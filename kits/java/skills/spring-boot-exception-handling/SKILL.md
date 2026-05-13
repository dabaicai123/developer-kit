---
name: spring-boot-exception-handling
description: "Global exception handling with @RestControllerAdvice, custom exception hierarchy, @ExceptionHandler, unified Result<T> response, field-level validation errors, error code system, logging integration, and anti-patterns. Use when implementing centralized error handling or defining custom business exceptions."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Exception Handling

Patterns for centralized error handling using `@RestControllerAdvice`, custom exception hierarchy, and unified `Result<T>`.

## When to use this skill

- Implementing global exception handling with `@RestControllerAdvice`
- Defining a custom business exception hierarchy with error codes
- Returning consistent error responses with `Result<T>` format
- Handling field-level validation errors from `@Valid` / `@Validated`
- Integrating logging with exception handling for observability
- Deciding between global vs local exception handlers
- Establishing an error code system for API contracts

## Instructions

### 1. Define custom exception hierarchy + error code system

Create a structured exception hierarchy rooted in `BusinessException`. Use integer HTTP status codes, never String codes:

```java
/**
 * Base business exception — all custom exceptions extend this class.
 * <p>Carries an integer error code (maps to HTTP status) and a human-readable message.</p>
 */
public class BusinessException extends RuntimeException {
    private final int code;    // Full business error code (e.g., 104004)
    private final String msg;

    public BusinessException(int code, String msg) {
        super(msg);
        this.code = code;
        this.msg = msg;
    }

    /** HTTP status derived from the last 3 digits of the error code */
    public int httpStatus() {
        return ErrorCodes.httpStatus(code);
    }

    public int getCode() { return code; }
    public String getMsg() { return msg; }
}

/** Resource not found (404) */
public class NotFoundException extends BusinessException {
    public NotFoundException(int code, String msg) {
        super(code, msg);
    }
}

/** Validation or input error (400) */
public class InputValidationException extends BusinessException {
    public InputValidationException(int code, String msg) { super(code, msg); }
}

/** Authentication failure (401) */
public class UnauthorizedException extends BusinessException {
    public UnauthorizedException(int code, String msg) { super(code, msg); }
}

/** Permission denied (403) */
public class ForbiddenException extends BusinessException {
    public ForbiddenException(int code, String msg) { super(code, msg); }
}

/** State conflict or duplicate (409) */
public class ConflictException extends BusinessException {
    public ConflictException(int code, String msg) { super(code, msg); }
}

/** External service unavailable (503) */
public class ExternalServiceUnavailableException extends BusinessException {
    public ExternalServiceUnavailableException(int code, String msg) {
        super(code, msg);
    }
}
```

Error code system — each code maps to a specific business scenario. Format: module prefix (1-digit) + sequence number (3-digit) + HTTP status suffix (3-digit). HTTP status is derived via `errorCode % 1000`; business code is returned in `Result.code`.

```java
public final class ErrorCodes {
    // User module (1xxx)
    public static final int USER_NOT_FOUND       = 104004;
    public static final int USER_ALREADY_EXISTS   = 104009;
    public static final int USER_PASSWORD_INVALID = 104010;

    // Order module (2xxx)
    public static final int ORDER_NOT_FOUND       = 204004;
    public static final int ORDER_STATUS_INVALID   = 204009;
    public static final int ORDER_STOCK_INSUFFICIENT = 204010;

    // Payment module (3xxx)
    public static final int PAYMENT_TIMEOUT       = 305008;
    public static final int PAYMENT_SERVICE_DOWN  = 305003;

    /** Derive HTTP status from the error code structure */
    public static int httpStatus(int errorCode) {
        return errorCode % 1000;
    }
}

// Usage in service layer
public UserDO getUser(Long id) {
    return Optional.ofNullable(baseMapper.selectById(id))
        .orElseThrow(() -> new NotFoundException(ErrorCodes.USER_NOT_FOUND, "User not found: " + id));
}
```

### 2. Define Result<T> unified response wrapper

All API responses use `Result<T>` — `{"code":200,"msg":"success","data":...}` for success, `Result.fail(code, msg)` for errors. This is the project-specific convention; do not mix with `ProblemDetail` within the same API.

> **Note on `ProblemDetail` (RFC 7807)**: Spring Boot 3.5 natively supports `ProblemDetail` via `spring.mvc.problemdetails.enabled=true`. `ProblemDetail` is a valid industry standard for projects that adopt RFC 7807. This project uses `Result<T>` instead — the two formats should not be mixed in the same API contract.

### 3. Configure global handler with @RestControllerAdvice

All exceptions return `Result<Void>` with the unified `{"code":xxx,"msg":"xxx","data":null}` format:

```java
/**
 * Global exception handler — catches all exceptions and returns unified Result<Void> responses.
 * <p>Order determines handler priority; @Order ensures this handler runs before any others.
 * <p><b>Caution</b>: HIGHEST_PRECEDENCE overrides Spring Security's AccessDeniedException handler.
 * If Spring Security exception handling is required, use a lower precedence or add a dedicated
 * SecurityExceptionHandler with higher precedence.</p>
 */
@RestControllerAdvice
@Slf4j
@Order(Ordered.HIGHEST_PRECEDENCE)
public class GlobalExceptionHandler {

    /** Handle custom business exceptions with structured error codes */
    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusiness(BusinessException e) {
        log.warn("Business error: code={}, msg={}", e.getCode(), e.getMsg());
        return Result.fail(e.getCode(), e.getMsg());
    }

    /** Handle @Valid / @Validated field-level validation errors */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
            .map(f -> f.getField() + ": " + f.getDefaultMessage())
            .collect(Collectors.joining("; "));
        log.warn("Validation error: {}", msg);
        return Result.fail(400000, msg);
    }

    /** Handle @Validated path/query parameter constraint violations */
    @ExceptionHandler(ConstraintViolationException.class)
    public Result<Void> handleConstraintViolation(ConstraintViolationException ex) {
        String msg = ex.getConstraintViolations().stream()
            .map(v -> v.getPropertyPath() + ": " + v.getMessage())
            .collect(Collectors.joining("; "));
        log.warn("Constraint violation: {}", msg);
        return Result.fail(400000, msg);
    }

    /** Handle Spring HttpRequestMethodNotSupportedException (wrong HTTP method) */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public Result<Void> handleMethodNotSupported(HttpRequestMethodNotSupportedException e) {
        log.warn("Method not supported: {} for path {}", e.getMethod(), e.getMessage());
        return Result.fail(405000, "Unsupported request method: " + e.getMethod());
    }

    /** Catch-all for unexpected errors — never expose stack traces or internal details */
    @ExceptionHandler(Exception.class)
    public Result<Void> handleUnexpected(Exception e) {
        log.error("Unexpected error", e);
        return Result.fail(500000, "Internal server error");
    }
}
```

### 4. Field-level validation error response DTO

```java
public record ValidationError(
    int code,
    String msg,
    List<FieldErrorDetail> errors
) {
    public static ValidationError fromBindingResult(int code, BindingResult bindingResult) {
        List<FieldErrorDetail> details = bindingResult.getFieldErrors().stream()
            .map(f -> new FieldErrorDetail(f.getField(), f.getDefaultMessage(), f.getRejectedValue()))
            .toList();
        return new ValidationError(code, "Validation failed", details);
    }
}

public record FieldErrorDetail(
    String field,
    String message,
    Object rejectedValue
) {}
```

Return `Result<ValidationError>` when the API requires field-level detail; otherwise `Result<Void>`.

### 5. Decide between global vs local exception handlers

Global handlers (via `@RestControllerAdvice`) handle cross-cutting error patterns. Local handlers (via `@ExceptionHandler` on a specific `@RestController`) handle controller-specific scenarios:

```java
/**
 * Local exception handler — defined on a specific controller for targeted error handling.
 * <p>Local handlers override global handlers for the same exception type on that controller.</p>
 */
@RestController
@RequestMapping("/v1/orders")
@Slf4j
public class OrderController {

    private final OrderServiceI orderServiceI;

    /** Local handler for Order-specific conflict scenarios */
    @ExceptionHandler(ConflictException.class)
    public Result<Void> handleOrderConflict(ConflictException e) {
        // More specific handling for order conflicts, e.g., suggesting alternatives
        log.warn("Order conflict: {}", e.getMsg());
        return Result.fail(e.getCode(), e.getMsg() + " — Please check the order and retry");
    }
}
```

**Guidelines for choosing global vs local:**

| Scenario | Approach | Reason |
|---|---|---|
| BusinessException, validation, unexpected errors | Global `@RestControllerAdvice` | Cross-cutting; same format for all controllers |
| Controller-specific error detail or alternate response | Local `@ExceptionHandler` on controller | Override global for special cases |
| Both global and local handle the same exception type | Local wins for that controller | Spring resolves local first |

### 6. Logging rules

- 4xx (client errors): `log.warn()` — no stack trace; these are expected
- 5xx (server errors): `log.error()` — full stack trace; these indicate bugs
- Never log passwords, tokens, JWT secrets, or PII in exception messages

## Examples

### Example 1: Throwing BusinessException from service layer

```java
@Service
@RequiredArgsConstructor
public class OrderServiceImpl implements OrderServiceI {

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void create(CreateOrderCmd cmd) {
        // Validate business rules — throw NotFoundException if user does not exist
        UserDO user = userMapper.selectById(cmd.getUserId());
        if (user == null) {
            throw new NotFoundException(ErrorCodes.USER_NOT_FOUND, "User not found: " + cmd.getUserId());
        }

        // Validate business rules — throw ConflictException if duplicate order exists
        if (lambdaQuery().eq(OrderDO::getExternalRef, cmd.getExternalRef()).exists()) {
            throw new ConflictException(ErrorCodes.ORDER_STATUS_INVALID, "Order already exists, external ref: " + cmd.getExternalRef());
        }

        // Business logic proceeds...
        OrderDO order = OrderConverter.toDO(cmd);
        baseMapper.insert(order);
    }
}
```

### Example 2: Local handler overriding global for specific controller

```java
@RestController
@RequestMapping("/v1/payments")
@Slf4j
public class PaymentController {

    private final PaymentServiceI paymentServiceI;

    /** Local handler — more detailed response for payment-specific service unavailable errors */
    @ExceptionHandler(ExternalServiceUnavailableException.class)
    public Result<Void> handlePaymentUnavailable(ExternalServiceUnavailableException e) {
        log.warn("Payment service unavailable: {}", e.getMsg());
        // Return payment-specific guidance instead of generic 503
        return Result.fail(305003, "Payment service temporarily unavailable, please retry in 30 seconds");
    }
}
```

## Best Practices

- **All API responses use `Result<T>` wrapper** — `{"code":200,"msg":"success","data":...}`
- **Errors return `Result.fail(code, msg)`** — this project uses `Result<T>` as unified response contract. Do not mix `ProblemDetail` (RFC 7807) or `ResponseEntity`.
- **Never expose stack traces or internal details in responses** — the `Exception.class` catch-all must return a generic message
- **Log 4xx at WARN, 5xx at ERROR with full stack trace** — client errors are expected, server errors indicate bugs
- **Define a structured error code system** — per-module prefixes give clients programmatic error handling
- **Use `@Order(Ordered.HIGHEST_PRECEDENCE)` on global handler** — ensures it runs before framework handlers
- **Throw `BusinessException` subclasses from service layer** — let the global handler catch and format them

## Constraints and Warnings

- **Catching `Exception` and swallowing it** — prevents rollback in `@Transactional` methods. Either re-throw or use `TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()`.
- **Exposing stack traces in API responses** — leaks internal architecture, library versions, and file paths to attackers.
- **Using String error codes** — not sortable, not numeric, inconsistent with HTTP status conventions. Use integer codes.
- **Mixing `Result<T>` with `ProblemDetail` or `ResponseEntity`** — breaks unified response contract.
- **Throwing raw `RuntimeException` or `NullPointerException`** — unstructured, no error code, no business context. Always throw `BusinessException` subclasses.
- **Logging 4xx errors at ERROR level** — floods error logs with expected client mistakes. Use WARN for 4xx, ERROR for 5xx.
- **Catch-all handler that returns the exception message verbatim** — `return Result.fail(500, e.getMessage())` leaks internal details. Return a fixed generic message for 5xx.
- **Multiple `@RestControllerAdvice` classes handling the same exception type** — causes ambiguous handler resolution. Use a single global handler with `@Order`.
- **Duplicate enum constant names in ErrorCodes** — never define the same constant name twice with different codes. Use distinct names: `STRATEGY_CONFIG_NOT_FOUND = 404` vs `CHANNEL_STRATEGY_MISSING = 5002`.
- **`@RestControllerAdvice` catches exceptions from all controller types** — composed of `@ControllerAdvice` + `@ResponseBody`. Handles exceptions from both `@RestController` and `@Controller`.
- **Validation exception handler must handle both `MethodArgumentNotValidException` (from `@Valid` on `@RequestBody`) and `ConstraintViolationException` (from `@Validated` on path/query params)** — separate exception types with different message formats.
- **The catch-all `@ExceptionHandler(Exception.class)` must be defined last** — Spring resolves handlers by exception type specificity.

## References

- `spring-boot-rest-api-standards/references/unified-result-pattern.md` — complete `Result.java` and `PageResult.java` definition
- `spring-boot-validation` — Jakarta Bean Validation patterns that produce `MethodArgumentNotValidException`

## Related Skills

- `spring-boot-validation` — `@Valid` / `@Validated` produces `MethodArgumentNotValidException` handled by global handler
- `spring-boot-rest-api-standards` — unified `Result<T>` response format and API design
- `spring-boot-transaction-management` — `@Transactional` rollback rules interact with exception handling; swallowing exceptions prevents rollback
- `spring-boot-logging` — structured logging patterns for exception observability
- `spring-boot-resilience4j` — Resilience4j exceptions (`CallNotPermittedException`, `BulkheadFullException`) need dedicated handlers
- `spring-cloud-openfeign` — `ErrorDecoder` translates remote exceptions into local `BusinessException`
- `unit-test-exception-handler` — testing global exception handler behavior

## Keywords

exception handling, @RestControllerAdvice, @ExceptionHandler, BusinessException, Result, error code, validation error, field error, global handler, local handler, NotFoundException, ConflictException, ExternalServiceUnavailableException, InputValidationException, logging, anti-patterns, stack trace, rollback, ConstraintViolationException, ProblemDetail, RFC 7807