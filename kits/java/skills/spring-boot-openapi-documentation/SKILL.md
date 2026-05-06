---
name: spring-boot-openapi-documentation
description: "SpringDoc 2.8.x + OpenAPI 3.0 spec for COLA/DDD projects: adapter controller annotations, Cmd/Qry/VO Schema labeling, Result<T> response patterns, JWT security scheme. Generates Swagger UI for REST APIs in DDD/COLA projects."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot OpenAPI Documentation (COLA/DDD Mode)

OpenAPI 3.0 documentation for Spring Boot 3.5.x REST APIs using SpringDoc 2.8.x.

## When to use this skill

- Set up SpringDoc 2.8.x and generate OpenAPI 3.0 specs for Spring Boot 3.5.x REST APIs
- Document controllers in the COLA adapter layer with OpenAPI annotations
- Document Cmd/Qry/VO models with `@Schema` annotations
- Configure Swagger UI for `Result<T>` unified response format
- Add JWT security scheme documentation
- Document pagination endpoints and error responses

## Prerequisites

This skill assumes COLA/DDD architecture (see `ddd-cola`). OpenAPI documentation targets the **adapter layer** (`adapter/web/`); annotated models span the **client module** (`client/dto/` — Cmd, Qry, VO).

## Instructions

### 1. Add Dependencies → [dependency-setup.md](references/dependency-setup.md)

### 2. Configure SpringDoc → [configuration.md](references/configuration.md)

```yaml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
  packages-to-scan: com.example.app.adapter.web
  paths-to-match: /v1/**
```

### 3. Document Controllers (Adapter Layer) → [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Controllers in `adapter/web/` use `@Tag(description=Chinese)` and `@Operation(summary=Chinese, description=Chinese)`. Responses use `Result<T>` and `Result<PageResult<T>>`.

### 4. Document Models (Client Module — Cmd/Qry/VO) → [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Cmd/Qry/VO/DTO use `@Schema(description=Chinese)`. Domain entities and DO objects are never annotated — they must not leak into API documentation.

### 5. Configure OpenAPI Bean + Security → [configuration.md](references/configuration.md)

```java
// infrastructure/config/OpenApiConfig.java
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

Apply `@SecurityRequirement(name = "bearer-jwt")` on controllers.

### 6. Document Pagination & Error Responses → [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Pagination: `@RequestParam` for page/pageSize with `Result<PageResult<T>>`. Errors: `Result<Void>` with error codes, documented via `@ApiResponse(description=Chinese)`.

### 7. Verify → Access Swagger UI at `/swagger-ui/index.html`

## COLA Layer Mapping

| OpenAPI Element | COLA Layer | Package | Annotate? |
|-----------------|-----------|---------|-----------|
| `@Tag`, `@Operation` | Adapter | `adapter/web/` | Yes |
| `@Schema` on Cmd/Qry/VO/DTO | Client | `client/dto/` | Yes |
| OpenAPI config, security scheme | Infrastructure | `infrastructure/config/` | Yes |
| Domain Entity | Domain | `domain/model/entity/` | **NOT** |
| DO Object | Infrastructure | `infrastructure/mapper/` | **NOT** |
| Gateway Interface | Domain | `domain/gateway/` | **NOT** |
| Gateway Implementation | Infrastructure | `infrastructure/` | **NOT** |

## Constraints and Warnings

**Anti-patterns**:

- **NOT annotating domain entities or DO objects with `@Schema`** — domain and persistence layers are internal; `@Schema` on them leaks internal structure into public API docs. Annotate only Cmd/Qry/VO/DTO in `client/dto/`.
- **NOT mixing SpringDoc v3.0.x with Spring Boot 3.5.x** — SpringDoc 3.0.x targets Spring Boot 4.0.x. For Spring Boot 3.5.x, use SpringDoc 2.8.x only.
- **NOT using SpringDoc < 2.8.9 with Spring Boot 3.5.x** — Spring Boot 3.5.0 renamed `HateoasProperties.getUseHalAsDefaultJsonMediaType()` to `isUseHalAsDefaultJsonMediaType()`, causing startup failure with older SpringDoc versions. Use SpringDoc >= 2.8.9.
- **NOT writing `@Schema` descriptions in English for Chinese-user-facing APIs** — all `@Tag`, `@Operation`, `@Schema`, `@ApiResponse` descriptions use Chinese. English identifiers (tag `name`, field names) are fine.
- **NOT exposing sensitive data in `@Schema(example=...)`** — passwords, tokens, and PII must not appear in examples. Use `accessMode = WRITE_ONLY` for passwords, `hidden = true` for internal fields.
- **NOT documenting every controller method with verbose `@ApiResponses`** — use global `OpenAPI` bean config for common responses; annotate only methods with non-standard responses.
- **NOT leaving admin/internal endpoints visible in Swagger UI** — hide them with `@Hidden` on the controller class or `@Operation(hidden = true)` on specific methods.

**Technical constraints**:

- **SpringDoc 2.8.x is the correct line for Spring Boot 3.5.x** — SpringDoc v3.0.x requires Spring Boot 4.0.x. The two lines are incompatible.
- **SpringDoc requires Jakarta EE 10 annotations** — `@NotNull`, `@NotBlank`, `@Size` etc. must use `jakarta.validation.*`, not `javax.validation.*`. SpringDoc auto-generates constraints from Jakarta validation.
- **Parameter names require compiler flag** — add `<parameters>true</parameters>` to `maven-compiler-plugin` configuration, or SpringDoc may fail to resolve method parameter names.
- **Security must permit Swagger endpoints** — add `/v3/api-docs/**`, `/swagger-ui/**` to `SecurityFilterChain` permit list, otherwise Swagger UI returns 401/403.

## References

- **[dependency-setup.md](references/dependency-setup.md)** — Maven/Gradle, version matrix, WebFlux variant, COLA package scanning
- **[configuration.md](references/configuration.md)** — SpringDoc config, OpenAPI bean, security, API groups, troubleshooting
- **[cola-openapi-patterns.md](references/cola-openapi-patterns.md)** — COLA controller + Cmd/Qry/VO + pagination + error patterns (Chinese descriptions)
- **[annotations-reference.md](references/annotations-reference.md)** — Core OpenAPI annotation reference

## Related Skills

- `ddd-cola` — COLA architecture, naming, CQRS paths (prerequisite)
- `spring-boot-rest-api-standards` — Result<T>, PageResult<T>, URL conventions
- `spring-boot-exception-handling` — Global handler, Result.fail(), error codes
- `spring-boot-validation` — @Valid, @NotBlank (auto-documented by SpringDoc)

## Keywords

openapi, swagger, springdoc, API docs, DDD, COLA, adapter layer, Result, PageResult, Cmd, Qry, VO, DTO, schema annotations, JWT, SpringDoc 2.8.x

## External Resources

- [SpringDoc Official Documentation](https://springdoc.org/)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)