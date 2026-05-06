# Unified Result Pattern Reference

All Spring Boot REST APIs use `Result<T>` wrapper. Outer structure: exactly `code`, `msg`, `data`.

Spring Boot 3.5 defaults ProblemDetail (`spring.mvc.problemdetails.enabled=true`). COLA projects must disable it:
```yaml
spring:
  mvc:
    problemdetails:
      enabled: false
```

NOT `ProblemDetail`, `ResponseEntity`, or `ErrorResponse` → use `Result<T>`.

## Result.java

```java
package com.example.common.result;

import lombok.Data;

@Data
public class Result<T> {
    private int code;
    private String msg;
    private T data;

    private Result(int code, String msg, T data) {
        this.code = code;
        this.msg = msg;
        this.data = data;
    }

    public static Result<Void> success() {
        return new Result<>(200, "success", null);
    }

    public static <T> Result<T> success(T data) {
        return new Result<>(200, "success", data);
    }

    public static Result<Void> fail(int code, String msg) {
        return new Result<>(code, msg, null);
    }

    public static <T> Result<T> fail(int code, String msg, T data) {
        return new Result<>(code, msg, data);
    }
}
```

NOT String codes like "SUCCESS" or "NOT_FOUND" → always integer HTTP status codes.
NOT extra fields in outer structure → exactly `code/msg/data`.

## PageResult.java (MyBatis-Plus conversion)

```java
package com.example.common.result;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.Data;
import java.util.List;
import java.util.Collections;
import java.util.function.Function;
import java.util.stream.Collectors;

@Data
public class PageResult<T> {
    private List<T> records;
    private long total;
    private long page;
    private long pageSize;

    public PageResult(List<T> records, long total, long page, long pageSize) {
        this.records = records != null ? records : Collections.emptyList();
        this.total = total;
        this.page = page;
        this.pageSize = pageSize;
    }

    public static <T> PageResult<T> of(Page<T> mpPage) {
        return new PageResult<>(mpPage.getRecords(), mpPage.getTotal(), mpPage.getCurrent(), mpPage.getSize());
    }

    public <U> PageResult<U> map(Function<T, U> converter) {
        List<U> voList = records.stream().map(converter).collect(Collectors.toList());
        return new PageResult<>(voList, total, page, pageSize);
    }
}
```

## BusinessException.java

```java
package com.example.common.exception;

public class BusinessException extends RuntimeException {
    private final int code;
    private final String msg;

    public BusinessException(int code, String msg) {
        super(msg);
        this.code = code;
        this.msg = msg;
    }

    public int getCode() { return code; }
    public String getMsg() { return msg; }
}

// NOT jakarta.validation.ValidationException → use BizValidationException to avoid collision
public class BizValidationException extends BusinessException {
    public BizValidationException(String msg) { super(400, msg); }
}

public class NotFoundException extends BusinessException {
    public NotFoundException(String resource, Object id) {
        super(404, resource + " not found: " + id);
    }
}

public class UnauthorizedException extends BusinessException {
    public UnauthorizedException(String msg) { super(401, msg); }
}

public class ForbiddenException extends BusinessException {
    public ForbiddenException(String msg) { super(403, msg); }
}

public class ConflictException extends BusinessException {
    public ConflictException(String msg) { super(409, msg); }
}
```

NOT `jakarta.validation.ValidationException` for business validation → use `BizValidationException`.

## GlobalExceptionHandler.java

```java
package com.example.common.exception;

import com.example.common.result.Result;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import java.util.stream.Collectors;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusiness(BusinessException e) {
        log.warn("Business error: {} - {}", e.getCode(), e.getMsg());
        return Result.fail(e.getCode(), e.getMsg());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidation(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
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

NOT letting raw exceptions bubble up → `@RestControllerAdvice` catches all.
NOT `@ExceptionHandler` returning `ResponseEntity` → return `Result<Void>`.

## JSON Response Examples

### Single item
```json
{"code": 200, "msg": "success", "data": {"id": 1, "name": "John", "email": "john@example.com"}}
```

### Page query
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "records": [{"id": 1, "name": "John"}, {"id": 2, "name": "Jane"}],
    "total": 100,
    "page": 1,
    "pageSize": 10
  }
}
```

### List (no pagination)
```json
{"code": 200, "msg": "success", "data": [{"id": 1, "name": "John"}, {"id": 2, "name": "Jane"}]}
```

### Create/Update/Delete (no data)
```json
{"code": 200, "msg": "success", "data": null}
```

### Error
```json
{"code": 404, "msg": "User not found: 123", "data": null}
```

### Validation error
```json
{"code": 400, "msg": "name: cannot be blank; email: invalid format", "data": null}
```

## Controller Pattern

```java
@RestController
@RequestMapping("/v1/users")
@RequiredArgsConstructor
public class UserController {
    private final UserServiceI userServiceI;

    @GetMapping("/{id}")
    public Result<UserVO> getById(@PathVariable Long id) {
        return Result.success(userServiceI.getById(id));
    }

    @GetMapping
    public Result<PageResult<UserVO>> page(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "10") long pageSize) {
        return Result.success(userServiceI.page(page, pageSize));
    }

    @GetMapping("/list")
    public Result<List<UserVO>> list() {
        return Result.success(userServiceI.list());
    }

    @PostMapping
    public Result<Void> create(@Valid @RequestBody UserCreateDTO dto) {
        userServiceI.create(dto);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @Valid @RequestBody UserUpdateDTO dto) {
        userServiceI.update(id, dto);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@PathVariable Long id) {
        userServiceI.removeById(id);
        return Result.success();
    }
}
```

NOT Controller wrapping `Result.success()` again → Service already returns `Result<T>`.

## Service Pattern (MyBatis-Plus)

```java
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserServiceI {

    @Override
    public UserVO getById(Long id) {
        UserDO entity = baseMapper.selectById(id);
        if (entity == null) {
            throw new NotFoundException("User", id);
        }
        return UserConverter.toVO(entity);
    }

    @Override
    public PageResult<UserVO> page(long page, long pageSize) {
        Page<UserDO> mpPage = baseMapper.selectPage(
            new Page<>(page, pageSize),
            lambdaQuery().orderByDesc(UserDO::getCreatedAt)
        );
        return PageResult.of(mpPage).map(UserConverter::toVO);
    }
}
```

## Error Code Convention

| code | Usage |
|------|-------|
| 200 | All successful operations |
| 400 | Validation errors, invalid input |
| 401 | Missing or invalid auth |
| 403 | No permission |
| 404 | Resource not found |
| 409 | Duplicate, state conflict |
| 500 | Unexpected server errors |

NOT String codes → always integer HTTP status codes. NOT extra outer fields → exactly `code/msg/data`.