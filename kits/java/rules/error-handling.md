---
paths:
  - "**/*.java"
---

# Rule: Java Error Handling

Enforce consistent error handling patterns across Spring Boot + MyBatis-Plus projects. For detailed examples, use the `spring-boot-exception-handling` skill.

## Guidelines

1. **Use `BusinessException` hierarchy** — create specific subclasses (`NotFoundException`, `ValidationException`, `UnauthorizedException`) with integer HTTP status codes, never String codes.

2. **Use `@RestControllerAdvice`** — centralized exception handling with `@ExceptionHandler` for each exception type. Log business errors at `WARN`, unexpected errors at `ERROR` with stack trace.

3. **Use unified `Result<T>` wrapper** — all API responses must follow `code/msg/data` format. Use `Result.success(data)` for success, `Result.fail(intCode, msg)` for errors. Never return bare objects or `ResponseEntity`. Always declare a concrete payload type (`Result<UserVO>`, `Result<PageResult<UserVO>>`, `Result<List<UserVO>>`, `Result<Void>`); never `Result<Object>`, `Result<?>`, or raw `Result` — those break OpenAPI schemas and hide DTO contract drift.

4. **Throw specific exceptions from Service layer** — never return null for missing resources (throw `NotFoundException`). Never use generic `RuntimeException` for business errors.

5. **Log with context** — `log.error("Failed to create user: username={}", dto.getUsername(), e)`. Never log only `getMessage()` without stack trace.

## Anti-Patterns

- Catching `Exception` and returning null — throw specific exceptions
- Using `RuntimeException` for business errors — use `BusinessException`
- Logging only `getMessage()` — include stack trace for unexpected errors
- Swallowing exceptions silently — always log or throw
- Returning null instead of throwing — fail explicitly
- String error codes — use integer HTTP status codes
- Duplicate error code names with different values — use distinct names for different semantics
- Bare objects in API responses — use `Result<T>` wrapper
- `Result<Object>` / `Result<?>` / raw `Result` — declare the concrete payload type