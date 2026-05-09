---
name: spring-boot-exception-handling
description: "Global exception handling for Spring Boot 3.5.x with @RestControllerAdvice, custom exception hierarchy, @ExceptionHandler, unified Result<T> response, field-level validation errors, error code system, logging integration, and anti-patterns. Use when implementing centralized error handling or defining custom business exceptions."
version: "1.0.0"
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
    public NotFoundException(String resource, Object id) {
        super(404, resource + " not found: " + id);
    }
}

/** Validation or input error (400) */
public class ValidationException extends BusinessException {
    public ValidationException(String msg) { super(400, msg); }
}

/** Authentication failure (401) */
public class UnauthorizedException extends BusinessException {
    public UnauthorizedException(String msg) { super(401, msg); }
}

/** Permission denied (403) */
public class ForbiddenException extends BusinessException {
    public ForbiddenException(String msg) { super(403, msg); }
}

/** State conflict or duplicate (409) */
public class ConflictException extends BusinessException {
    public ConflictException(String msg) { super(409, msg); }
}

/** External service unavailable (503) */
public class ServiceUnavailableException extends BusinessException {
    public ServiceUnavailableException(String service) {
        super(503, service + " unavailable");
    }
}
```

Error code system — each code maps to a specific business scenario. Format: module prefix + sequential number (e.g., USER_1001). HTTP status is derived from the code prefix; business code is returned in Result.code.

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

### 3. Configure global handler with @RestControllerAdvice

All exceptions return `Result<Void>` with the unified `{"code":xxx,"msg":"xxx","data":null}` format:

```java
/**
 * Global exception handler — catches all exceptions and returns unified Result<Void> responses.
 * <p>Order determines handler priority; @Order ensures this handler runs before any others.</p>
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
        return Result.fail(405000, "Method not allowed: " + e.getMethod());
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
@RequestMapping("/api/v1/orders")
@Slf4j
public class OrderController {

    private final OrderService orderService;

    /** Local handler for Order-specific conflict scenarios */
    @ExceptionHandler(ConflictException.class)
    public Result<Void> handleOrderConflict(ConflictException e) {
        // More specific handling for order conflicts, e.g., suggesting alternatives
        log.warn("Order conflict: {}", e.getMsg());
        return Result.fail(e.getCode(), e.getMsg() + " — please review your order and retry");
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
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void create(OrderCreateDTO dto) {
        // Validate business rules — throw NotFoundException if user does not exist
        UserDO user = userMapper.selectById(dto.getUserId());
        if (user == null) {
            throw new NotFoundException("User", dto.getUserId());
        }

        // Validate business rules — throw ConflictException if duplicate order exists
        if (lambdaQuery().eq(OrderDO::getExternalRef, dto.getExternalRef()).exists()) {
            throw new ConflictException("Order already exists with ref: " + dto.getExternalRef());
        }

        // Business logic proceeds...
        OrderDO order = OrderConverter.toDO(dto);
        baseMapper.insert(order);
    }
}
```

### Example 2: Local handler overriding global for specific controller

```java
@RestController
@RequestMapping("/api/v1/payments")
@Slf4j
public class PaymentController {

    private final PaymentService paymentService;

    /** Local handler — more detailed response for payment-specific service unavailable errors */
    @ExceptionHandler(ServiceUnavailableException.class)
    public Result<Void> handlePaymentUnavailable(ServiceUnavailableException e) {
        log.warn("Payment service unavailable: {}", e.getMsg());
        // Return payment-specific guidance instead of generic 503
        return Result.fail(305003, "Payment processing is temporarily unavailable. Please retry after 30 seconds.");
    }
}
```

## Best Practices

- **All API responses use `Result<T>` wrapper** — `{"code":200,"msg":"success","data":...}`
- **Errors return `Result.fail(code, msg)`** — never `ProblemDetail` or `ResponseEntity`
- **Never expose stack traces or internal details in responses** — the `Exception.class` catch-all must return a generic message
- **Log 4xx at WARN, 5xx at ERROR with full stack trace** — client errors are expected, server errors indicate bugs
- **Never log passwords, tokens, JWT secrets, or PII in exception messages**
- **Define a structured error code system** — per-module prefixes give clients programmatic error handling
- **Avoid duplicate error code names** — even if two scenarios seem similar (both "not found"), use distinct names reflecting the specific semantics. `STRATEGY_CONFIG_NOT_FOUND` vs `CHANNEL_STRATEGY_MISSING` is better than `STRATEGY_NOT_FOUND` appearing twice with different codes.
- **Use `@Order(Ordered.HIGHEST_PRECEDENCE)` on global handler** — ensures it runs before any framework handlers
- **Throw `BusinessException` subclasses from service layer** — let the global handler catch and format them
- **Prefer throwing exceptions over returning error Result from service methods** — keeps service signatures clean and lets the handler normalize the response

## Constraints and Warnings

**Anti-patterns**:

- **Catching `Exception` and swallowing it** — prevents rollback in `@Transactional` methods; the proxy only sees a normal return. Either re-throw or use `TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()`.
- **Exposing stack traces in API responses** — leaks internal architecture, library versions, and file paths to attackers.
- **Using String error codes** (`"NOT_FOUND"`, `"ERROR"`) — not sortable, not numeric, inconsistent with HTTP status conventions. Use integer codes.
- **Returning `ResponseEntity` or `ProblemDetail`** — breaks the unified `Result<T>` contract. Always use `Result.fail()`.
- **Throwing raw `RuntimeException` or `NullPointerException``** — unstructured, no error code, no business context. Always throw `BusinessException` subclasses.
- **Logging 4xx errors at ERROR level** — floods error logs with expected client mistakes. Use WARN for 4xx, ERROR for 5xx.
- **Re-validating in service layer after controller `@Valid`** — redundant and wasteful. Validate at the controller boundary only.
- **Catch-all handler that returns the exception message verbatim** — `return Result.fail(500, e.getMessage())` leaks internal details. Return a fixed generic message for 5xx.
- **Multiple `@RestControllerAdvice` classes handling the same exception type** — causes ambiguous handler resolution. Use a single global handler with `@Order`.
- **Duplicate enum constant names in ErrorCodes** — never define the same constant name twice with different codes (e.g., `STRATEGY_NOT_FOUND = 404` and `STRATEGY_NOT_FOUND = 5002`). Java enum/constants must be unique by name. When two errors have similar names but different semantics, use distinct names: `STRATEGY_CONFIG_NOT_FOUND = 404` vs `CHANNEL_STRATEGY_MISSING = 5002`.

**Technical constraints**:

- **`@RestControllerAdvice` only handles exceptions from `@RestController` methods** — it does not catch exceptions from filters, interceptors, or `@Controller` (non-REST) classes. For those, use `@ControllerAdvice` or register error pages.
- **Validation exception handler must handle both `MethodArgumentNotValidException` (from `@Valid` on `@RequestBody`) and `ConstraintViolationException` (from `@Validated` on path/query params)** — these are separate exception types with different message formats.
- **The catch-all `@ExceptionHandler(Exception.class)` must be defined last** — Spring resolves handlers by exception type specificity; more specific types are matched first.
- **Never expose stack traces, SQL statements, or internal class names in error responses** — these are security risks that leak implementation details.

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

exception handling, @RestControllerAdvice, @ExceptionHandler, BusinessException, Result, error code, validation error, field error, global handler, local handler, NotFoundException, ConflictException, ServiceUnavailableException, logging, anti-patterns, stack trace, rollback, ConstraintViolationException