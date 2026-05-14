# COLA/DDD OpenAPI Patterns

OpenAPI annotation patterns for COLA REST APIs. Chinese-user-facing APIs should use Chinese in `@Tag`, `@Operation`, `@Schema`, and `@ApiResponse` descriptions.

This file covers OpenAPI annotations only. For REST patterns, URL design, and pagination, see `spring-boot-rest-api-standards/references/cola-rest-patterns.md`.

## Controller Documentation (Adapter Layer)

```java
// service-adapter: web/CustomerController.java
@RestController
@RequestMapping("/v1/customers")
@Tag(name = "Customer", description = "客户管理接口")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearer-jwt")
public class CustomerController {
    private final CustomerServiceI customerService;

    @Operation(summary = "创建客户", description = "提交客户信息并创建客户")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "客户创建成功"),
        @ApiResponse(responseCode = "400", description = "参数校验失败"),
        @ApiResponse(responseCode = "409", description = "客户名称冲突")
    })
    @PostMapping
    public Result<Void> addCustomer(@Valid @RequestBody CustomerAddCmd cmd) {
        return customerService.addCustomer(cmd);
    }

    @Operation(summary = "查询客户", description = "按客户编号查询客户详情")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @ApiResponse(responseCode = "404", description = "客户不存在")
    @GetMapping("/{customerId}")
    public Result<CustomerDTO> getCustomer(
            @Parameter(description = "客户编号", example = "CUST-001")
            @PathVariable String customerId) {
        return customerService.getCustomer(customerId);
    }

    @Operation(summary = "客户列表", description = "分页查询客户")
    @GetMapping
    public Result<PageResult<CustomerDTO>> listCustomers(@ParameterObject @Valid CustomerPageQry qry) {
        return customerService.listCustomers(qry);
    }
}
```

## Model Documentation (Client Module)

Cmd, Qry, and DTO live in the client module per `ddd-cola`.

### Command Object

```java
// service-client: dto/CustomerAddCmd.java
@Schema(description = "创建客户命令")
@Data
public class CustomerAddCmd extends Command {
    @Schema(description = "公司名称", example = "示例科技", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotBlank(message = "公司名称不能为空")
    private String companyName;

    @Schema(description = "客户类型", example = "IMPORTANT",
        allowableValues = {"POTENTIAL", "INTENTIONAL", "IMPORTANT", "VIP"})
    private String customerType;
}
```

### Query Object

```java
// service-client: dto/CustomerPageQry.java
@Schema(description = "客户分页查询参数")
@Data
public class CustomerPageQry extends Query {
    @Schema(description = "页码", example = "1", requiredMode = Schema.RequiredMode.REQUIRED)
    @Min(value = 1, message = "页码必须大于 0")
    private long page = 1;

    @Schema(description = "每页条数", example = "10", requiredMode = Schema.RequiredMode.REQUIRED)
    @Min(value = 1, message = "每页条数必须大于 0")
    private long pageSize = 10;

    @Schema(description = "客户类型筛选", example = "IMPORTANT")
    private String customerType;
}
```

### DTO Object

```java
// service-client: dto/data/CustomerDTO.java
@Schema(description = "客户数据传输对象")
@Data
public class CustomerDTO {
    @Schema(description = "客户编号", example = "CUST-001", accessMode = Schema.AccessMode.READ_ONLY)
    private String customerId;

    @Schema(description = "公司名称", example = "示例科技")
    private String companyName;

    @Schema(description = "客户类型", example = "IMPORTANT",
        allowableValues = {"POTENTIAL", "INTENTIONAL", "IMPORTANT", "VIP"})
    private String customerType;
}
```

### Enum Documentation

```java
public enum CustomerType {
    @Schema(description = "潜在客户")
    POTENTIAL,

    @Schema(description = "意向客户")
    INTENTIONAL,

    @Schema(description = "重要客户")
    IMPORTANT,

    @Schema(description = "VIP 客户")
    VIP
}
```

## What Never to Annotate

| Object | Package | Reason |
|--------|---------|--------|
| Domain Entity | `domain/customer/` | Internal to domain; must not leak to API |
| Domain VO | `domain/customer/vo/` | Behavior-carrying internal type |
| Gateway Interface | `domain/customer/gateway/` | Internal port; not exposed to clients |
| DO Object | `infrastructure/customer/gatewayimpl/database/dataobject/` | Persistence-only; not in API contract |
| Gateway Impl | `infrastructure/customer/` | Infrastructure internal |

Annotate only client-module objects that cross the adapter boundary. Do not import domain entities as response types in controllers.

```java
// NOT
public Result<Customer> getCustomer(@PathVariable String id) { }

// Correct
public Result<CustomerDTO> getCustomer(@PathVariable String id) { }
```

## Pagination with PageResult

```java
@Operation(summary = "客户列表", description = "分页查询客户")
@GetMapping
public Result<PageResult<CustomerDTO>> listCustomers(@ParameterObject @Valid CustomerPageQry qry) {
    return customerService.listCustomers(qry);
}
```

For SpringDoc-native pagination in non-COLA projects, use `@ParameterObject Pageable`.

## Error Response Documentation

COLA uses `Result<Void>` with integer error codes for errors:

```java
@Operation(summary = "创建客户")
@ApiResponse(responseCode = "200", description = "成功")
@ApiResponse(responseCode = "400", description = "参数校验失败",
    content = @Content(schema = @Schema(implementation = Result.class)))
@ApiResponse(responseCode = "409", description = "客户名称冲突",
    content = @Content(schema = @Schema(implementation = Result.class)))
@PostMapping
public Result<Void> addCustomer(@Valid @RequestBody CustomerAddCmd cmd) {
    return customerService.addCustomer(cmd);
}
```

Global exception handler returns `Result<Void>`; see `spring-boot-exception-handling`. Mark handler methods with `@Operation(hidden = true)` if they appear in generated docs.

## Hidden Fields and Access Modes

```java
@Schema(hidden = true)
private String internalField;

@Schema(description = "创建时间", example = "2026-05-14T10:30:00", accessMode = Schema.AccessMode.READ_ONLY)
private LocalDateTime createdAt;

@Schema(description = "密码", accessMode = Schema.AccessMode.WRITE_ONLY)
private String password;
```

Do not use sensitive values in `@Schema(example=...)`.
