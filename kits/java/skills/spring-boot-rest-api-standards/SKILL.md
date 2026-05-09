---
name: spring-boot-rest-api-standards
description: "COLA/DDD 项目的 REST API 设计规范：适配层控制器、Result<T> 统一响应、PageResult 分页、Cmd/Qry/VO 数据契约、异常处理。用于在 DDD/COLA 项目中设计或审查 REST 接口、DTO 模型、分页与错误响应。"
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot REST API Standards (COLA/DDD Mode)

## When to use this skill

- Creating REST endpoints in the COLA **adapter layer**
- Designing Cmd/Qry/VO/DTO contracts for the **app layer**
- Implementing `Result<T>` / `PageResult<T>` unified response format
- Setting up pagination, filtering, and error handling patterns
- Reviewing REST API architecture in DDD projects

## Prerequisite

This skill assumes the project follows COLA/DDD architecture → see `ddd-cola`. REST controllers belong to the **adapter layer** (`adapter/controller/`), request/response models span the **app layer** (`app/` — Cmd, Qry, VO, DTO).

## Instructions

### 1. Design Resource-Based URLs → [cola-rest-patterns.md](references/cola-rest-patterns.md)

Use plural nouns, REST conventions (`GET /v1/orders`, `POST /v1/orders`). Never action-based URLs like `/getOrderList`.

### 2. Use Result<T> Unified Response → [unified-result-pattern.md](references/unified-result-pattern.md)

All API responses follow `{code, msg, data}` format. Never use `ResponseEntity`, `ProblemDetail`, or raw entity returns.

### 3. Create COLA Controller (Adapter Layer) → [cola-rest-patterns.md](references/cola-rest-patterns.md)

Controllers in `adapter/controller/` delegate to `app/service/`. They contain no business logic, only routing + `Result<T>` wrapping.

### 4. Design Cmd/Qry/VO/DTO Contracts (App Layer) → [cola-rest-patterns.md](references/cola-rest-patterns.md)

- **Cmd**: write-path request body (e.g., `CreateOrderCmd`)
- **Qry**: read-path query parameters (e.g., `OrderQry`)
- **VO/DTO**: response body (e.g., `OrderDTO`)
- Never expose domain entities or DO objects directly

### 5. Implement Validation → `spring-boot-validation`

Use `@Valid` on `@RequestBody`, Jakarta annotations (`@NotBlank`, `@Size`). Validation messages use Chinese.

### 6. Handle Errors → `spring-boot-exception-handling`

`@RestControllerAdvice` catches `BusinessException` → `Result.fail(code, msg)`. Validation errors → `Result.fail(400, msg)`. Never let raw exceptions bubble up.

### 7. Configure Pagination → [cola-rest-patterns.md](references/cola-rest-patterns.md)

Return `Result<PageResult<T>>` for paginated endpoints. Use `PageResult.of(mpPage).map()` to convert MyBatis-Plus `Page<DO>` → `PageResult<VO>`.

### 8. Security Headers and CORS → `spring-boot-security`

## COLA Layer Mapping

| REST Element | COLA Layer | Package | Notes |
|-------------|-----------|---------|-------|
| Controller | Adapter | `adapter/controller/` | Inbound handler, no business logic |
| Cmd (request body) | App | `app/` | Write-path input |
| Qry (query params) | App | `app/` | Read-path input |
| VO/DTO (response) | App | `app/` | Response output |
| Result<T>, PageResult<T> | Common | `common/result/` | Unified wrapper |
| GlobalExceptionHandler | Common | `common/exception/` | `@RestControllerAdvice` |
| **Never expose** | Domain | `domain/model/entity/` | Entities are internal |
| **Never expose** | Infrastructure | `infrastructure/mapper/` | DO objects are persistence-only |

## Rules

- **Never expose domain entities or DO objects** — use Cmd/Qry/VO/DTO at the adapter boundary
- **All API responses use `Result<T>`** — never `ResponseEntity`, `ProblemDetail`, or raw objects
- **Validation messages use Chinese** — `@NotBlank(message = "客户 ID 不能为空")`
- **Handle all exceptions globally** — `@RestControllerAdvice`, never let raw exceptions bubble up
- **Always paginate large result sets** — `Result<PageResult<T>>`, prevent DDoS/performance issues
- **Never expose sensitive data** — no passwords, tokens, PII in responses or logs
- **Integer error codes only** — never String codes like "NOT_FOUND"; always use HTTP status integers
- **URL prefix `/v1/`** — version your API routes from the start

## References

- **[unified-result-pattern.md](references/unified-result-pattern.md)** — Result<T>, PageResult<T>, BusinessException, GlobalExceptionHandler full source
- **[cola-rest-patterns.md](references/cola-rest-patterns.md)** — COLA controller + Cmd/Qry/VO + pagination + filtering patterns
- **[annotations-reference.md](references/annotations-reference.md)** — Core Spring Web + Jakarta validation annotations

## Related Skills

- `ddd-cola` — COLA architecture, naming, CQRS paths (prerequisite)
- `spring-boot-exception-handling` — BusinessException hierarchy, error codes, GlobalExceptionHandler
- `spring-boot-validation` — @Valid, @NotBlank, MethodArgumentNotValidException
- `spring-boot-openapi-documentation` — Swagger/OpenAPI docs for REST endpoints

## Keywords

REST API, Result, PageResult, Cmd, Qry, VO, DTO, adapter layer, COLA, DDD, pagination, error handling, BusinessException, validation