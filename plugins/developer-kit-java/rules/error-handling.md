---
paths:
  - "**/*.java"
---

# Rule: Java Error Handling

## Context

Enforce consistent error handling patterns across Spring Boot + MyBatis-Plus projects, including business exception hierarchy, global exception handler, and unified Result response format.

## Guidelines

### Business Exception Hierarchy

Create a clear exception hierarchy for business logic errors:

```java
// Base business exception
public class BusinessException extends RuntimeException {
    private final String code;
    private final String message;

    public BusinessException(String code, String message) {
        super(message);
        this.code = code;
        this.message = message;
    }
}

// Specific business exceptions
public class NotFoundException extends BusinessException {
    public NotFoundException(String resource, Long id) {
        super("NOT_FOUND", resource + " not found: " + id);
    }
}

public class ValidationException extends BusinessException {
    public ValidationException(String message) {
        super("VALIDATION_ERROR", message);
    }
}

public class UnauthorizedException extends BusinessException {
    public UnauthorizedException(String message) {
        super("UNAUTHORIZED", message);
    }
}
```

### Global Exception Handler

Use `@RestControllerAdvice` for centralized exception handling:

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusinessException(BusinessException e) {
        log.warn("Business error: {} - {}", e.getCode(), e.getMsg());
        return Result.fail(e.getCode(), e.getMsg());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidation(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors()
            .stream().map(f -> f.getField() + ": " + f.getDefaultMessage())
            .collect(Collectors.joining("; "));
        return Result.fail(400, msg);
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handleUnexpected(Exception e) {
        log.error("Unexpected error", e);
        return Result.fail(500, "Internal server error");
    }
}
```

### Result Wrapper Pattern

Use the unified `Result<T>` with `PageData<T>` for all API responses. See `spring-boot-rest-api-standards/references/unified-result-pattern.md` for full definition.

```java
// Standard response format: {"code": 200, "msg": "success", "data": ...}
Result<UserVO> result = Result.success(userVO);           // single item
Result<PageData<UserVO>> result = Result.success(pageData); // page query
Result<Void> result = Result.success();                   // no data
Result<Void> result = Result.fail(404, "User not found"); // error
```

### BusinessException

Use integer HTTP status codes, never String codes:

```java
// Good: Integer code matching HTTP status
public class BusinessException extends RuntimeException {
    private final int code;
    private final String msg;
    public BusinessException(int code, String msg) {
        super(msg); this.code = code; this.msg = msg;
    }
}

public class NotFoundException extends BusinessException {
    public NotFoundException(String resource, Object id) {
        super(404, resource + " not found: " + id);
    }
}

// Bad: String code
public class BusinessException extends RuntimeException {
    private final String code; // WRONG: should be int
    public BusinessException(String code, String msg) { ... }
}
```

### Error Handling in Service Layer

```java
// Good: Throw specific business exceptions
public UserVO getById(Long id) {
    UserEntity entity = userMapper.selectById(id);
    if (entity == null) {
        throw new NotFoundException("User", id);
    }
    return convert(entity);
}

// Bad: Return null (silent failure)
public UserVO getById(Long id) {
    UserEntity entity = userMapper.selectById(id);
    return entity == null ? null : convert(entity); // WRONG: caller must handle null
}

// Bad: Generic exception
public UserVO getById(Long id) {
    UserEntity entity = userMapper.selectById(id);
    if (entity == null) {
        throw new RuntimeException("User not found"); // WRONG: too generic
    }
}
```

### Logging Errors

```java
// Good: Structured error logging with context
log.error("Failed to create user: username={}", dto.getUsername(), e);

// Bad: Unstructured logging
log.error("Something went wrong"); // WRONG: no context
log.error("Error: " + e.getMessage()); // WRONG: no stack trace
```

## Anti-Patterns

- Catching `Exception` and returning null — throw specific exceptions
- Using `RuntimeException` for business errors — use `BusinessException`
- Logging only `getMessage()` — include stack trace for unexpected errors
- Swallowing exceptions silently — always log or throw
- Returning null instead of throwing — fail explicitly