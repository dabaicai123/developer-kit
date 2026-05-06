# SpringDoc Dependency Setup

## Maven

```xml
<!-- WebMVC (most COLA projects) -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.8.16</version>
</dependency>
```

WebFlux variant (reactive projects):

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webflux-ui</artifactId>
    <version>2.8.16</version>
</dependency>
```

## Gradle

```gradle
// WebMVC
implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.16'

// WebFlux
implementation 'org.springdoc:springdoc-openapi-starter-webflux-ui:2.8.16'
```

## Version Compatibility

| Spring Boot | SpringDoc | Notes |
|------------|-----------|-------|
| 3.5.x | >= 2.8.9 | Spring Boot 3.5.0 renamed HateoasProperties method; SpringDoc < 2.8.9 fails at startup |
| 3.4.x | 2.7.x – 2.8.x | |
| 3.3.x | 2.6.x | |

**NOT** using SpringDoc v3.0.x with Spring Boot 3.5.x — SpringDoc 3.0.x targets Spring Boot 4.0.x and is incompatible.

Check [Maven Central](https://mvnrepository.com/artifact/org.springdoc) for the latest stable version in the 2.8.x line.

## COLA Package Scanning

COLA controllers live in `adapter/web/`. Configure SpringDoc to scan only the adapter layer:

```yaml
springdoc:
  packages-to-scan: com.example.app.adapter.web
  paths-to-match: /v1/**
```

This prevents domain/infrastructure internal classes from leaking into API documentation.