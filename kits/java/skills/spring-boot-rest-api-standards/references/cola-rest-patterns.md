# COLA/DDD REST Patterns

Patterns for REST APIs in COLA architecture. All user-facing descriptions and validation messages use Chinese.

## Controller (Adapter Layer)

Controllers in `adapter/controller/` are thin inbound handlers. They delegate to `app/service/` (thin facade) which routes to `app/executor/` (actual handler). No business logic in controllers.

```java
// adapter/controller/OrderController.java
@RestController
@RequestMapping("/v1/orders")
@RequiredArgsConstructor
@Slf4j
public class OrderController {
    private final OrderServiceI orderService;

    // 写路径 — Cmd 作为 request body
    @PostMapping
    public Result<Void> createOrder(@Valid @RequestBody CreateOrderCmd cmd) {
        orderService.createOrder(cmd);
        return Result.success();
    }

    // 读路径 — 单条查询
    @GetMapping("/{id}")
    public Result<OrderDTO> getOrder(@PathVariable String id) {
        return Result.success(orderService.getOrder(id));
    }

    // 读路径 — 分页查询
    @GetMapping
    public Result<PageResult<OrderDTO>> listOrders(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "10") long pageSize,
            @RequestParam(required = false) String status) {
        return Result.success(orderService.listOrders(page, pageSize, status));
    }

    // 更新
    @PutMapping("/{id}")
    public Result<Void> updateOrder(@PathVariable String id,
            @Valid @RequestBody UpdateOrderCmd cmd) {
        orderService.updateOrder(id, cmd);
        return Result.success();
    }

    // 删除
    @DeleteMapping("/{id}")
    public Result<Void> deleteOrder(@PathVariable String id) {
        orderService.deleteOrder(id);
        return Result.success();
    }
}
```

## Cmd/Qry/VO/DTO (App Layer)

### Command (Write Path — Request Body)

```java
// app/ — CreateOrderCmd
@Data
public class CreateOrderCmd {
    @NotBlank(message = "客户 ID 不能为空")
    private String customerId;

    @NotNull(message = "订单商品不能为空")
    @Size(min = 1, message = "至少需要一件商品")
    private List<OrderItemVO> items;
}
```

### Query (Read Path — Parameters)

```java
// app/ — OrderQry
@Data
public class OrderQry {
    private String status;     // 状态筛选
    private String customerId; // 客户筛选
}
```

### DTO (Response Body)

```java
// app/ — OrderDTO
@Data
public class OrderDTO {
    private String orderId;
    private String customerId;
    private String status;
    private BigDecimal totalAmount;
    private LocalDateTime createdAt;
}
```

### What NOT to Expose

| Type | Package | Expose? | Reason |
|------|---------|---------|--------|
| Domain Entity | `domain/model/entity/` | **Never** | Internal, no ORM annotations |
| DO Object | `infrastructure/mapper/` | **Never** | Persistence-only, MyBatis-Plus annotations |
| Gateway Interface | `domain/gateway/` | **Never** | Internal port |
| Cmd | `app/` | **Yes** | Request body |
| Qry | `app/` | **Yes** | Query parameters |
| VO/DTO | `app/` | **Yes** | Response body |

## Pagination Pattern

Return `Result<PageResult<T>>` for paginated endpoints. Convert MyBatis-Plus `Page<DO>` → `PageResult<VO>` in the service layer:

```java
// app/service/ — delegates to executor
@Service
@RequiredArgsConstructor
public class OrderServiceImpl implements OrderServiceI {
    private final OrderQryExe orderQryExe;

    @Override
    public PageResult<OrderDTO> listOrders(long page, long pageSize, String status) {
        return orderQryExe.execute(page, pageSize, status);
    }
}

// app/executor/ — read path, bypasses Domain
@Component
@RequiredArgsConstructor
public class OrderQryExe {
    private final OrderMapper orderMapper;

    public PageResult<OrderDTO> execute(long page, long pageSize, String status) {
        Page<OrderDO> mpPage = new Page<>(page, pageSize);
        LambdaQueryWrapper<OrderDO> wrapper = new LambdaQueryWrapper<>();
        if (status != null) {
            wrapper.eq(OrderDO::getStatus, status);
        }
        wrapper.orderByDesc(OrderDO::getCreatedAt);
        orderMapper.selectPage(mpPage, wrapper);
        return PageResult.of(mpPage).map(OrderConverter::toDTO);
    }
}
```

## Filtering Pattern

Use `LambdaQueryWrapper` for dynamic filtering in read executors. Build conditions from Qry parameters:

```java
// app/executor/ — dynamic filtering from Qry object
public PageResult<OrderDTO> execute(OrderQry qry, long page, long pageSize) {
    LambdaQueryWrapper<OrderDO> wrapper = new LambdaQueryWrapper<>();
    wrapper.eq(qry.getStatus() != null, OrderDO::getStatus, qry.getStatus());
    wrapper.eq(qry.getCustomerId() != null, OrderDO::getCustomerId, qry.getCustomerId());
    wrapper.orderByDesc(OrderDO::getCreatedAt);
    Page<OrderDO> mpPage = orderMapper.selectPage(new Page<>(page, pageSize), wrapper);
    return PageResult.of(mpPage).map(OrderConverter::toDTO);
}
```

Never use raw `QueryWrapper` — always use `LambdaQueryWrapper`. → see `mybatis-plus-patterns`

## URL Design

| Pattern | Example | Notes |
|---------|---------|-------|
| Resource list | `GET /v1/orders` | Paginated, returns `Result<PageResult<OrderDTO>>` |
| Single resource | `GET /v1/orders/{id}` | Returns `Result<OrderDTO>` |
| Create | `POST /v1/orders` | Body: `CreateOrderCmd`, returns `Result<Void>` |
| Update | `PUT /v1/orders/{id}` | Body: `UpdateOrderCmd`, returns `Result<Void>` |
| Delete | `DELETE /v1/orders/{id}` | Returns `Result<Void>` |
| Sub-resource | `GET /v1/orders/{id}/items` | Nested resource under aggregate root |

### Anti-patterns

| Bad | Why | Good |
|-----|-----|------|
| `/getOrderList` | Action-based URL | `GET /v1/orders` |
| `/order/create` | Noun + verb | `POST /v1/orders` |
| `/api/v1/...` | Mixed prefix | `/v1/orders` (version in path) |
| Exposing `Order` entity | Leaks domain internals | `OrderDTO` at boundary |
| Exposing `OrderDO` | Leaks persistence internals | Convert via MapStruct |
| `ResponseEntity<T>` | Breaks unified format | `Result<T>` |

## HTTP Status Codes in Result<T>

| code | Usage | Response |
|------|-------|----------|
| 200 | All successful operations | `Result.success(data)` or `Result.success()` |
| 400 | Validation errors | `Result.fail(400, msg)` |
| 401 | Missing or invalid auth | `Result.fail(401, msg)` |
| 403 | No permission | `Result.fail(403, msg)` |
| 404 | Resource not found | `Result.fail(404, msg)` |
| 409 | Duplicate, state conflict | `Result.fail(409, msg)` |
| 500 | Unexpected server errors | `Result.fail(500, "Internal server error")` |

Never use String codes. Always use integer HTTP status codes.