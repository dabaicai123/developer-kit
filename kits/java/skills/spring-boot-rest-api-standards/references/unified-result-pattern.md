# Unified Result Pattern Reference

All Spring Boot REST APIs use `Result<T>`. The outer JSON shape is exactly `code`, `msg`, and `data`.

Spring Boot 3.5 defaults ProblemDetail (`spring.mvc.problemdetails.enabled=true`). COLA projects must disable it:

```yaml
spring:
  mvc:
    problemdetails:
      enabled: false
```

Do not return `ProblemDetail`, `ResponseEntity`, raw entities, or raw `Result`.

## COLA Placement

| Type | Module | Package | Notes |
|------|--------|---------|-------|
| `Result<T>` | common | `common.result` | Pure Java response wrapper |
| `PageResult<T>` | common | `common.result` | No MyBatis-Plus dependency |
| `BusinessException` | common | `common.exception` | Pure Java exception root |
| `GlobalExceptionHandler` | adapter | `web.advice` | Spring Web `@RestControllerAdvice` |

`common` must not depend on Spring Web. Keep the exception hierarchy there, but put the handler in adapter.

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

Rules:

- Use integer codes, not strings like `"SUCCESS"` or `"NOT_FOUND"`.
- Keep the outer fields exactly `code/msg/data`.
- Always declare a concrete payload type.

## Type Parameter Decision Table

| Endpoint shape | Correct return type | Anti-pattern |
|----------------|--------------------|--------------|
| Returns single resource | `Result<UserDTO>` | `Result<Object>` / `Result<Map<String,Object>>` |
| Returns paginated list | `Result<PageResult<UserDTO>>` | `Result<Object>` / raw `Result<PageResult>` |
| Returns flat list | `Result<List<UserDTO>>` | raw `Result<List>` / `Result<Object>` |
| Returns nothing | `Result<Void>` | `Result<Object>` with `null` data |
| Returns ID after create | `Result<Long>` or `Result<UserDTO>` | `Result<Object>` |
| Returns one of several shapes | Split endpoints or use a sealed DTO | `Result<Object>` / `Map<String,Object>` |

Use DTO for REST response contracts. Reserve VO terminology for domain value objects, not API responses.

## PageResult.java

```java
package com.example.common.result;

import lombok.Data;

import java.util.Collections;
import java.util.List;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Unified pagination response.
 *
 * <p>Does not depend on MyBatis-Plus. App/infrastructure code destructures
 * MyBatis-Plus Page records/total/current/size at the call site.
 */
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

    public static <T> PageResult<T> of(List<T> records, long total, long page, long pageSize) {
        return new PageResult<>(records, total, page, pageSize);
    }

    public <U> PageResult<U> map(Function<T, U> converter) {
        List<U> mapped = records.stream().map(converter).collect(Collectors.toList());
        return new PageResult<>(mapped, total, page, pageSize);
    }
}
```

COLA read path example:

```java
Page<CustomerDO> mpPage = customerMapper.selectPage(new Page<>(qry.getPage(), qry.getPageSize()), wrapper);
PageResult<CustomerDTO> result = PageResult
    .of(mpPage.getRecords(), mpPage.getTotal(), mpPage.getCurrent(), mpPage.getSize())
    .map(customerDOConverter::toDTO);
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

    public int getCode() {
        return code;
    }

    public String getMsg() {
        return msg;
    }
}
```

Use business-specific subclasses:

```java
public class NotFoundException extends BusinessException {
    public NotFoundException(String resource, Object id) {
        super(404, resource + " not found: " + id);
    }
}

public class ConflictException extends BusinessException {
    public ConflictException(String msg) {
        super(409, msg);
    }
}
```

Do not use `jakarta.validation.ValidationException` for business validation. Use a project-specific `InputValidationException` or `BizValidationException` to avoid collision with Jakarta validation.

## GlobalExceptionHandler.java

```java
package com.example.web.advice;

import com.example.common.exception.BusinessException;
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

Do not put this class in `common`; it depends on Spring Web and belongs to the adapter module.

## COLA Controller Pattern

```java
package com.example.web;

import com.example.api.UserServiceI;
import com.example.common.result.PageResult;
import com.example.common.result.Result;
import com.example.dto.UserCreateCmd;
import com.example.dto.UserPageQry;
import com.example.dto.data.UserDTO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/v1/users")
@RequiredArgsConstructor
public class UserController {
    private final UserServiceI userService;

    @GetMapping
    public Result<PageResult<UserDTO>> page(@ParameterObject @Valid UserPageQry qry) {
        return userService.page(qry);
    }

    @PostMapping
    public Result<Void> create(@Valid @RequestBody UserCreateCmd cmd) {
        return userService.create(cmd);
    }
}
```

Controller delegates and does not wrap `Result.success()` again because `ServiceI` already returns `Result<T>`.

## JSON Response Examples

Single item:

```json
{"code": 200, "msg": "success", "data": {"id": 1, "name": "Alice"}}
```

Page query:

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "records": [{"id": 1, "name": "Alice"}],
    "total": 100,
    "page": 1,
    "pageSize": 10
  }
}
```

No data:

```json
{"code": 200, "msg": "success", "data": null}
```

Error:

```json
{"code": 404, "msg": "User not found: 123", "data": null}
```
