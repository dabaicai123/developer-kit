# File Upload Validation

## Spring Multipart Configuration

### application.yml

```yaml
spring:
  servlet:
    multipart:
      max-file-size: 10MB          # Single file max size
      max-request-size: 50MB       # Total request max size (multiple files)
      file-size-threshold: 1MB     # In-memory threshold; files larger than this are written to disk
      location: ${java.io.tmpdir}  # Temporary directory for large file uploads
```

### Configuration Explanation

| Property | Purpose |
|---|---|
| `max-file-size` | Maximum size for a single uploaded file. Exceeding throws `MaxUploadSizeExceededException` |
| `max-request-size` | Maximum size for the entire multipart request (useful when uploading multiple files) |
| `file-size-threshold` | Files below this threshold stay in memory; above are written to `location` |
| `location` | Disk directory for temporarily storing large uploads. Defaults to JVM temp dir |

### Handling MaxUploadSizeExceededException

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public Result<Void> handleMaxUploadSize(MaxUploadSizeExceededException e) {
        log.warn("File size exceeded: {}", e.getMessage());
        return Result.fail(400, "File size exceeds the allowed limit (10MB)");
    }
}
```

## Controller-Level Validation

### Extension Whitelist Check

Never accept all file types. Define an explicit whitelist of allowed extensions:

```java
private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "gif", "pdf", "xlsx", "docx");

private void validateExtension(String filename) {
    if (filename == null || !filename.contains(".")) {
        throw new ValidationException("Invalid filename: no extension");
    }
    String extension = filename.substring(filename.lastIndexOf(".") + 1).toLowerCase();
    if (!ALLOWED_EXTENSIONS.contains(extension)) {
        throw new ValidationException("File extension not allowed: " + extension);
    }
}
```

### MIME Type Validation (Content-Type Header)

Check the `MultipartFile.getContentType()` against an allowed MIME type map. Note: MIME type is set by the client browser and can be spoofed — it should be used as a **first-pass filter**, not the sole validation:

```java
private static final Map<String, Set<String>> EXTENSION_TO_MIME = Map.of(
    "jpg", Set.of("image/jpeg"),
    "jpeg", Set.of("image/jpeg"),
    "png", Set.of("image/png"),
    "gif", Set.of("image/gif"),
    "pdf", Set.of("application/pdf"),
    "xlsx", Set.of("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
);

private void validateMimeType(MultipartFile file, String extension) {
    String contentType = file.getContentType();
    if (contentType == null) {
        throw new ValidationException("Content-Type header is missing");
    }
    Set<String> allowedMimes = EXTENSION_TO_MIME.get(extension.toLowerCase());
    if (allowedMimes != null && !allowedMimes.contains(contentType.toLowerCase())) {
        throw new ValidationException(
            "MIME type mismatch: expected " + allowedMimes + " but got " + contentType);
    }
}
```

### Content Validation (Magic Bytes Check)

The most reliable validation — check the actual file content header (magic bytes) to verify the file type matches the declared type. This catches cases where a malicious user renames a `.exe` to `.jpg`:

```java
private boolean validateFileContent(MultipartFile file, String extension) {
    try (InputStream is = file.getInputStream()) {
        byte[] header = new byte[16];
        int read = is.read(header);
        if (read < 4) return false;

        return switch (extension.toLowerCase()) {
            // JPEG: starts with FF D8 FF
            case "jpg", "jpeg" ->
                header[0] == (byte) 0xFF && header[1] == (byte) 0xD8 && header[2] == (byte) 0xFF;

            // PNG: starts with 89 50 4E 47 (0x89 + "PNG")
            case "png" ->
                header[0] == (byte) 0x89
                && header[1] == 0x50  // 'P'
                && header[2] == 0x4E  // 'N'
                && header[3] == 0x47; // 'G'

            // GIF: starts with "GIF87a" or "GIF89a"
            case "gif" ->
                new String(header, 0, 6).equals("GIF87a")
                || new String(header, 0, 6).equals("GIF89a");

            // PDF: starts with "%PDF"
            case "pdf" -> new String(header, 0, 4).equals("%PDF");

            // XLSX (ZIP-based): starts with PK (50 4B 03 04)
            case "xlsx", "docx" ->
                header[0] == 0x50  // 'P'
                && header[1] == 0x4B; // 'K'

            // For unknown extensions, skip magic bytes check
            default -> true;
        };
    } catch (IOException e) {
        log.error("Failed to read file header for validation", e);
        return false;
    }
}
```

### Combined Validation (Extension + MIME + Magic Bytes)

Always combine all three validation layers for security:

```java
@PostMapping("/upload")
public Result<FileUploadResponse> upload(@RequestParam("file") MultipartFile file) {
    String originalFilename = file.getOriginalFilename();

    // Layer 1: Extension whitelist
    validateExtension(originalFilename);
    String extension = getFileExtension(originalFilename);

    // Layer 2: MIME type
    validateMimeType(file, extension);

    // Layer 3: Magic bytes (content)
    if (!validateFileContent(file, extension)) {
        throw new ValidationException("File content does not match declared type");
    }

    // Layer 4: Size limit
    if (file.getSize() > MAX_FILE_SIZE) {
        throw new ValidationException("File size exceeds " + (MAX_FILE_SIZE / 1024 / 1024) + "MB limit");
    }

    // Proceed with upload
    String storageFilename = generateStorageFilename(extension);
    String storagePath = fileStorageService.upload(file, storageFilename);
    // ...
}
```

### File Size Check (MultipartFile.getSize())

```java
private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

private void validateFileSize(MultipartFile file) {
    if (file.isEmpty()) {
        throw new ValidationException("File is empty");
    }
    if (file.getSize() > MAX_FILE_SIZE) {
        throw new ValidationException("File size exceeds 10MB limit");
    }
}
```

`file.getSize()` returns the actual file size in bytes. This is a server-side check that cannot be spoofed by the client. Use it in addition to `max-file-size` in Spring config (which rejects oversized requests before they reach your controller).

## Path Traversal Prevention

### Never Use Original Filename for Storage Path

The original filename from `MultipartFile.getOriginalFilename()` is provided by the client and can contain path traversal sequences:

- `../../../etc/passwd` — reads sensitive system files
- `../../config/application.yml` — reads application configuration
- `C:\Windows\System32\` — Windows path traversal

**Never** use the original filename directly as a storage path or key.

### Generate UUID-Based Filename + Preserve Original Name in Metadata

```java
private String generateStorageFilename(String extension) {
    // UUID ensures uniqueness and prevents collision and path traversal
    return UUID.randomUUID().toString().replace("-", "") + "." + extension;
}

// Store original name in database metadata, not in filesystem
FileMetadata metadata = new FileMetadata();
metadata.setOriginalFilename(file.getOriginalFilename());  // preserved for display
metadata.setStorageFilename(storageFilename);               // UUID name used for actual storage
metadata.setStoragePath("uploads/2024/01/" + storageFilename); // controlled directory structure
metadata.setFileSize(file.getSize());
metadata.setContentType(file.getContentType());
fileMetadataRepository.save(metadata);
```

### Sanitize Filename — Strip Path Separators, Limit Length

If you must display or process the original filename, sanitize it first:

```java
private String sanitizeFilename(String filename) {
    if (filename == null) return "unnamed";

    // Strip path separators and dangerous characters
    String sanitized = filename.replaceAll("[\\\\/\\:*?\"<>|]", "_");

    // Remove leading dots (hidden files in Unix)
    while (sanitized.startsWith(".")) {
        sanitized = sanitized.substring(1);
    }

    // Limit length to prevent excessively long names
    if (sanitized.length() > 200) {
        String extension = "";
        if (sanitized.contains(".")) {
            extension = sanitized.substring(sanitized.lastIndexOf("."));
        }
        sanitized = sanitized.substring(0, 200 - extension.length()) + extension;
    }

    return sanitized;
}
```

### Controlled Directory Structure

Instead of letting user input determine the storage directory, use a **date-based directory structure** controlled by the server:

```java
private String buildStoragePath(String storageFilename) {
    // Server-controlled directory: uploads/YYYY/MM/
    LocalDate today = LocalDate.now();
    return String.format("uploads/%d/%02d/%s",
        today.getYear(), today.getMonthValue(), storageFilename);
}
```

## Filename Security Patterns

### Pattern 1: UUID + Original Extension (Recommended)

```java
String originalFilename = file.getOriginalFilename();
String extension = getFileExtension(originalFilename);
String storageFilename = UUID.randomUUID().toString().replace("-", "") + "." + extension;
```

- Uniqueness guaranteed by UUID
- Original extension preserved for content-type detection
- Original filename stored only in database metadata
- No path traversal risk — UUID contains no path separators

### Pattern 2: Hash-Based Filename

```java
String contentHash = DigestUtils.md5Hex(file.getInputStream());
String storageFilename = contentHash + "." + extension;
```

- Same file content produces same hash — natural deduplication
- MD5 is fast but not cryptographically secure; use SHA-256 for security-sensitive scenarios
- Risk: hash collision for large file volumes (extremely unlikely with SHA-256)

### Pattern 3: Timestamp + RandomSuffix

```java
String storageFilename = System.currentTimeMillis() + "_" + RandomStringUtils.randomAlphanumeric(8) + "." + extension;
```

- Simpler than UUID
- Timestamp provides rough ordering
- Random suffix prevents collision
- Less uniqueness guarantee than UUID (acceptable for most cases)

## Complete Upload Validation Utility

```java
@Component
@Slf4j
public class FileValidationService {

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of(
        "jpg", "jpeg", "png", "gif", "pdf", "xlsx", "docx", "zip"
    );

    private static final Map<String, Set<String>> EXTENSION_TO_MIME = Map.of(
        "jpg", Set.of("image/jpeg"),
        "jpeg", Set.of("image/jpeg"),
        "png", Set.of("image/png"),
        "gif", Set.of("image/gif"),
        "pdf", Set.of("application/pdf"),
        "xlsx", Set.of("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
        "docx", Set.of("application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
        "zip", Set.of("application/zip", "application/x-zip-compressed")
    );

    private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

    /**
     * Full validation pipeline: extension -> MIME -> magic bytes -> size
     */
    public String validateAndGenerateStorageName(MultipartFile file) {
        String originalFilename = file.getOriginalFilename();

        // 1. Extension whitelist
        String extension = validateExtension(originalFilename);

        // 2. MIME type match
        validateMimeType(file, extension);

        // 3. Magic bytes (content integrity)
        validateMagicBytes(file, extension);

        // 4. Size limit
        validateSize(file);

        // 5. Generate safe storage filename
        return UUID.randomUUID().toString().replace("-", "") + "." + extension;
    }

    private String validateExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            throw new ValidationException("Invalid filename: missing extension");
        }
        String extension = filename.substring(filename.lastIndexOf(".") + 1).toLowerCase();
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new ValidationException("File extension not allowed: " + extension);
        }
        return extension;
    }

    private void validateMimeType(MultipartFile file, String extension) {
        String contentType = file.getContentType();
        Set<String> allowed = EXTENSION_TO_MIME.get(extension);
        if (allowed != null && (contentType == null || !allowed.contains(contentType.toLowerCase()))) {
            throw new ValidationException("MIME type mismatch for extension: " + extension);
        }
    }

    private void validateMagicBytes(MultipartFile file, String extension) {
        try (InputStream is = file.getInputStream()) {
            byte[] header = new byte[16];
            int read = is.read(header);
            if (read < 4) {
                throw new ValidationException("File too small to validate content type");
            }
            if (!checkMagicBytes(header, extension)) {
                throw new ValidationException("File content does not match declared type: " + extension);
            }
        } catch (IOException e) {
            throw new ValidationException("Failed to validate file content");
        }
    }

    private boolean checkMagicBytes(byte[] header, String extension) {
        return switch (extension) {
            case "jpg", "jpeg" -> header[0] == (byte) 0xFF && header[1] == (byte) 0xD8;
            case "png" -> header[0] == (byte) 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47;
            case "gif" -> new String(header, 0, 6).startsWith("GIF8");
            case "pdf" -> new String(header, 0, 4).equals("%PDF");
            case "xlsx", "docx", "zip" -> header[0] == 0x50 && header[1] == 0x4B;
            default -> true;
        };
    }

    private void validateSize(MultipartFile file) {
        if (file.isEmpty()) {
            throw new ValidationException("Uploaded file is empty");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new ValidationException("File size exceeds 10MB limit");
        }
    }
}
```

## Summary: Three-Layer Validation Model

| Layer | What it checks | Spoofable? | When to use |
|---|---|---|---|
| Extension whitelist | File extension matches allowed set | Yes (rename file) | Always — first-pass filter |
| MIME type validation | Content-Type header matches expected type | Yes (client sets header) | Always — second-pass filter |
| Magic bytes (content) | Actual file bytes match file type signature | No (requires forging content) | Always — definitive check |

All three layers must be applied together. Extension and MIME checks are fast but can be spoofed by attackers. Magic bytes validation reads actual file content and cannot be forged without modifying the file itself.