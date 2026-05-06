# COLA/DDD OpenAPI Patterns

OpenAPI annotation patterns for COLA REST APIs. All `@Tag`, `@Operation`, `@Schema`, `@ApiResponse` descriptions use Chinese.

> Supplement to `ddd-cola` and `spring-boot-rest-api-standards/references/cola-rest-patterns.md`. Covers OpenAPI/Swagger annotations only. For REST patterns, URL design, and pagination, see `cola-rest-patterns.md`.

## Controller Documentation (Adapter Layer)

```java
// adapter/web/CustomerController.java
@RestController
@RequestMapping("/v1/customers")
@Tag(name = "Customer", description = "客户管理接口")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearer-jwt")
public class CustomerController {
    private final CustomerServiceI customerService;

    @Operation(summary = "创建客户", description = "提交新客户，走写路径")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "客户创建成功"),
        @ApiResponse(responseCode = "400", description = "参数校验失败"),
        @ApiResponse(responseCode = "409", description = "客户名冲突")
    })
    @PostMapping
    public Result<Void> addCustomer(@Valid @RequestBody CustomerAddCmd cmd) {
        return customerService.addCustomer(cmd);
    }

    @Operation(summary = "查询客户", description = "按 ID 查询客户详情，走读路径")
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
    public Result<PageResult<CustomerDTO>> listCustomers(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "10") long pageSize,
            @RequestParam(required = false)
            @Parameter(description = "客户类型筛选", example = "IMPORTANT") String customerType) {
        return customerService.listCustomers(page, pageSize, customerType);
    }
}
```

## Model Documentation (Client Module — Cmd/Qry/DTO)

> Cmd, Qry, DTO live in the **client module** (`client/dto/`) per `ddd-cola` SKILL.md.

### Command Object (Write Path)

```java
// client/dto/CustomerAddCmd.java
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

### Query Object (Read Path)

```java
// client/dto/CustomerListByNameQry.java
@Schema(description = "按名称查询客户参数")
@Data
@AllArgsConstructor
public class CustomerListByNameQry extends Query {
    @Schema(description = "客户名称", example = "示例科技", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotBlank(message = "名称不能为空")
    private String name;
}
```

### DTO Object (Response)

```java
// client/dto/data/CustomerDTO.java
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

## NOT: What Never to Annotate

| Object | Package | Reason |
|--------|---------|--------|
| Domain Entity | `domain/customer/` | Internal to domain; must not leak to API |
| Gateway Interface | `domain/customer/gateway/` | Internal port; not exposed to clients |
| DO Object | `infrastructure/customer/` | Persistence-only; not in API contract |
| Gateway Impl | `infrastructure/customer/` | Infrastructure internal |

**NOT** adding `@Schema` to domain entities — the annotation leaks internal domain structure into public API documentation, breaking DDD encapsulation. Annotate only objects in `client/dto/` that cross the adapter boundary.

**NOT** importing domain entities as `@Schema` response types in controllers — use DTO from `client/dto/data/` instead:

```java
// NOT: domain entity as response type
public Result<CustomerEntity> getCustomer(@PathVariable String id) { }

// Correct: DTO as response type
public Result<CustomerDTO> getCustomer(@PathVariable String id) { }
```

## Pagination with PageResult

COLA uses `Result<PageResult<T>>` for paginated responses. Use `@RequestParam` for page/pageSize:

```java
@Operation(summary = "客户列表", description = "分页查询客户")
@GetMapping
public Result<PageResult<CustomerDTO>> listCustomers(
        @RequestParam(defaultValue = "1") long page,
        @RequestParam(defaultValue = "10") long pageSize,
        @RequestParam(required = false)
        @Parameter(description = "客户类型筛选") String customerType) {
    return customerService.listCustomers(page, pageSize, customerType);
}
```

`PageResult<T>` wraps MyBatis-Plus `Page<T>` — see `spring-boot-rest-api-standards`.

For SpringDoc-native pagination (non-COLA projects), use `@ParameterObject Pageable`:

```java
public Result<PageResult<OrderDTO>> listOrders(@ParameterObject Pageable pageable) { }
```

## Error Response Documentation

COLA uses `Result<Void>` with error codes for all errors:

```java
@Operation(summary = "创建客户")
@ApiResponse(responseCode = "200", description = "成功")
@ApiResponse(responseCode = "400", description = "参数校验失败",
    content = @Content(schema = @Schema(implementation = Result.class)))
@ApiResponse(responseCode = "409", description = "客户名冲突",
    content = @Content(schema = @Schema(implementation = Result.class)))
@PostMapping
public Result<Void> addCustomer(@Valid @RequestBody CustomerAddCmd cmd) { ... }
```

Global exception handler returns `Result<Void>` — see `spring-boot-exception-handling`. Mark handler methods with `@Operation(hidden = true)` to exclude them from docs.

## Hidden Fields and Access Modes

```java
// Hide internal fields from API documentation
@Schema(hidden = true)
private String internalField;

// Read-only: server-generated, not in request
@Schema(description = "创建时间", example = "2024-01-15T10:30:00", accessMode = Schema.AccessMode.READ_ONLY)
private LocalDateTime createdAt;

// Write-only: sent in request, not in response
@Schema(description = "密码", accessMode = Schema.AccessMode.WRITE_ONLY)
private String password;
```

**NOT** using `@Schema(example=...)` for passwords, tokens, or PII — sensitive data must not appear in Swagger UI examples. Use `accessMode = WRITE_ONLY` for passwords and `hidden = true` for internal fields.