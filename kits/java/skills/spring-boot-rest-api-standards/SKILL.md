---
name: spring-boot-rest-api-standards
description: "REST API design standards for COLA/DDD projects: adapter layer controllers, Result<T> unified response, PageResult pagination, Cmd/Qry/DTO client contracts, exception handling. Use when designing or reviewing REST interfaces, DTO models, pagination, and error responses in DDD/COLA projects."
version: "1.1.0"
---

# Spring Boot REST API Standards (COLA/DDD Mode)

## When to use

- Creating REST endpoints in the COLA adapter layer.
- Designing Cmd/Qry/DTO contracts for the client module.
- Implementing `Result<T>` / `PageResult<T>` unified response format.
- Setting up pagination, filtering, and error handling patterns.
- Reviewing REST API architecture in DDD projects.

## Prerequisite

This skill assumes COLA/DDD architecture; see `ddd-cola`. Controllers belong to the adapter module (`web/` package), while Cmd/Qry/DTO contracts live in the client module (`dto/`, `dto.data/`).

## Instructions

### 1. Resource-Based URLs -> [cola-rest-patterns.md](references/cola-rest-patterns.md)

Use plural nouns and REST conventions: `GET /v1/orders`, `POST /v1/orders`. NOT action-based URLs like `/getOrderList`; use `GET /v1/orders`.

### 2. Result<T> Unified Response -> [unified-result-pattern.md](references/unified-result-pattern.md)

All responses follow `{code, msg, data}` format. NOT `ResponseEntity`, `ProblemDetail`, or raw entity returns; use `Result<T>`.

Always declare a concrete payload type: `Result<UserDTO>`, `Result<PageResult<UserDTO>>`, `Result<List<UserDTO>>`, or `Result<Void>` for no-payload responses. NOT `Result<Object>`, `Result<?>`, or raw `Result`; these break OpenAPI schemas and IDE inference. See [unified-result-pattern.md](references/unified-result-pattern.md) for the full type-parameter decision table.

Spring Boot 3.5 defaults ProblemDetail (`spring.mvc.problemdetails.enabled=true`). COLA projects must disable it: set `spring.mvc.problemdetails.enabled=false`.

### 3. COLA Controller (Adapter Layer) -> [cola-rest-patterns.md](references/cola-rest-patterns.md)

Controllers in the adapter module `web/` package delegate to `ServiceI`. The app module implements `ServiceI` and returns `Result<T>` directly, so the controller does not wrap again.

### 4. Cmd/Qry/DTO Contracts (Client Module) -> [cola-rest-patterns.md](references/cola-rest-patterns.md)

- **Cmd**: write-path request body, for example `CreateOrderCmd`.
- **Qry**: read-path query parameters, for example `OrderPageQry`.
- **DTO**: response body, for example `OrderDTO`.
- NOT domain entities or DO objects at adapter boundary; use Cmd/Qry/DTO from client.

### 5. Validation -> `spring-boot-validation`

Use `@Valid` on `@RequestBody`, Jakarta annotations (`@NotBlank`, `@Size`). Validation messages in concise English.

### 6. Error Handling -> `spring-boot-exception-handling`

The adapter module owns `@RestControllerAdvice` and catches `BusinessException` into `Result.fail(code, msg)`. `BusinessException` and subclasses stay in `common` as pure Java types; the handler must not live in `common` because `common` must not depend on Spring Web.

### 7. Pagination -> [cola-rest-patterns.md](references/cola-rest-patterns.md)

Return `Result<PageResult<T>>` for paginated endpoints. `PageResult` does not depend on MyBatis-Plus. In QryExe, use `PageResult.of(mpPage.getRecords(), mpPage.getTotal(), mpPage.getCurrent(), mpPage.getSize()).map()` to convert `Page<DO>` to `PageResult<DTO>`.

### 8. Security Headers and CORS -> `spring-boot-security`

## COLA Layer Mapping

| REST Element | COLA Layer | Package | Notes |
|-------------|-----------|---------|-------|
| Controller | Adapter | `web/` | Inbound handler, no business logic |
| Cmd (request body) | Client | `dto/` | Write-path input, flat fields |
| Qry (query params) | Client | `dto/` | Read-path input, flat fields |
| DTO (response) | Client | `dto.data/` | Response output, no domain VO refs |
| Result<T>, PageResult<T> | Common | `common.result` | Pure Java unified wrapper |
| BusinessException hierarchy | Common | `common.exception` | Pure Java exception types |
| GlobalExceptionHandler | Adapter | `web.advice` | `@RestControllerAdvice`, depends on common result/exception |
| NOT exposed | Domain | `domain.{domain}/` | Entities and value objects are internal |
| NOT exposed | Infrastructure | `{domain}.gatewayimpl.database.dataobject/` | DO objects are persistence-only |

## Rules

- NOT domain entities or DO objects at adapter boundary; use Cmd/Qry/DTO from client.
- NOT `ResponseEntity`, `ProblemDetail`, or raw objects; all responses use `Result<T>`.
- NOT String error codes like `"NOT_FOUND"`; use integer HTTP status codes.
- NOT raw exceptions bubbling up; adapter `@RestControllerAdvice` catches all.
- NOT unpaginated large result sets; use `Result<PageResult<T>>`.
- NOT sensitive data in responses or logs; no passwords, tokens, PII.
- URL prefix `/v1/`; version API routes from the start.
- Validation messages use concise English.

## References

- **[unified-result-pattern.md](references/unified-result-pattern.md)** - Result<T>, PageResult<T>, BusinessException, GlobalExceptionHandler full source.
- **[cola-rest-patterns.md](references/cola-rest-patterns.md)** - COLA controller + Cmd/Qry/DTO + pagination + filtering patterns.
- **[annotations-reference.md](references/annotations-reference.md)** - Core Spring Web + Jakarta validation annotations.

## Related Skills

- `ddd-cola` - COLA architecture, naming, CQRS paths (prerequisite).
- `spring-boot-exception-handling` - BusinessException hierarchy, error codes, GlobalExceptionHandler.
- `spring-boot-validation` - @Valid, @NotBlank, MethodArgumentNotValidException.
- `spring-boot-openapi-documentation` - Swagger/OpenAPI docs for REST endpoints.
