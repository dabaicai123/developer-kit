# Exception Handling Full Examples

## BusinessException Hierarchy

```java
public class BusinessException extends RuntimeException {
    private final int code;
    private final String msg;

    public BusinessException(int code, String msg) {
        super(msg);
        this.code = code;
        this.msg = msg;
    }

    public int httpStatus() { return ErrorCodes.httpStatus(code); }
    public int getCode() { return code; }
    public String getMsg() { return msg; }
}

public class NotFoundException extends BusinessException {
    public NotFoundException(int code, String msg) { super(code, msg); }
}

public class InputValidationException extends BusinessException {
    public InputValidationException(int code, String msg) { super(code, msg); }
}

public class UnauthorizedException extends BusinessException {
    public UnauthorizedException(int code, String msg) { super(code, msg); }
}

public class ForbiddenException extends BusinessException {
    public ForbiddenException(int code, String msg) { super(code, msg); }
}

public class ConflictException extends BusinessException {
    public ConflictException(int code, String msg) { super(code, msg); }
}

public class ExternalServiceUnavailableException extends BusinessException {
    public ExternalServiceUnavailableException(int code, String msg) { super(code, msg); }
}
```

## ErrorCodes

```java
public final class ErrorCodes {
    // User module (1xxx)
    public static final int USER_NOT_FOUND       = 104004;
    public static final int USER_ALREADY_EXISTS   = 104009;
    public static final int USER_PASSWORD_INVALID = 104010;

    // Order module (2xxx)
    public static final int ORDER_NOT_FOUND       = 204004;
    public static final int ORDER_STATUS_INVALID   = 204009;

    // Payment module (3xxx)
    public static final int PAYMENT_TIMEOUT       = 305008;
    public static final int PAYMENT_SERVICE_DOWN  = 305003;

    public static int httpStatus(int errorCode) { return errorCode % 1000; }
}
```

## ValidationError DTO (Optional)

```java
public record ValidationError(int code, String msg, List<FieldErrorDetail> errors) {
    public static ValidationError fromBindingResult(int code, BindingResult bindingResult) {
        List<FieldErrorDetail> details = bindingResult.getFieldErrors().stream()
            .map(f -> new FieldErrorDetail(f.getField(), f.getDefaultMessage(), f.getRejectedValue()))
            .toList();
        return new ValidationError(code, "Validation failed", details);
    }
}

public record FieldErrorDetail(String field, String message, Object rejectedValue) {}
```

## Service Layer Usage

```java
public UserDO getUser(Long id) {
    return Optional.ofNullable(baseMapper.selectById(id))
        .orElseThrow(() -> new NotFoundException(ErrorCodes.USER_NOT_FOUND, "User not found: " + id));
}
```
