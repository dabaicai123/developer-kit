# OpenAPI Annotations Reference

Core annotations for COLA/DDD Spring Boot projects. All `description` fields use Chinese.

## `@Tag` — Group Endpoints

```java
@Tag(name = "Order", description = "订单管理接口")
```

| Attribute | Purpose |
|-----------|---------|
| `name` | Tag identifier (English, matches aggregate root) |
| `description` | Group description (Chinese) |

## `@Operation` — Describe Endpoint

```java
@Operation(summary = "创建订单", description = "提交新订单，走写路径")
```

| Attribute | Purpose |
|-----------|---------|
| `summary` | Short label (Chinese, < 120 chars) |
| `description` | Detailed description (Chinese) |
| `hidden` | Hide from docs (`true`) |
| `deprecated` | Mark as deprecated |
| `security` | Security requirements |

## `@ApiResponse` / `@ApiResponses` — Document Responses

```java
@ApiResponse(responseCode = "200", description = "订单创建成功")
@ApiResponse(responseCode = "404", description = "订单不存在")
```

| Attribute | Purpose |
|-----------|---------|
| `responseCode` | HTTP status code |
| `description` | Response description (Chinese) |
| `content` | Response schema |

## `@Parameter` — Document Parameters

```java
@Parameter(description = "订单编号", example = "ORD-001", required = true)
```

| Attribute | Purpose |
|-----------|---------|
| `description` | Parameter description (Chinese) |
| `required` | Whether required |
| `example` | Example value |
| `hidden` | Hide from docs |

## `@Schema` — Document Models/Fields

```java
// Class level
@Schema(description = "创建订单命令")
public class CreateOrderCmd { }

// Field level
@Schema(description = "客户 ID", example = "cust-001", requiredMode = Schema.RequiredMode.REQUIRED)
@Schema(description = "订单编号", accessMode = Schema.AccessMode.READ_ONLY)
@Schema(description = "订单状态", allowableValues = {"PENDING", "CONFIRMED", "SHIPPED"})
```

| Attribute | Purpose |
|-----------|---------|
| `description` | Field description (Chinese) |
| `example` | Example value |
| `requiredMode` | REQUIRED, NOT_REQUIRED, AUTO |
| `accessMode` | READ_ONLY, WRITE_ONLY, READ_WRITE |
| `allowableValues` | Enumerated values |
| `hidden` | Hide from docs |
| `minimum`/`maximum` | Numeric range |
| `minLength`/`maxLength` | String length |

## `@SecurityRequirement` — Apply Security

```java
// Controller level — all endpoints require auth
@SecurityRequirement(name = "bearer-jwt")

// Method level — specific endpoint
@Operation(security = @SecurityRequirement(name = "bearer-jwt"))

// Override — no auth for this endpoint
@Operation(security = {})
```

## `@ParameterObject` — Document Pageable

```java
public Result<PageResult<OrderDTO>> listOrders(@ParameterObject Pageable pageable) { }
```

Auto-generates `page`, `size`, `sort` parameters.

## `@Hidden` — Hide Entire Controller

```java
@Hidden
@RestController
public class InternalController { }
```

## Auto-Documented Validation Annotations

SpringDoc auto-generates constraints from Jakarta validation — no extra `@Schema` needed for these:

| Annotation | Generates |
|------------|-----------|
| `@NotBlank` | required, minLength=1 |
| `@NotNull` | required, nullable=false |
| `@Size(min, max)` | minLength, maxLength |
| `@Min` / `@Max` | minimum, maximum |
| `@DecimalMin` / `@DecimalMax` | minimum, maximum |
| `@Email` | format=email |
| `@Pattern` | pattern (regex) |