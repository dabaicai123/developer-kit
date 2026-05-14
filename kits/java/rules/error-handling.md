---
paths:
  - "**/*.java"
---

# Rule: Java Error Handling

Enforce consistent error handling patterns across Spring Boot + MyBatis-Plus projects. For detailed examples, use the `spring-boot-exception-handling` skill.

## Guidelines

1. **Business exceptions** - use `BusinessException` subclasses such as `NotFoundException`, `InputValidationException`, and `UnauthorizedException`; use integer HTTP status codes, never string codes.
2. **COLA placement** - keep `BusinessException`, subclasses, and `ErrorCode` in `common.exception`; put `GlobalExceptionHandler` in adapter `web.advice`.
3. **Central handler** - use `@RestControllerAdvice` with typed `@ExceptionHandler` methods. Log business errors at `WARN`; log unexpected errors at `ERROR` with stack trace.
4. **API shape** - REST APIs return concrete `Result<T>` payloads with `code/msg/data`, such as `Result<UserDTO>` or `Result<Void>`. Avoid `Result<Object>`, `Result<?>`, and raw `Result`.
5. **Fail explicitly** - app/domain code throws specific exceptions for missing resources and business failures; it does not return `null` or throw generic `RuntimeException`.
6. **Log context** - include stable identifiers in logs, for example `username` or `orderId`; do not log only `getMessage()` for unexpected errors.

## Anti-Patterns

- Catching `Exception` and returning `null`.
- Using generic `RuntimeException` for business errors.
- Putting `@RestControllerAdvice` in `common`.
- Logging only `getMessage()` for unexpected errors.
- Swallowing exceptions silently.
- String error codes or duplicate code names with different meanings.
- Bare API objects, `Result<Object>`, `Result<?>`, or raw `Result`.
