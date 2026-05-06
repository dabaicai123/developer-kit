# COLA/DDD REST Patterns

Patterns for REST APIs in COLA architecture. Swagger/OpenAPI descriptions in Chinese; all other content in English.

Supplement to `ddd-cola` SKILL.md — REST-specific patterns. For module structure, CQRS, and Gateway patterns, refer to `ddd-cola`.

## Controller (Adapter Layer)

Controllers in `web/` are thin inbound handlers. They delegate to `CustomerServiceI` (app layer). No business logic in controllers.

```java
// adapter/web/CustomerController.java
@RestController
@RequestMapping("/v1/customers")
@RequiredArgsConstructor
@Tag(name = "Customer", description = "客户管理接口")
public class CustomerController {
    private final CustomerServiceI customerService;

    @PostMapping
    public Result<Void> addCustomer(@Valid @RequestBody CustomerAddCmd cmd) {
        return customerService.addCustomer(cmd);
    }

    @GetMapping("/{customerId}")
    public Result<CustomerDTO> getCustomer(@PathVariable String customerId) {
        return customerService.getCustomer(customerId);
    }

    // @ParameterObject (Spring Boot 3.5+) for query param binding to Qry object
    @GetMapping
    public Result<PageResult<CustomerDTO>> listCustomers(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "10") long pageSize,
            @RequestParam(required = false) String customerType) {
        return customerService.listCustomers(page, pageSize, customerType);
    }

    @PutMapping("/{customerId}")
    public Result<Void> updateCustomer(@PathVariable String customerId,
            @Valid @RequestBody CustomerUpdateCmd cmd) {
        return customerService.updateCustomer(customerId, cmd);
    }

    @DeleteMapping("/{customerId}")
    public Result<Void> deleteCustomer(@PathVariable String customerId) {
        return customerService.deleteCustomer(customerId);
    }
}
```

NOT Controller wrapping `Result.success()` again → Service already returns `Result<T>`.
NOT business logic in Controller → delegate to Service.

## Cmd/Qry/DTO (Client Layer)

Canonical location: Cmd, Qry, and DTO live in **client** module (`client/dto/`).

### Command (Write Path — Request Body)

```java
// client/dto/CustomerAddCmd.java
@Data
public class CustomerAddCmd extends Command {
    @NotBlank(message = "Company name must not be blank")
    private String companyName;

    private String customerType;
}
```

### Query (Read Path — Parameters)

```java
// client/dto/CustomerListByNameQry.java
@Data
@AllArgsConstructor
public class CustomerListByNameQry extends Query {
    @NotBlank(message = "Name must not be blank")
    private String name;
}
```

### DTO (Response Body)

```java
// client/dto/data/CustomerDTO.java
@Data
public class CustomerDTO {
    private String customerId;
    private String companyName;
    private String customerType;
}
```

NOT domain entity `Customer` at boundary → use `CustomerDTO`.
NOT `CustomerDO` at boundary → convert via MapStruct.

## Pagination Pattern

Return `Result<PageResult<T>>` for paginated endpoints. Convert MyBatis-Plus `Page<DO>` → `PageResult<DTO>` in QryExe:

```java
// app/customer/executor/query/CustomerListByNameQryExe.java
@Component
@RequiredArgsConstructor
public class CustomerListByNameQryExe {
    private final CustomerMapper customerMapper;
    private final CustomerDOConverter customerDOConverter;

    public Result<PageResult<CustomerDTO>> execute(long page, long pageSize, String customerType) {
        Page<CustomerDO> mpPage = new Page<>(page, pageSize);
        LambdaQueryWrapper<CustomerDO> wrapper = new LambdaQueryWrapper<>();
        if (customerType != null) {
            wrapper.eq(CustomerDO::getCustomerType, customerType);
        }
        wrapper.orderByDesc(CustomerDO::getCreatedAt);
        customerMapper.selectPage(mpPage, wrapper);
        return Result.success(PageResult.of(mpPage).map(customerDOConverter::toDTO));
    }
}
```

## Filtering Pattern

Use `LambdaQueryWrapper` for dynamic filtering in read executors:

```java
public Result<PageResult<CustomerDTO>> execute(CustomerListByNameQry qry, long page, long pageSize) {
    LambdaQueryWrapper<CustomerDO> wrapper = new LambdaQueryWrapper<>();
    wrapper.eq(qry.getName() != null, CustomerDO::getCompanyName, qry.getName());
    wrapper.orderByDesc(CustomerDO::getCreatedAt);
    Page<CustomerDO> mpPage = customerMapper.selectPage(new Page<>(page, pageSize), wrapper);
    return Result.success(PageResult.of(mpPage).map(customerDOConverter::toDTO));
}
```

NOT raw `QueryWrapper` → always use `LambdaQueryWrapper`. → see `mybatis-plus-patterns`

## @ParameterObject (Spring Boot 3.5+)

Spring Framework 6.2 introduces `@ParameterObject` for binding query params to a Qry object without manual `@RequestParam` extraction:

```java
@GetMapping
public Result<PageResult<CustomerDTO>> listCustomers(@ParameterObject CustomerListQry qry) {
    return customerService.listCustomers(qry);
}
```

NOT manual `@RequestParam` for each query field → use `@ParameterObject` + Qry object.

## URL Design

| Pattern | Example | Notes |
|---------|---------|-------|
| Resource list | `GET /v1/customers` | Paginated, `Result<PageResult<CustomerDTO>>` |
| Single resource | `GET /v1/customers/{id}` | `Result<CustomerDTO>` |
| Create | `POST /v1/customers` | Body: `CustomerAddCmd`, `Result<Void>` |
| Update | `PUT /v1/customers/{id}` | Body: `CustomerUpdateCmd`, `Result<Void>` |
| Delete | `DELETE /v1/customers/{id}` | `Result<Void>` |
| Sub-resource | `GET /v1/customers/{id}/credits` | Nested under aggregate root |

### Anti-patterns

| NOT | Why | Correct |
|-----|-----|---------|
| `/getCustomerList` | Action-based URL | `GET /v1/customers` |
| `/customer/create` | Noun + verb | `POST /v1/customers` |
| `/api/v1/...` | Mixed prefix | `/v1/customers` (version in path, no `/api`) |
| `Customer` entity at boundary | Leaks domain internals | `CustomerDTO` |
| `CustomerDO` at boundary | Leaks persistence internals | Convert via MapStruct |
| `ResponseEntity<T>` | Breaks unified format | `Result<T>` |

## HTTP Status Codes in Result<T>

| code | Usage |
|------|-------|
| 200 | All successful operations |
| 400 | Validation errors |
| 401 | Missing or invalid auth |
| 403 | No permission |
| 404 | Resource not found |
| 409 | Duplicate, state conflict |
| 500 | Unexpected server errors |

NOT String codes → always integer HTTP status codes.