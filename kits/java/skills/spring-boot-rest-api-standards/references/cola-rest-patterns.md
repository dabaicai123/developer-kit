# COLA/DDD REST Patterns

Patterns for REST APIs in COLA architecture. Swagger/OpenAPI descriptions may use Chinese in code examples; architectural guidance stays in English.

This is a REST-specific supplement to `ddd-cola`. For module structure, CQRS paths, and Gateway patterns, refer to `ddd-cola`.

## Controller (Adapter Layer)

Controllers in the adapter module `web/` package are thin inbound handlers. They delegate to `CustomerServiceI` from the client module; the app module provides `CustomerServiceImpl`. No business logic belongs in controllers.

```java
// service-adapter: web/CustomerController.java
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

    @GetMapping
    public Result<PageResult<CustomerDTO>> listCustomers(@ParameterObject @Valid CustomerPageQry qry) {
        return customerService.listCustomers(qry);
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

Do not wrap `Result.success()` again in the controller; `ServiceI` already returns `Result<T>`.

## Cmd/Qry/DTO (Client Layer)

Canonical location: Cmd, Qry, and DTO live in the client module.

```java
// service-client: dto/CustomerAddCmd.java
@Data
public class CustomerAddCmd extends Command {
    @NotBlank(message = "Company name must not be blank")
    private String companyName;

    private String customerType;
}
```

```java
// service-client: dto/CustomerPageQry.java
@Data
public class CustomerPageQry extends Query {
    @Min(value = 1, message = "Page must be greater than zero")
    private long page = 1;

    @Min(value = 1, message = "Page size must be greater than zero")
    private long pageSize = 10;

    private String customerType;
}
```

```java
// service-client: dto/data/CustomerDTO.java
@Data
public class CustomerDTO {
    private String customerId;
    private String companyName;
    private String customerType;
}
```

Do not expose domain entity `Customer` or persistence object `CustomerDO` at the adapter boundary. Use `CustomerDTO`.

## Pagination Pattern

Return `Result<PageResult<T>>` for paginated endpoints. Convert MyBatis-Plus `Page<DO>` to `PageResult<DTO>` in QryExe:

```java
// service-app: customer/executor/query/CustomerPageQryExe.java
@Component
@RequiredArgsConstructor
public class CustomerPageQryExe {
    private final CustomerMapper customerMapper;
    private final CustomerDOConverter customerDOConverter;

    public Result<PageResult<CustomerDTO>> execute(CustomerPageQry qry) {
        LambdaQueryWrapper<CustomerDO> wrapper = Wrappers.lambdaQuery();
        wrapper.eq(StringUtils.hasText(qry.getCustomerType()), CustomerDO::getCustomerType, qry.getCustomerType());
        wrapper.orderByDesc(CustomerDO::getCreatedAt);

        Page<CustomerDO> mpPage = customerMapper.selectPage(new Page<>(qry.getPage(), qry.getPageSize()), wrapper);
        PageResult<CustomerDTO> pageResult = PageResult
            .of(mpPage.getRecords(), mpPage.getTotal(), mpPage.getCurrent(), mpPage.getSize())
            .map(customerDOConverter::toDTO);
        return Result.success(pageResult);
    }
}
```

Use `LambdaQueryWrapper` or `Wrappers.lambdaQuery()`. Do not use raw `QueryWrapper`.

## @ParameterObject

Use `@ParameterObject` for binding query params to a Qry object:

```java
@GetMapping
public Result<PageResult<CustomerDTO>> listCustomers(@ParameterObject @Valid CustomerPageQry qry) {
    return customerService.listCustomers(qry);
}
```

Do not manually duplicate every query field as `@RequestParam` when a Qry object already exists.

## URL Design

| Pattern | Example | Notes |
|---------|---------|-------|
| Resource list | `GET /v1/customers` | Paginated, `Result<PageResult<CustomerDTO>>` |
| Single resource | `GET /v1/customers/{id}` | `Result<CustomerDTO>` |
| Create | `POST /v1/customers` | Body: `CustomerAddCmd`, `Result<Void>` |
| Update | `PUT /v1/customers/{id}` | Body: `CustomerUpdateCmd`, `Result<Void>` |
| Delete | `DELETE /v1/customers/{id}` | `Result<Void>` |
| Sub-resource | `GET /v1/customers/{id}/credits` | Nested under aggregate root |

## Anti-Patterns

| NOT | Why | Correct |
|-----|-----|---------|
| `/getCustomerList` | Action-based URL | `GET /v1/customers` |
| `/customer/create` | Noun + verb | `POST /v1/customers` |
| `/api/v1/...` | Mixed prefix | `/v1/customers` |
| `Customer` entity at boundary | Leaks domain internals | `CustomerDTO` |
| `CustomerDO` at boundary | Leaks persistence internals | Convert through `CustomerDOConverter` |
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

Use integer codes, not string codes.
