---
name: spring-boot-exception-handling
description: "Global exception handling with @RestControllerAdvice, BusinessException hierarchy, error codes, unified Result<T> response. Use when implementing centralized error handling or defining custom business exceptions."
version: "1.2.0"
type: skill
---

# Spring Boot Exception Handling

Centralized error handling using `@RestControllerAdvice`, custom exception hierarchy, and unified `Result<T>`.

## When to use

- Implementing global exception handling
- Defining custom business exception hierarchy with error codes
- Handling field-level validation errors from `@Valid` / `@Validated`
- Deciding between global vs local exception handlers

## Instructions

### 1. Exception Hierarchy

Root: `BusinessException(int code, String msg)` with subclasses per HTTP status:

| Exception | HTTP Status | Use Case |
|-----------|-------------|----------|
| `NotFoundException` | 404 | Resource not found |
| `InputValidationException` | 400 | Business validation failure |
| `UnauthorizedException` | 401 | Authentication failure |
| `ForbiddenException` | 403 | Permission denied |
| `ConflictException` | 409 | State conflict or duplicate |
| `ExternalServiceUnavailableException` | 503 | External service down |

### 2. Error Code System

Format: module prefix (1-digit) + sequence (3-digit) + HTTP status suffix (3-digit). HTTP status derived via `errorCode % 1000`.

Example: `USER_NOT_FOUND = 104004` → module 1, sequence 04, HTTP 404.

### 3. GlobalExceptionHandler

```java
@RestControllerAdvice
@Slf4j
@Order(Ordered.HIGHEST_PRECEDENCE)
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusiness(BusinessException e) {
        log.warn("Business error: code={}, msg={}", e.getCode(), e.getMsg());
        return Result.fail(e.getCode(), e.getMsg());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
            .map(f -> f.getField() + ": " + f.getDefaultMessage())
            .collect(Collectors.joining("; "));
        log.warn("Validation error: {}", msg);
        return Result.fail(400000, msg);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public Result<Void> handleConstraintViolation(ConstraintViolationException ex) {
        String msg = ex.getConstraintViolations().stream()
            .map(v -> v.getPropertyPath() + ": " + v.getMessage())
            .collect(Collectors.joining("; "));
        log.warn("Constraint violation: {}", msg);
        return Result.fail(400000, msg);
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handleUnexpected(Exception e) {
        log.error("Unexpected error", e);
        return Result.fail(500000, "Internal server error");
    }
}
```

### 4. Global vs Local Handlers

- **Global** (`@RestControllerAdvice`): BusinessException, validation, unexpected errors — same format for all controllers
- **Local** (`@ExceptionHandler` on controller): controller-specific error detail or alternate response — overrides global for that controller

### 5. Logging Rules

- 4xx: `log.warn()` — no stack trace (expected client errors)
- 5xx: `log.error()` — full stack trace (bugs)
- Never log passwords, tokens, or PII in exception messages

## Rules

- All responses use `Result<T>` — NOT `ProblemDetail`, `ResponseEntity`, or raw objects
- Never expose stack traces in responses — catch-all returns generic message
- Throw `BusinessException` subclasses from service layer — NOT raw `RuntimeException`
- Use integer error codes — NOT String codes
- Handle both `MethodArgumentNotValidException` (`@Valid` on `@RequestBody`) and `ConstraintViolationException` (`@Validated` on path/query params)
- Catching `Exception` and swallowing prevents `@Transactional` rollback — re-throw or mark rollback-only
- Single `@RestControllerAdvice` with `@Order` — avoid multiple handlers for same exception type

## References

- `spring-boot-rest-api-standards/references/unified-result-pattern.md` — complete `Result.java` and `PageResult.java`
- [Full examples: hierarchy, ErrorCodes, ValidationError DTO](references/full-examples.md)

## Related Skills

- `spring-boot-validation` — produces `MethodArgumentNotValidException`
- `spring-boot-rest-api-standards` — unified `Result<T>` format
- `spring-boot-transaction-management` — rollback interaction with exception handling
