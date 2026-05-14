---
name: spring-boot-openapi-documentation
description: "Documents Spring Boot REST APIs with SpringDoc 2.8.x, OpenAPI 3.0, COLA/DDD adapter controllers, client-module Cmd/Qry/DTO schemas, Result<T> responses, JWT security schemes, and Swagger UI. Use when generating or reviewing API documentation."
version: "1.1.0"
---

# Spring Boot OpenAPI Documentation (COLA/DDD Mode)

OpenAPI 3.0 documentation for Spring Boot 3.5.x REST APIs using SpringDoc 2.8.x.

## When to use this skill

- Set up SpringDoc 2.8.x and generate OpenAPI 3.0 specs for Spring Boot 3.5.x REST APIs.
- Document controllers in the COLA adapter layer with OpenAPI annotations.
- Document client-module Cmd/Qry/DTO models with `@Schema` annotations.
- Configure Swagger UI for `Result<T>` unified response format.
- Add JWT security scheme documentation.
- Document pagination endpoints and error responses.

## Prerequisites

This skill assumes COLA/DDD architecture; see `ddd-cola`. OpenAPI documentation targets the adapter module (`web/` package). Annotated API models live in the client module (`dto/` and `dto.data/`).

## Instructions

### 1. Add Dependencies -> [dependency-setup.md](references/dependency-setup.md)

Use SpringDoc 2.8.x for Spring Boot 3.5.x. Do not use SpringDoc 3.x unless the project is on Spring Boot 4.x.

### 2. Configure SpringDoc -> [configuration.md](references/configuration.md)

```yaml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
  packages-to-scan: com.example.web
  paths-to-match: /v1/**
```

### 3. Document Controllers (Adapter Layer) -> [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Controllers in the adapter module `web/` package use `@Tag(description=Chinese)` and `@Operation(summary=Chinese, description=Chinese)`. Responses use `Result<T>` and `Result<PageResult<T>>`.

### 4. Document Models (Client Module) -> [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Cmd/Qry/DTO classes in the client module use `@Schema(description=Chinese)`. Domain entities, domain VOs, Gateway interfaces, Gateway implementations, and DO objects are internal and must not be annotated for public API documentation.

### 5. Configure OpenAPI Bean + Security -> [configuration.md](references/configuration.md)

```java
// infrastructure module: config/OpenApiConfig.java
@Configuration
public class OpenApiConfig {
    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("订单服务 API")
                .version("v1.0")
                .description("订单管理服务接口文档"))
            .components(new Components()
                .addSecuritySchemes("bearer-jwt", new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")));
    }
}
```

Apply `@SecurityRequirement(name = "bearer-jwt")` on secured controllers.

### 6. Document Pagination & Error Responses -> [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Pagination uses a Qry object and `Result<PageResult<T>>`. Errors use `Result<Void>` with integer error codes and are documented via `@ApiResponse(description=Chinese)`.

### 7. Verify

Access Swagger UI at `/swagger-ui/index.html`.

## COLA Layer Mapping

| OpenAPI Element | COLA Layer | Package | Annotate? |
|-----------------|-----------|---------|-----------|
| `@Tag`, `@Operation` | Adapter | `web/` | Yes |
| `@Schema` on Cmd/Qry/DTO | Client | `dto/`, `dto.data/` | Yes |
| OpenAPI config, security scheme | Infrastructure | `config/` | Yes |
| Domain Entity / VO | Domain | `domain.{domain}/`, `domain.{domain}.vo/` | No |
| DO Object | Infrastructure | `{domain}.gatewayimpl.database.dataobject/` | No |
| Gateway Interface | Domain | `domain.{domain}.gateway/` | No |
| Gateway Implementation | Infrastructure | `{domain}/` | No |

## Constraints and Warnings

- Do not annotate domain entities, domain VOs, or DO objects with `@Schema`; they are internal and must not leak into API docs.
- Do not mix SpringDoc 3.x with Spring Boot 3.5.x; use SpringDoc 2.8.x.
- Do not use SpringDoc < 2.8.9 with Spring Boot 3.5.x.
- Do not write `@Schema` descriptions in English for Chinese-user-facing APIs. English identifiers are fine.
- Do not expose passwords, tokens, or PII in `@Schema(example=...)`; use `accessMode = WRITE_ONLY` or `hidden = true`.
- Do not document every method with verbose `@ApiResponses`; use global OpenAPI config for common responses and annotate only non-standard responses.
- Do not leave admin/internal endpoints visible in Swagger UI; use `@Hidden` or `@Operation(hidden = true)`.
- SpringDoc requires Jakarta validation annotations (`jakarta.validation.*`), not `javax.validation.*`.
- Add `<parameters>true</parameters>` to `maven-compiler-plugin`, or SpringDoc may fail to resolve method parameter names.
- Security must permit `/v3/api-docs/**` and `/swagger-ui/**`, otherwise Swagger UI returns 401/403.

## References

- **[dependency-setup.md](references/dependency-setup.md)** - Maven/Gradle, version matrix, WebFlux variant, COLA package scanning.
- **[configuration.md](references/configuration.md)** - SpringDoc config, OpenAPI bean, security, API groups, troubleshooting.
- **[cola-openapi-patterns.md](references/cola-openapi-patterns.md)** - COLA controller + Cmd/Qry/DTO + pagination + error patterns.
- **[annotations-reference.md](references/annotations-reference.md)** - Core OpenAPI annotation reference.

## Related Skills

- `ddd-cola`
- `spring-boot-rest-api-standards`
- `spring-boot-exception-handling`
- `spring-boot-validation`
