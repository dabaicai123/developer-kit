---
name: spring-boot-exception-handling
description: Global exception handling patterns for Spring Boot 3.5.x with @RestControllerAdvice, custom exceptions, and unified Result response. Use when implementing centralized error handling.
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Exception Handling

Centralized error handling for Spring Boot 3.5.x using unified `Result<T>` response format.

## When to use this skill

- Implementing global exception handling
- Defining custom business exceptions
- Returning consistent error responses with `Result<T>` format

## Custom Exceptions

Use integer HTTP status codes, never String codes:

```java
public class BusinessException extends RuntimeException {
    private final int code;
    private final String msg;

    public BusinessException(int code, String msg) {
        super(msg);
        this.code = code;
        this.msg = msg;
    }
}

public class NotFoundException extends BusinessException {
    public NotFoundException(String resource, Object id) {
        super(404, resource + " not found: " + id);
    }
}

public class ValidationException extends BusinessException {
    public ValidationException(String msg) { super(400, msg); }
}

public class UnauthorizedException extends BusinessException {
    public UnauthorizedException(String msg) { super(401, msg); }
}

public class ForbiddenException extends BusinessException {
    public ForbiddenException(String msg) { super(403, msg); }
}
```

## Global Handler

All exceptions return `Result<Void>` with the unified `{"code":xxx,"msg":"xxx","data":null}` format:

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusiness(BusinessException e) {
        log.warn("Business error: {} - {}", e.getCode(), e.getMsg());
        return Result.fail(e.getCode(), e.getMsg());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
            .map(f -> f.getField() + ": " + f.getDefaultMessage())
            .collect(Collectors.joining("; "));
        log.warn("Validation error: {}", msg);
        return Result.fail(400, msg);
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handleUnexpected(Exception e) {
        log.error("Unexpected error", e);
        return Result.fail(500, "Internal server error");
    }
}
```

## See Also

See `spring-boot-rest-api-standards/references/unified-result-pattern.md` for the complete `Result.java` and `PageResult.java` definition.

## Best Practices

- All API responses use `Result<T>` wrapper — `{"code":200,"msg":"success","data":...}`
- Errors return `Result.fail(code, msg)` — never ProblemDetail or ResponseEntity
- Use integer HTTP status codes (400, 404, 500) — never String codes ("NOT_FOUND", "ERROR")
- Never expose stack traces or internal details in responses
- Log unexpected errors with full stack trace at ERROR level