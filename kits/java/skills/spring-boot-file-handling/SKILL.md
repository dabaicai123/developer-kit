---
name: spring-boot-file-handling
description: "Spring Boot file handling with MultipartFile upload/download, MinIO and Aliyun OSS object storage, EasyExcel export/import, file validation, and storage abstraction. Use when implementing file upload, download, or export features in Spring Boot."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot File Handling

File upload/download, object storage (MinIO & Aliyun OSS), EasyExcel export/import, and storage abstraction for Spring Boot 3.5.x.

## When to use this skill

- Implementing MultipartFile upload/download endpoints
- Integrating MinIO or Aliyun OSS object storage
- Implementing EasyExcel-based Excel export/import
- Creating storage abstraction layer to decouple business logic from storage provider
- Adding file validation (type, size, extension, magic bytes)
- Generating presigned URLs for secure file access

## Project Setup — MinIO, Aliyun OSS, EasyExcel dependencies

```xml
<!-- MinIO -->
<dependency>
    <groupId>io.minio</groupId>
    <artifactId>minio</artifactId>
    <version>8.5.14</version>
</dependency>

<!-- Aliyun OSS -->
<dependency>
    <groupId>com.aliyun.oss</groupId>
    <artifactId>aliyun-sdk-oss</artifactId>
    <version>3.18.1</version>
</dependency>

<!-- EasyExcel -->
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

### File upload flow (controller -> validation -> storage)

1. Controller receives `MultipartFile` via `@PostMapping`
2. Validate file: check extension whitelist, MIME type, size limit, and content (magic bytes)
3. Generate unique storage filename: UUID + original extension (never use original filename for storage path)
4. Save file metadata (original name, size, type, storage path) to database
5. Upload file to object storage via `FileStorageService` abstraction
6. Return file metadata (id, download URL or presigned URL) to client

### File download flow (controller -> storage -> response)

1. Controller receives download request by file id
2. Query file metadata from database
3. For direct download: stream file from storage to HTTP response with proper headers
4. For presigned URL: generate URL via storage provider and return to client (preferred)
5. Set `Content-Disposition: attachment; filename="xxx"` header
6. Set correct `Content-Type` header from stored metadata

### Excel export flow (query data -> EasyExcel write -> response)

1. Query data from database (use pagination for large datasets)
2. Map entities to export DTOs with `@ExcelProperty` annotations
3. Set response headers: `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
4. Set `Content-Disposition: attachment; filename="xxx.xlsx"`
5. Write Excel via `EasyExcel.write(response.getOutputStream(), DTO.class).sheet("Sheet1").doWrite(dataList)`
6. Never load entire dataset into memory — use streaming or pagination

### Excel import flow (upload -> EasyExcel read listener -> process)

1. Upload Excel file via MultipartFile
2. Validate file: extension (.xlsx), size, and content structure
3. Read Excel via `EasyExcel.read(file.getInputStream(), DTO.class, new DataReadListener(service)).sheet().doRead()`
4. `AnalysisEventListener` processes rows in batches (e.g., 1000 rows per batch insert)
5. Handle errors in `onException` callback
6. Return import result: total rows, success count, error rows with details

### Storage abstraction (interface + MinIO/OSS implementations)

1. Define `FileStorageService` interface with upload, download, delete, presigned URL methods
2. Implement `MinioFileStorageService` with `@ConditionalOnProperty(name = "file.storage.type", havingValue = "minio")`
3. Implement `OssFileStorageService` with `@ConditionalOnProperty(name = "file.storage.type", havingValue = "oss")`
4. Business code depends only on `FileStorageService` interface — never directly on storage SDK
5. Switch storage provider by changing config property without any code change

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

### Example 4: EasyExcel import — ReadListener pattern for processing rows in batch

```java
@Slf4j
public class UserImportReadListener extends AnalysisEventListener<UserImportDTO> {

    private static final int BATCH_SIZE = 1000;
    private final UserService userService;
    private final List<UserImportDTO> batchList = new ArrayList<>();
    private int totalRows = 0;
    private int successRows = 0;
    private final List<ImportError> errors = new ArrayList<>();

    public UserImportReadListener(UserService userService) {
        this.userService = userService;
    }

    @Override
    public void invoke(UserImportDTO data, AnalysisContext context) {
        totalRows++;
        try {
            validateRow(data, context.readRowHolder().getRowIndex());
            batchList.add(data);
            if (batchList.size() >= BATCH_SIZE) {
                userService.batchCreate(batchList);
                successRows += batchList.size();
                batchList.clear();
            }
        } catch (ValidationException e) {
            errors.add(new ImportError(context.readRowHolder().getRowIndex(), e.getMsg()));
        }
    }

    @Override
    public void doAfterAllAnalysed(AnalysisContext context) {
        if (!batchList.isEmpty()) {
            userService.batchCreate(batchList);
            successRows += batchList.size();
        }
        log.info("Import completed: total={}, success={}, errors={}", totalRows, successRows, errors.size());
    }

    @Override
    public void onException(Exception exception, AnalysisContext context) {
        log.error("Excel parse error at row {}", context.readRowHolder().getRowIndex(), exception);
        if (exception instanceof ExcelDataConvertException) {
            ExcelDataConvertException e = (ExcelDataConvertException) exception;
            errors.add(new ImportError(e.getRowIndex(),
                "Column " + e.getColumnIndex() + ": data type mismatch"));
        }
    }

    private void validateRow(UserImportDTO data, int rowIndex) {
        if (StringUtils.isBlank(data.getUsername())) {
            throw new ValidationException("Username is required");
        }
        if (StringUtils.isBlank(data.getEmail()) || !data.getEmail().contains("@")) {
            throw new ValidationException("Valid email is required");
        }
    }

    public ImportResult getResult() {
        return new ImportResult(totalRows, successRows, errors);
    }
}

@Data
public class UserImportDTO {
    @ExcelProperty("Username")
    private String username;

    @ExcelProperty("Email")
    private String email;

    @ExcelProperty("Age")
    private Integer age;
}
```

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
- **Virus/malware scanning**: recommended for user uploads, but not covered in this skill (mention as needed)
- **MinIO vs OSS**: MinIO is self-hosted (good for private cloud), OSS is cloud-native (good for Aliyun). Choose based on deployment environment
- **EasyExcel vs Apache POI**: EasyExcel uses streaming SAX parser — far less memory than POI's DOM model. Always prefer EasyExcel for large files

## References

- See `references/minio-oss-integration.md` for complete MinIO and Aliyun OSS configuration, operations, and storage abstraction pattern
- See `references/easyexcel-patterns.md` for EasyExcel export/import patterns, ReadListener, custom converters, and multi-sheet handling
- See `references/file-upload-validation.md` for Spring multipart configuration, file validation (extension, MIME, magic bytes), and path traversal prevention

## Related Skills

- `spring-boot-validation` — Bean Validation patterns for request DTOs
- `spring-boot-rest-api-standards` — REST API design, unified `Result<T>` response format
- `spring-boot-exception-handling` — Global exception handling, `BusinessException`, `NotFoundException`

## Keywords

MultipartFile, MinIO, OSS, EasyExcel, file upload, file download, presigned URL, ReadListener, storage abstraction