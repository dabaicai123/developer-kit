# SpringDoc Dependency Setup

## Maven

```xml
<!-- WebMVC (most COLA projects use this) -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.8.13</version>
</dependency>
```

## Gradle

```gradle
implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.13'
```

## Version Compatibility

| Spring Boot | SpringDoc |
|------------|-----------|
| 3.5.x | 2.8.x |
| 3.4.x | 2.7.x – 2.8.x |
| 3.3.x | 2.6.x |

Always check [Maven Central](https://mvnrepository.com/artifact/org.springdoc) for the latest stable version.

## COLA Package Scanning

COLA controllers live in `adapter/controller/`. Configure SpringDoc to scan only the adapter layer:

```yaml
springdoc:
  packages-to-scan: com.example.app.adapter.controller
  paths-to-match: /v1/**
```

This prevents domain/infrastructure internal classes from leaking into API documentation.