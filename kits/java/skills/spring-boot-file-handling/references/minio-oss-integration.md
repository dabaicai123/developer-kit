# MinIO and Aliyun OSS Integration

## MinIO Setup

### Dependency

```xml
<dependency>
    <groupId>io.minio</groupId>
    <artifactId>minio</artifactId>
    <version>8.5.14</version>
</dependency>
```

### Configuration Properties

```yaml
file:
  storage:
    type: minio  # Switch to "oss" for Aliyun OSS

minio:
  endpoint: http://127.0.0.1:9000
  access-key: minioadmin
  secret-key: minioadmin
  bucket: my-app-files
```

### MinioClient Bean Configuration

```java
@Configuration
@ConditionalOnProperty(name = "file.storage.type", havingValue = "minio")
public class MinioConfig {

    @Bean
    public MinioClient minioClient(
            @Value("${minio.endpoint}") String endpoint,
            @Value("${minio.access-key}") String accessKey,
            @Value("${minio.secret-key}") String secretKey) {
        return MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
    }
}
```

## MinIO Operations

### putObject — Upload File

```java
public String upload(MultipartFile file, String storageFilename) {
    try {
        ensureBucketExists();
        minioClient.putObject(PutObjectArgs.builder()
                .bucket(bucket)
                .object(storageFilename)
                .stream(file.getInputStream(), file.getSize(), -1)
                .contentType(file.getContentType())
                .build());
        return storageFilename;
    } catch (Exception e) {
        log.error("MinIO upload failed: {}", storageFilename, e);
        throw new BusinessException(500, "File upload failed");
    }
}

// Upload from InputStream with known size
public String upload(InputStream inputStream, String storageFilename, long size, String contentType) {
    try {
        minioClient.putObject(PutObjectArgs.builder()
                .bucket(bucket)
                .object(storageFilename)
                .stream(inputStream, size, -1)
                .contentType(contentType)
                .build());
        return storageFilename;
    } catch (Exception e) {
        log.error("MinIO upload failed: {}", storageFilename, e);
        throw new BusinessException(500, "File upload failed");
    }
}
```

### getObject — Download File

```java
public InputStream download(String storagePath) {
    try {
        return minioClient.getObject(GetObjectArgs.builder()
                .bucket(bucket)
                .object(storagePath)
                .build());
    } catch (ErrorResponseException e) {
        if (e.errorResponse().code().equals("NoSuchKey")) {
            throw new NotFoundException("File", storagePath);
        }
        throw new BusinessException(500, "File download failed");
    } catch (Exception e) {
        log.error("MinIO download failed: {}", storagePath, e);
        throw new BusinessException(500, "File download failed");
    }
}
```

### removeObject — Delete File

```java
public void delete(String storagePath) {
    try {
        minioClient.removeObject(RemoveObjectArgs.builder()
                .bucket(bucket)
                .object(storagePath)
                .build());
    } catch (Exception e) {
        log.error("MinIO delete failed: {}", storagePath, e);
        throw new BusinessException(500, "File delete failed");
    }
}
```

### Presigned URL Generation

```java
// Required imports for presigned URL: io.minio.http.Method, java.util.concurrent.TimeUnit
// GET presigned URL for download
public String generatePresignedUrl(String storagePath, int expiryMinutes) {
    try {
        return minioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                .bucket(bucket)
                .object(storagePath)
                .method(Method.GET)
                .expiry(expiryMinutes, TimeUnit.MINUTES)  // expiry(int) defaults to seconds; specify unit explicitly
                .build());
    } catch (Exception e) {
        log.error("MinIO presigned URL generation failed: {}", storagePath, e);
        throw new BusinessException(500, "Failed to generate download URL");
    }
}

// PUT presigned URL for upload (client-side upload)
public String generateUploadPresignedUrl(String storagePath, int expiryMinutes) {
    try {
        return minioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                .bucket(bucket)
                .object(storagePath)
                .method(Method.PUT)
                .expiry(expiryMinutes, TimeUnit.MINUTES)  // expiry(int) defaults to seconds; specify unit explicitly
                .build());
    } catch (Exception e) {
        log.error("MinIO upload presigned URL generation failed: {}", storagePath, e);
        throw new BusinessException(500, "Failed to generate upload URL");
    }
}
```

## Bucket Management

### Create Bucket

```java
private void ensureBucketExists() {
    try {
        boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
        if (!exists) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        }
    } catch (Exception e) {
        log.error("MinIO bucket check/create failed", e);
        throw new BusinessException(500, "Storage initialization failed");
    }
}
```

### Set Bucket Policy (Public Read)

```java
public void setBucketPublicReadPolicy() {
    String policy = """
        {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"AWS": ["*"]},
                "Action": ["s3:GetObject"],
                "Resource": ["arn:aws:s3:::%s/*"]
            }]
        }
        """.formatted(bucket);

    try {
        minioClient.setBucketPolicy(SetBucketPolicyArgs.builder()
                .bucket(bucket)
                .config(policy)
                .build());
    } catch (Exception e) {
        log.error("Failed to set bucket policy", e);
        throw new BusinessException(500, "Bucket policy configuration failed");
    }
}
```

## Aliyun OSS Setup

### Dependency

```xml
<dependency>
    <groupId>com.aliyun.oss</groupId>
    <artifactId>aliyun-sdk-oss</artifactId>
    <version>3.18.1</version>
</dependency>
```

### Configuration Properties

```yaml
file:
  storage:
    type: oss  # Switch to "minio" for MinIO

oss:
  endpoint: oss-cn-hangzhou.aliyuncs.com
  access-key-id: ${OSS_ACCESS_KEY_ID}
  access-key-secret: ${OSS_ACCESS_KEY_SECRET}
  bucket: my-app-files
```

### OSSClient Bean Configuration

```java
@Configuration
@ConditionalOnProperty(name = "file.storage.type", havingValue = "oss")
public class OssConfig {

    @Bean
    public OSS ossClient(
            @Value("${oss.endpoint}") String endpoint,
            @Value("${oss.access-key-id}") String accessKeyId,
            @Value("${oss.access-key-secret}") String accessKeySecret) {
        return new OSSClientBuilder().build(endpoint, accessKeyId, accessKeySecret);
    }

    @Bean
    public PreDestroyCleanup preDestroyCleanup(OSS ossClient) {
        return new PreDestroyCleanup(ossClient);
    }

    static class PreDestroyCleanup {
        private final OSS ossClient;
        PreDestroyCleanup(OSS ossClient) { this.ossClient = ossClient; }
        @PreDestroy  // jakarta.annotation.PreDestroy (Spring Boot 3.x uses Jakarta EE 9+)
        public void cleanup() { ossClient.shutdown(); }
    }
}
```

## OSS Operations

### putObject — Upload File

```java
public String upload(MultipartFile file, String storageFilename) {
    try {
        ObjectMetadata metadata = new ObjectMetadata();
        metadata.setContentLength(file.getSize());
        metadata.setContentType(file.getContentType());
        ossClient.putObject(new PutObjectRequest(bucket, storageFilename, file.getInputStream(), metadata));
        return storageFilename;
    } catch (Exception e) {
        log.error("OSS upload failed: {}", storageFilename, e);
        throw new BusinessException(500, "File upload failed");
    }
}
```

### getObject — Download File

```java
public InputStream download(String storagePath) {
    try {
        OSSObject ossObject = ossClient.getObject(bucket, storagePath);
        return ossObject.getObjectContent();
    } catch (OSSException e) {
        if ("NoSuchKey".equals(e.getErrorCode())) {
            throw new NotFoundException("File", storagePath);
        }
        log.error("OSS download failed: {}", storagePath, e);
        throw new BusinessException(500, "File download failed");
    } catch (Exception e) {
        log.error("OSS download failed: {}", storagePath, e);
        throw new BusinessException(500, "File download failed");
    }
}
```

### deleteObject — Delete File

```java
public void delete(String storagePath) {
    try {
        ossClient.deleteObject(bucket, storagePath);
    } catch (Exception e) {
        log.error("OSS delete failed: {}", storagePath, e);
        throw new BusinessException(500, "File delete failed");
    }
}
```

### generatePresignedUrl — Presigned URL

```java
public String generatePresignedUrl(String storagePath, int expiryMinutes) {
    try {
        Date expiration = new Date(System.currentTimeMillis() + expiryMinutes * 60 * 1000L);
        URL url = ossClient.generatePresignedUrl(bucket, storagePath, expiration);
        return url.toString();
    } catch (Exception e) {
        log.error("OSS presigned URL generation failed: {}", storagePath, e);
        throw new BusinessException(500, "Failed to generate download URL");
    }
}
```

## Storage Abstraction Interface Pattern

### FileStorageService Interface

```java
/**
 * File storage service abstraction interface
 * <p>Defines standard operations for file upload, download, delete, and presigned URL generation</p>
 * <p>Business code depends only on this interface, not on specific storage implementations</p>
 */
public interface FileStorageService {

    /**
     * Upload file
     *
     * @param file           MultipartFile uploaded file
     * @param storageFilename Storage filename (UUID-generated unique name)
     * @return Storage path
     */
    String upload(MultipartFile file, String storageFilename);

    /**
     * Download file (returns stream to avoid memory usage for large files)
     *
     * @param storagePath Storage path
     * @return File content stream
     */
    InputStream download(String storagePath);

    /**
     * Delete file
     *
     * @param storagePath Storage path
     */
    void delete(String storagePath);

    /**
     * Generate presigned download URL
     *
     * @param storagePath   Storage path
     * @param expiryMinutes URL validity duration (minutes)
     * @return Presigned URL string
     */
    String generatePresignedUrl(String storagePath, int expiryMinutes);
}
```

### MinIO Implementation

```java
@Service
@ConditionalOnProperty(name = "file.storage.type", havingValue = "minio")
@RequiredArgsConstructor
@Slf4j
public class MinioFileStorageService implements FileStorageService {

    private final MinioClient minioClient;

    @Value("${minio.bucket}")
    private String bucket;

    @Override
    public String upload(MultipartFile file, String storageFilename) {
        try {
            ensureBucketExists();
            minioClient.putObject(PutObjectArgs.builder()
                    .bucket(bucket)
                    .object(storageFilename)
                    .stream(file.getInputStream(), file.getSize(), -1)
                    .contentType(file.getContentType())
                    .build());
            return storageFilename;
        } catch (Exception e) {
            log.error("MinIO upload failed: {}", storageFilename, e);
            throw new BusinessException(500, "File upload failed");
        }
    }

    @Override
    public InputStream download(String storagePath) {
        try {
            return minioClient.getObject(GetObjectArgs.builder()
                    .bucket(bucket)
                    .object(storagePath)
                    .build());
        } catch (Exception e) {
            log.error("MinIO download failed: {}", storagePath, e);
            throw new NotFoundException("File", storagePath);
        }
    }

    @Override
    public void delete(String storagePath) {
        try {
            minioClient.removeObject(RemoveObjectArgs.builder()
                    .bucket(bucket)
                    .object(storagePath)
                    .build());
        } catch (Exception e) {
            log.error("MinIO delete failed: {}", storagePath, e);
            throw new BusinessException(500, "File delete failed");
        }
    }

    @Override
    public String generatePresignedUrl(String storagePath, int expiryMinutes) {
        try {
            return minioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .bucket(bucket)
                    .object(storagePath)
                    .method(Method.GET)
                    .expiry(expiryMinutes)
                    .build());
        } catch (Exception e) {
            log.error("MinIO presigned URL generation failed: {}", storagePath, e);
            throw new BusinessException(500, "Failed to generate download URL");
        }
    }

    private void ensureBucketExists() {
        try {
            boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
            if (!exists) {
                minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
            }
        } catch (Exception e) {
            log.error("MinIO bucket check/create failed", e);
            throw new BusinessException(500, "Storage initialization failed");
        }
    }
}
```

### OSS Implementation

```java
@Service
@ConditionalOnProperty(name = "file.storage.type", havingValue = "oss")
@RequiredArgsConstructor
@Slf4j
public class OssFileStorageService implements FileStorageService {

    private final OSS ossClient;

    @Value("${oss.bucket}")
    private String bucket;

    @Override
    public String upload(MultipartFile file, String storageFilename) {
        try {
            ObjectMetadata metadata = new ObjectMetadata();
            metadata.setContentLength(file.getSize());
            metadata.setContentType(file.getContentType());
            ossClient.putObject(new PutObjectRequest(bucket, storageFilename, file.getInputStream(), metadata));
            return storageFilename;
        } catch (Exception e) {
            log.error("OSS upload failed: {}", storageFilename, e);
            throw new BusinessException(500, "File upload failed");
        }
    }

    @Override
    public InputStream download(String storagePath) {
        try {
            OSSObject ossObject = ossClient.getObject(bucket, storagePath);
            return ossObject.getObjectContent();
        } catch (OSSException e) {
            if ("NoSuchKey".equals(e.getErrorCode())) {
                throw new NotFoundException("File", storagePath);
            }
            log.error("OSS download failed: {}", storagePath, e);
            throw new BusinessException(500, "File download failed");
        } catch (Exception e) {
            log.error("OSS download failed: {}", storagePath, e);
            throw new BusinessException(500, "File download failed");
        }
    }

    @Override
    public void delete(String storagePath) {
        try {
            ossClient.deleteObject(bucket, storagePath);
        } catch (Exception e) {
            log.error("OSS delete failed: {}", storagePath, e);
            throw new BusinessException(500, "File delete failed");
        }
    }

    @Override
    public String generatePresignedUrl(String storagePath, int expiryMinutes) {
        try {
            Date expiration = new Date(System.currentTimeMillis() + expiryMinutes * 60 * 1000L);
            URL url = ossClient.generatePresignedUrl(bucket, storagePath, expiration);
            return url.toString();
        } catch (Exception e) {
            log.error("OSS presigned URL generation failed: {}", storagePath, e);
            throw new BusinessException(500, "Failed to generate download URL");
        }
    }
}
```

## @ConditionalOnProperty Switching Pattern

The `@ConditionalOnProperty` annotation enables zero-code-change switching between MinIO and OSS by changing a single configuration property:

```yaml
# Use MinIO (self-hosted, private cloud)
file:
  storage:
    type: minio

# Use Aliyun OSS (cloud-native, Aliyun deployment)
file:
  storage:
    type: oss
```

- `MinioConfig` and `MinioFileStorageService` activate only when `file.storage.type=minio`
- `OssConfig` and `OssFileStorageService` activate only when `file.storage.type=oss`
- Business code injects `FileStorageService` interface — Spring auto-wires the active implementation
- No code changes required when switching storage provider
- Both implementations can coexist in the same project (only one activates at runtime)

### Disambiguation When Multiple Beans Exist

If you need both beans active simultaneously (e.g., for migration), use `@Qualifier`:

```java
@Service
@RequiredArgsConstructor
public class FileService {
    private final FileStorageService fileStorageService; // auto-wires active implementation

    // For dual-write migration scenarios:
    // @Qualifier("minioFileStorageService") FileStorageService minioStorage;
    // @Qualifier("ossFileStorageService") FileStorageService ossStorage;
}
```