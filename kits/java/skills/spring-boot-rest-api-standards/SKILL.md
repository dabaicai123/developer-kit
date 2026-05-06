---
name: spring-boot-rest-api-standards
description: "REST API design standards for COLA/DDD projects: adapter layer controllers, Result<T> unified response, PageResult pagination, Cmd/Qry/VO data contracts, exception handling. Use when designing or reviewing REST interfaces, DTO models, pagination, and error responses in DDD/COLA projects."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot REST API Standards (COLA/DDD Mode)

## When to use

- Creating REST endpoints in the COLA **adapter layer**
- Designing Cmd/Qry/VO/DTO contracts for the **app layer**
- Implementing `Result<T>` / `PageResult<T>` unified response format
- Setting up pagination, filtering, and error handling patterns
- Reviewing REST API architecture in DDD projects

## Prerequisite

This skill assumes COLA/DDD architecture → see `ddd-cola`. Controllers belong to **adapter layer** (`adapter/web/`), request/response models span **app layer** (`app/`).

## Instructions

### 1. Resource-Based URLs → [cola-rest-patterns.md](references/cola-rest-patterns.md)

Use plural nouns, REST conventions (`GET /v1/orders`, `POST /v1/orders`). NOT action-based URLs like `/getOrderList` → use `GET /v1/orders`.

### 2. Result<T> Unified Response → [unified-result-pattern.md](references/unified-result-pattern.md)

All responses follow `{code, msg, data}` format. NOT `ResponseEntity`, `ProblemDetail`, or raw entity returns → use `Result<T>`.

Spring Boot 3.5 defaults ProblemDetail (`spring.mvc.problemdetails.enabled=true`). COLA projects must disable it: set `spring.mvc.problemdetails.enabled=false`.

### 3. COLA Controller (Adapter Layer) → [cola-rest-patterns.md](references/cola-rest-patterns.md)

Controllers in `adapter/web/` delegate to `app/service/`. No business logic, only routing. Service returns `Result<T>` directly — Controller does NOT wrap again.

### 4. Cmd/Qry/VO/DTO Contracts (App Layer) → [cola-rest-patterns.md](references/cola-rest-patterns.md)

- **Cmd**: write-path request body (e.g., `CreateOrderCmd`)
- **Qry**: read-path query parameters (e.g., `OrderQry`)
- **VO/DTO**: response body (e.g., `OrderDTO`)
- NOT domain entities or DO objects at adapter boundary → use Cmd/Qry/VO/DTO

### 5. Validation → `spring-boot-validation`

Use `@Valid` on `@RequestBody`, Jakarta annotations (`@NotBlank`, `@Size`). Validation messages in concise English.

### 6. Error Handling → `spring-boot-exception-handling`

`@RestControllerAdvice` catches `BusinessException` → `Result.fail(code, msg)`. NOT letting raw exceptions bubble up → catch globally.

### 7. Pagination → [cola-rest-patterns.md](references/cola-rest-patterns.md)

Return `Result<PageResult<T>>` for paginated endpoints. Use `PageResult.of(mpPage).map()` to convert MyBatis-Plus `Page<DO>` → `PageResult<VO>`.

### 8. Security Headers and CORS → `spring-boot-security`

## COLA Layer Mapping

| REST Element | COLA Layer | Package | Notes |
|-------------|-----------|---------|-------|
| Controller | Adapter | `adapter/web/` | Inbound handler, no business logic |
| Cmd (request body) | App | `app/` | Write-path input |
| Qry (query params) | App | `app/` | Read-path input |
| VO/DTO (response) | App | `app/` | Response output |
| Result<T>, PageResult<T> | Common | `common/result/` | Unified wrapper |
| GlobalExceptionHandler | Common | `common/exception/` | `@RestControllerAdvice` |
| NOT exposed | Domain | `domain/model/entity/` | Entities are internal |
| NOT exposed | Infrastructure | `infrastructure/mapper/` | DO objects are persistence-only |

## Rules

- NOT domain entities or DO objects at adapter boundary → use Cmd/Qry/VO/DTO
- NOT `ResponseEntity`, `ProblemDetail`, or raw objects → all responses use `Result<T>`
- NOT String error codes like "NOT_FOUND" → use integer HTTP status codes
- NOT raw exceptions bubbling up → `@RestControllerAdvice` catches all
- NOT unpaginated large result sets → `Result<PageResult<T>>`
- NOT sensitive data in responses or logs → no passwords, tokens, PII
- URL prefix `/v1/` → version API routes from the start
- Validation messages use concise English

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