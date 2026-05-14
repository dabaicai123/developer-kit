---
name: spring-boot-exception-handling
description: "Global exception handling with adapter-layer @RestControllerAdvice, common-module BusinessException hierarchy, integer error codes, and unified Result<T> responses. Use when implementing centralized error handling or defining custom business exceptions."
version: "1.2.0"
---

# Spring Boot Exception Handling

Centralized error handling using adapter-layer `@RestControllerAdvice`, a pure Java `BusinessException` hierarchy in `common`, and unified `Result<T>`.

## When to use

- Implementing global exception handling.
- Defining custom business exception hierarchy with error codes.
- Handling field-level validation errors from `@Valid` / `@Validated`.
- Deciding between global vs local exception handlers.

## COLA Placement

- `BusinessException`, subclasses, and `ErrorCode` live in `common.exception`.
- `Result<T>` and `PageResult<T>` live in `common.result`.
- `GlobalExceptionHandler` lives in the adapter module, normally `web.advice`.
- Do not put `@RestControllerAdvice` in `common`; `common` must stay pure Java and must not depend on Spring Web.

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

Format: module prefix (1 digit) + sequence (3 digits) + HTTP status suffix (3 digits). HTTP status is derived via `errorCode % 1000`.

Example: `USER_NOT_FOUND = 104004` means module `1`, sequence `04`, HTTP `404`.

### 3. GlobalExceptionHandler

```java
package com.example.web.advice;

import com.example.common.exception.BusinessException;
import com.example.common.result.Result;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.stream.Collectors;

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

- **Global** (`@RestControllerAdvice`): BusinessException, validation, unexpected errors; same format for all controllers.
- **Local** (`@ExceptionHandler` on controller): controller-specific error detail or alternate response; overrides global for that controller.

### 5. Logging Rules

- 4xx: `log.warn()` with no stack trace for expected client/business errors.
- 5xx: `log.error()` with full stack trace for bugs.
- Never log passwords, tokens, or PII in exception messages.

## Rules

- All responses use `Result<T>`; NOT `ProblemDetail`, `ResponseEntity`, or raw objects.
- Never expose stack traces in responses; catch-all returns a generic message.
- Throw `BusinessException` subclasses from app/domain code; NOT raw `RuntimeException`.
- Use integer error codes; NOT String codes.
- Handle both `MethodArgumentNotValidException` (`@Valid` on `@RequestBody`) and `ConstraintViolationException` (`@Validated` on path/query params).
- Catching `Exception` and swallowing prevents `@Transactional` rollback; rethrow or mark rollback-only.
- Single `@RestControllerAdvice` with `@Order`; avoid multiple handlers for the same exception type.

## References

- `spring-boot-rest-api-standards/references/unified-result-pattern.md` - complete `Result.java`, `PageResult.java`, and COLA examples.
- [Full examples: hierarchy, ErrorCodes, ValidationError DTO](references/full-examples.md)

## Related Skills

- `spring-boot-validation` - produces `MethodArgumentNotValidException`.
- `spring-boot-rest-api-standards` - unified `Result<T>` format.
- `spring-boot-transaction-management` - rollback interaction with exception handling.
