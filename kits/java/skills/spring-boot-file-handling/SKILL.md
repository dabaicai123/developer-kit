---
name: spring-boot-file-handling
description: "Spring Boot file handling with MultipartFile upload/download, MinIO and Aliyun OSS object storage, EasyExcel export/import, file validation, and storage abstraction. Use when implementing file upload, download, or export features in Spring Boot."
version: "1.0.0"
---

# Spring Boot File Handling

File handling patterns for Spring Boot — upload/download, object storage, EasyExcel, and storage abstraction.

## When to use this skill

- Implementing MultipartFile upload/download endpoints
- Integrating MinIO or Aliyun OSS object storage
- Implementing EasyExcel-based Excel export/import
- Creating storage abstraction layer to decouple business logic from storage provider
- Adding file validation (type, size, extension, magic bytes)
- Generating presigned URLs for secure file access

## Project Setup — MinIO, Aliyun OSS, EasyExcel dependencies

```xml
<!-- MinIO (check latest at https://min.io/docs/minio/linux/developers/java/minio-java.html) -->
<dependency>
    <groupId>io.minio</groupId>
    <artifactId>minio</artifactId>
    <version>8.5.14</version>
</dependency>

<!-- Aliyun OSS (check latest at https://help.aliyun.com/document_detail/32008.html) -->
<dependency>
    <groupId>com.aliyun.oss</groupId>
    <artifactId>aliyun-sdk-oss</artifactId>
    <version>3.18.1</version>
</dependency>

<!-- EasyExcel (check latest at https://github.com/alibaba/easyexcel) -->
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>easyexcel</artifactId>
    <version>4.0.3</version>
</dependency>
```

Spring multipart configuration:

```yaml
spring:
  servlet:
    multipart:
      max-file-size: 10MB
      max-request-size: 50MB
      file-size-threshold: 1MB
      location: ${java.io.tmpdir}
```

## Instructions

### File upload flow

Validate file type and size, generate a unique storage filename, save metadata to the database, upload to object storage via `FileStorageService`, return file metadata and download URL.

### File download flow

Query file metadata from the database. For presigned URL: generate via storage provider and return to client (preferred). For direct download: stream from storage to HTTP response with proper `Content-Disposition` and `Content-Type` headers.

### Excel export flow

Query data, map to export DTOs with `@ExcelProperty` annotations, set response headers, write via `EasyExcel.write(response.getOutputStream(), DTO.class).sheet("Sheet1").doWrite(dataList)`. Never load entire dataset into memory.

### Excel import flow

Upload Excel via MultipartFile, validate extension and size, read via `EasyExcel.read()` with `AnalysisEventListener` processing rows in batches. Handle errors in `onException` callback. Return import result with total, success, and error details.

### Storage abstraction

Define `FileStorageService` interface. Implement `MinioFileStorageService` and `OssFileStorageService` with `@ConditionalOnProperty`. Business code depends only on the interface — never directly on storage SDK. Switch providers by changing config property.

## Examples

### Example 1: MultipartFile upload controller with validation

```java
@RestController
@RequestMapping("/v1/files")
@RequiredArgsConstructor
@Slf4j
public class FileController {

    private final FileStorageService fileStorageService;
    private final FileMetadataService fileMetadataService;

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "pdf", "xlsx");
    private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

    @PostMapping("/upload")
    public Result<FileUploadResponse> upload(@RequestParam("file") MultipartFile file) {
        // 1. Validate extension
        String originalFilename = file.getOriginalFilename();
        String extension = getFileExtension(originalFilename);
        if (!ALLOWED_EXTENSIONS.contains(extension.toLowerCase())) {
            throw new ValidationException("File extension not allowed: " + extension);
        }

        // 2. Validate size
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new ValidationException("File size exceeds 10MB limit");
        }

        // 3. Validate content (magic bytes)
        if (!validateFileContent(file, extension)) {
            throw new ValidationException("File content does not match declared type");
        }

        // 4. Generate unique storage filename
        String storageFilename = UUID.randomUUID().toString().replace("-", "") + "." + extension;

        // 5. Upload to storage
        String storagePath = fileStorageService.upload(file, storageFilename);

        // 6. Save metadata to database
        FileMetadata metadata = fileMetadataService.save(
            originalFilename, storageFilename, storagePath,
            file.getSize(), file.getContentType()
        );

        // 7. Generate presigned download URL
        String downloadUrl = fileStorageService.generatePresignedUrl(storagePath, 60);

        return Result.success(new FileUploadResponse(metadata.getId(), downloadUrl));
    }

    private String getFileExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            throw new ValidationException("Invalid filename");
        }
        return filename.substring(filename.lastIndexOf(".") + 1);
    }

    private boolean validateFileContent(MultipartFile file, String extension) {
        try (InputStream is = file.getInputStream()) {
            byte[] header = new byte[8];
            int read = is.read(header);
            if (read < 4) return false;

            return switch (extension.toLowerCase()) {
                case "jpg", "jpeg" -> header[0] == (byte) 0xFF && header[1] == (byte) 0xD8;
                case "png" -> header[0] == (byte) 0x89 && new String(header, 1, 3).equals("PNG");
                case "pdf" -> new String(header, 0, 4).equals("%PDF");
                default -> true; // skip magic bytes check for unknown types
            };
        } catch (IOException e) {
            log.error("Failed to read file header for validation", e);
            return false;
        }
    }
}
```

### Example 2: FileStorageService interface (storage abstraction)

Business code depends only on the `FileStorageService` interface — implementations activate via `@ConditionalOnProperty`:

```java
public interface FileStorageService {
    String upload(MultipartFile file, String storageFilename);
    InputStream download(String storagePath);
    void delete(String storagePath);
    String generatePresignedUrl(String storagePath, int expiryMinutes);
}
```

> For complete MinIO and Aliyun OSS implementations, see `references/minio-oss-integration.md`.

### Example 3: EasyExcel export — write data to Excel and stream as HTTP response

```java
@RestController
@RequestMapping("/v1/export")
@RequiredArgsConstructor
public class ExcelExportController {

    private final UserService userService;

    @GetMapping("/users")
    public void exportUsers(HttpServletResponse response) throws IOException {
        // 1. Set response headers
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setCharacterEncoding("utf-8");
        String filename = URLEncoder.encode("User List", StandardCharsets.UTF_8).replaceAll("\\+", "%20");
        response.setHeader("Content-Disposition", "attachment; filename=" + filename + ".xlsx");

        // 2. Query data
        List<UserExportDTO> data = userService.findAllForExport();

        // 3. Write Excel
        EasyExcel.write(response.getOutputStream(), UserExportDTO.class)
                .sheet("User List")
                .doWrite(data);
    }
}

@Data
public class UserExportDTO {
    @ExcelProperty("User ID")
    private Long id;

    @ExcelProperty("Username")
    private String username;

    @ExcelProperty("Email")
    private String email;

    @ExcelProperty(value = "Registration Time", converter = LocalDateTimeConverter.class)
    private LocalDateTime createdAt;
}
```

### Example 4: EasyExcel import — ReadListener pattern

> See [easyexcel-import-example.md](references/easyexcel-import-example.md) for the full `AnalysisEventListener` implementation with batch processing, validation, and error handling.

### Example 5: File download as HTTP response with proper Content-Disposition header

```java
@GetMapping("/{id}/download")
public void download(@PathVariable Long id, HttpServletResponse response) throws IOException {
    // 1. Query file metadata
    FileMetadata metadata = fileMetadataService.getById(id);

    // 2. Download from storage (streaming, not loading entire file)
    InputStream inputStream = fileStorageService.download(metadata.getStoragePath());

    // 3. Set response headers
    response.setContentType(metadata.getContentType());
    String encodedFilename = URLEncoder.encode(metadata.getOriginalFilename(), StandardCharsets.UTF_8)
            .replaceAll("\\+", "%20");
    response.setHeader("Content-Disposition",
            "attachment; filename=\"" + encodedFilename + "\"; filename*=UTF-8''" + encodedFilename);
    response.setContentLengthLong(metadata.getFileSize());

    // 4. Stream file to response
    try (InputStream is = inputStream; OutputStream os = response.getOutputStream()) {
        is.transferTo(os);
    }
}

// Alternative: return presigned URL instead of proxying through application server (preferred)
@GetMapping("/{id}/download-url")
public Result<String> getDownloadUrl(@PathVariable Long id) {
    FileMetadata metadata = fileMetadataService.getById(id);
    String presignedUrl = fileStorageService.generatePresignedUrl(metadata.getStoragePath(), 30);
    return Result.success(presignedUrl);
}
```

## Best Practices

- Always validate file type by content (magic bytes), not just extension
- Set maximum file size: `spring.servlet.multipart.max-file-size` and `max-request-size`
- Use storage abstraction (`FileStorageService` interface) to decouple business logic from specific storage provider
- Stream large files — never load entire file content into memory
- Use EasyExcel `ReadListener` for import (batch processing, not loading entire file)
- Generate unique file names (UUID + original extension) to prevent collision and path traversal
- Return presigned URLs for download instead of proxying through application server
- Store file metadata (name, size, type, storage path) in database, actual file in object storage

## Constraints and Warnings

- **Path traversal**: never use user-provided filenames directly for storage paths — sanitize or generate unique names
- **File size limits**: configure both Spring (multipart) and storage provider limits
- **Memory**: avoid loading large files into byte arrays — use streaming APIs (`InputStream.transferTo()`)
- **Virus/malware scanning**: consider virus/malware scanning for user uploads (not covered in this skill)
- **MinIO vs OSS**: MinIO for self-hosted/private cloud deployments; Aliyun OSS for cloud-native deployments on Aliyun infrastructure
- **EasyExcel vs Apache POI**: EasyExcel uses streaming SAX parser — far less memory than POI's DOM model. Always prefer EasyExcel for large files
- **MinIO presigned URL expiry**: `.expiry(int)` defaults to seconds — always use `.expiry(duration, TimeUnit.MINUTES)` to specify the unit explicitly

## References

- See `references/minio-oss-integration.md` for complete MinIO and Aliyun OSS configuration, operations, and storage abstraction pattern
- See `references/easyexcel-patterns.md` for EasyExcel export/import patterns, ReadListener, custom converters, and multi-sheet handling
- See `references/easyexcel-import-example.md` for complete ReadListener implementation with batch processing
- See `references/file-upload-validation.md` for Spring multipart configuration, file validation (extension, MIME, magic bytes), and path traversal prevention

## Related Skills

- `spring-boot-validation`
- `spring-boot-rest-api-standards`
- `spring-boot-exception-handling`