---
name: spring-boot-openapi-documentation
description: "COLA/DDD 项目的 SpringDoc OpenAPI 3.0 API 文档：适配层控制器注解、Cmd/Qry/VO 的 Schema 标注、Result<T> 响应模式、安全方案文档。用于在 DDD/COLA 项目中为 REST API 生成 Swagger 文档、配置 Swagger UI、标注 controller 及 VO/DTO/Cmd 模型。"
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot OpenAPI Documentation (COLA/DDD Mode)

## When to use this skill

- Set up SpringDoc OpenAPI and generate OpenAPI 3.0 specs for Spring Boot 3.x REST APIs
- Document controllers in the COLA **adapter layer** with OpenAPI annotations
- Document VO/Cmd/Qry models in the **app layer** with `@Schema` annotations
- Configure Swagger UI for `Result<T>` unified response format
- Implement API security documentation (JWT)
- Document pageable/sortable endpoints and add examples/schemas

## Prerequisite

This skill assumes the project follows COLA/DDD architecture → see `ddd-cola`. OpenAPI documentation belongs to the **adapter layer** (`adapter/controller/`), and annotated models span the **app layer** (`app/` — Cmd, Qry, VO) and **domain layer** (only DTO that crosses boundaries).

## Instructions

### 1. Add Dependencies → [dependency-setup.md](references/dependency-setup.md)

### 2. Configure SpringDoc → [configuration.md](references/configuration.md)

Basic `application.yml`:

```yaml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
  packages-to-scan: com.example.app.adapter.controller
  paths-to-match: /v1/**
```

### 3. Document Controllers (Adapter Layer) → [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Controllers in `adapter/controller/` use `@Tag(description=中文)` and `@Operation(summary=中文, description=中文)`. Responses use `Result<T>` and `Result<PageResult<T>>`.

### 4. Document Models (App Layer — Cmd/Qry/VO) → [cola-openapi-patterns.md](references/cola-openapi-patterns.md)

Cmd/Qry/VO/DTO use `@Schema(description=中文)`. **Domain entities and DO objects are never annotated** — they are internal and must not leak into API documentation.

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

Pagination: `@ParameterObject Pageable` with `Result<PageResult<T>>`. Errors: `Result<Void>` with error codes, documented via `@ApiResponse(description=中文)`.

### 7. Verify → Access Swagger UI at `/swagger-ui/index.html`

## COLA Layer Mapping

| OpenAPI Element | COLA Layer | Package | Annotate? |
|-----------------|-----------|---------|-----------|
| `@Tag`, `@Operation` | Adapter | `adapter/controller/` | **Yes** |
| `@Schema` on Cmd/Qry/VO/DTO | App | `app/` | **Yes** |
| OpenAPI config, security scheme | Infrastructure | `infrastructure/config/` | **Yes** (bean config) |
| Domain Entity | Domain | `domain/model/entity/` | **Never** |
| DO Object | Infrastructure | `infrastructure/mapper/` | **Never** |

## Rules

- **Never annotate domain entities or DO objects** — internal layers must not leak into API docs
- **All `@Tag`, `@Operation`, `@Schema`, `@ApiResponse` descriptions use Chinese** — the docs serve Chinese-speaking users
- **Use `Result<T>` / `PageResult<T>` consistently** → see `spring-boot-rest-api-standards`
- **Never expose sensitive data** in `@Schema(example=...)` — no passwords, tokens, PII
- **Keep annotations minimal on controllers** — use global OpenAPI bean config when possible
- **Hide internal endpoints** with `@Hidden` — never expose admin controllers in public API groups

## References

- **[dependency-setup.md](references/dependency-setup.md)** — Maven/Gradle, version matrix, COLA package scanning
- **[configuration.md](references/configuration.md)** — SpringDoc config, OpenAPI bean, security, API groups, troubleshooting
- **[cola-openapi-patterns.md](references/cola-openapi-patterns.md)** — COLA controller + Cmd/Qry/VO + pagination + error patterns (Chinese descriptions)
- **[annotations-reference.md](references/annotations-reference.md)** — Core OpenAPI annotation reference

## Related Skills

- `ddd-cola` — COLA architecture, naming, CQRS paths (prerequisite)
- `spring-boot-rest-api-standards` — Result<T>, PageResult<T>, URL conventions
- `spring-boot-exception-handling` — Global handler, Result.fail(), error codes
- `spring-boot-validation` — @Valid, @NotBlank (auto-documented by SpringDoc)

## Keywords

openapi, swagger, springdoc, API 文档, DDD, COLA, adapter layer, Result, PageResult, Cmd, Qry, VO, DTO, schema annotations, JWT

## External Resources

- [SpringDoc Official Documentation](https://springdoc.org/)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)