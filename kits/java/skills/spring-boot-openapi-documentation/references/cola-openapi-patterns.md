# COLA/DDD OpenAPI Patterns

Patterns for documenting REST APIs in COLA architecture. All `@Tag`, `@Operation`, `@Schema`, `@ApiResponse` descriptions use Chinese.

## Controller Documentation (Adapter Layer)

```java
// adapter/controller/OrderController.java
@RestController
@RequestMapping("/v1/orders")
@Tag(name = "Order", description = "订单管理接口")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearer-jwt")
public class OrderController {
    private final OrderServiceI orderService;

    @Operation(summary = "创建订单", description = "提交新订单，走写路径")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "订单创建成功"),
        @ApiResponse(responseCode = "400", description = "参数校验失败"),
        @ApiResponse(responseCode = "409", description = "订单冲突")
    })
    @PostMapping
    public Result<Void> createOrder(@Valid @RequestBody CreateOrderCmd cmd) {
        return orderService.createOrder(cmd);
    }

    @Operation(summary = "查询订单", description = "按 ID 查询订单详情，走读路径")
    @ApiResponse(responseCode = "200", description = "查询成功")
    @ApiResponse(responseCode = "404", description = "订单不存在")
    @GetMapping("/{id}")
    public Result<OrderDTO> getOrder(
            @Parameter(description = "订单编号", example = "ORD-001")
            @PathVariable String id) {
        return orderService.getOrder(id);
    }

    @Operation(summary = "订单列表", description = "分页查询订单")
    @GetMapping
    public Result<PageResult<OrderDTO>> listOrders(
            @ParameterObject Pageable pageable,
            @RequestParam(required = false)
            @Parameter(description = "订单状态筛选", example = "PENDING") String status) {
        return orderService.listOrders(pageable, status);
    }
}
```

## Model Documentation (App Layer — Cmd/Qry/VO/DTO)

### Command Object (Write Path)

```java
// app/ — CreateOrderCmd
@Schema(description = "创建订单命令")
@Data
public class CreateOrderCmd {
    @Schema(description = "客户 ID", example = "cust-001", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotBlank(message = "客户 ID 不能为空")
    private String customerId;

    @Schema(description = "订单商品列表", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotNull
    @Size(min = 1, message = "至少需要一件商品")
    private List<OrderItemVO> items;
}
```

### Query Object (Read Path)

```java
// app/ — OrderQry
@Schema(description = "订单查询参数")
@Data
public class OrderQry {
    @Schema(description = "订单状态筛选", example = "PENDING")
    private String status;

    @Schema(description = "客户 ID 筛选", example = "cust-001")
    private String customerId;
}
```

### View/DTO Object (Response)

```java
// app/ — OrderDTO
@Schema(description = "订单数据传输对象")
@Data
public class OrderDTO {
    @Schema(description = "订单编号", example = "ORD-001", accessMode = Schema.AccessMode.READ_ONLY)
    private String orderId;

    @Schema(description = "客户 ID", example = "cust-001")
    private String customerId;

    @Schema(description = "订单状态", example = "PENDING",
        allowableValues = {"PENDING", "CONFIRMED", "SHIPPED", "DELIVERED", "CANCELLED"})
    private String status;

    @Schema(description = "订单总金额", example = "299.99")
    private BigDecimal totalAmount;

    @Schema(description = "创建时间", example = "2024-01-15T10:30:00", accessMode = Schema.AccessMode.READ_ONLY)
    private LocalDateTime createdAt;
}
```

### Enum Documentation

```java
public enum OrderStatus {
    @Schema(description = "待处理")
    PENDING,
    @Schema(description = "已确认")
    CONFIRMED,
    @Schema(description = "已发货")
    SHIPPED,
    @Schema(description = "已送达")
    DELIVERED,
    @Schema(description = "已取消")
    CANCELLED
}
```

## What NOT to Annotate

| Object | Package | Annotate? | Reason |
|--------|---------|-----------|--------|
| Domain Entity | `domain/model/entity/` | **Never** | Internal to domain; must not leak to API |
| Gateway Interface | `domain/gateway/` | **Never** | Internal port; not exposed to clients |
| DO Object | `infrastructure/mapper/` | **Never** | Persistence-only; not in API contract |
| Gateway Impl | `infrastructure/gatewayimpl/` | **Never** | Infrastructure internal |
| Cmd/Qry | `app/` | **Yes** | Crosses adapter boundary (request body) |
| VO/DTO | `app/` | **Yes** | Crosses adapter boundary (response body) |
| Controller | `adapter/controller/` | **Yes** | Entry point for API documentation |

## Pagination with PageResult

COLA uses `Result<PageResult<T>>` for paginated responses. Document with `@ParameterObject`:

```java
@Operation(summary = "订单列表", description = "分页查询订单")
@GetMapping
public Result<PageResult<OrderDTO>> listOrders(@ParameterObject Pageable pageable) {
    return orderService.listOrders(pageable);
}
```

SpringDoc auto-generates `page`, `size`, `sort` parameters from `Pageable`. `PageResult<T>` wraps MyBatis-Plus `Page<T>` → see `spring-boot-rest-api-standards`.

## Error Response Documentation

COLA uses `Result<Void>` with error codes for all errors. Document error responses:

```java
@Operation(summary = "创建订单")
@ApiResponse(responseCode = "200", description = "成功")
@ApiResponse(responseCode = "400", description = "参数校验失败",
    content = @Content(schema = @Schema(implementation = Result.class)))
@ApiResponse(responseCode = "409", description = "订单冲突",
    content = @Content(schema = @Schema(implementation = Result.class)))
@PostMapping
public Result<Void> createOrder(@Valid @RequestBody CreateOrderCmd cmd) { ... }
```

Global exception handler returns `Result<Void>` → see `spring-boot-exception-handling`. Mark handler methods with `@Operation(hidden = true)` to exclude them from docs.

## Hidden Fields and Access Modes

```java
// Hide internal fields from API documentation
@Schema(hidden = true)
private String internalField;

// Read-only fields (server-generated, not in request)
@Schema(description = "创建时间", accessMode = Schema.AccessMode.READ_ONLY)
private LocalDateTime createdAt;

// Write-only fields (sent in request, not in response)
@Schema(description = "密码", accessMode = Schema.AccessMode.WRITE_ONLY)
private String password;
```

## Nested Objects

```java
@Schema(description = "订单商品")
@Data
public class OrderItemVO {
    @Schema(description = "商品名称", example = "Clean Code")
    private String productName;

    @Schema(description = "数量", example = "2")
    @Min(1)
    private Integer quantity;

    @Schema(description = "单价", example = "29.99")
    @DecimalMin("0.0")
    private BigDecimal unitPrice;
}
```