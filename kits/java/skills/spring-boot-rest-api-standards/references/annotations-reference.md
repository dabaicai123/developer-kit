# Spring Web + Jakarta Validation Annotations Reference

Core annotations for COLA/DDD REST controllers.

## Spring Web Annotations

### Controller

| Annotation | Purpose | Example |
|------------|---------|---------|
| `@RestController` | REST endpoint class | `@RestController` on adapter/controller classes |
| `@RequestMapping` | Base URL prefix | `@RequestMapping("/v1/orders")` |
| `@GetMapping` | Read endpoint | `@GetMapping("/{id}")` |
| `@PostMapping` | Create endpoint | `@PostMapping` |
| `@PutMapping` | Update endpoint | `@PutMapping("/{id}")` |
| `@DeleteMapping` | Delete endpoint | `@DeleteMapping("/{id}")` |

### Parameter Binding

| Annotation | Purpose | Example |
|------------|---------|---------|
| `@PathVariable` | URL path variable | `@PathVariable String id` |
| `@RequestParam` | Query parameter | `@RequestParam(defaultValue = "1") long page` |
| `@RequestBody` | Request body (JSON) | `@RequestBody CreateOrderCmd cmd` |
| `@RequestHeader` | HTTP header | `@RequestHeader("Authorization") String auth` |
| `@Valid` | Trigger validation | `@Valid @RequestBody CreateOrderCmd cmd` |

## Jakarta Validation Annotations

SpringDoc auto-generates constraints from these → see `spring-boot-openapi-documentation`.

| Annotation | Purpose | Chinese message example |
|------------|---------|------------------------|
| `@NotBlank` | Required non-empty string | `@NotBlank(message = "客户 ID 不能为空")` |
| `@NotNull` | Required non-null value | `@NotNull(message = "数量不能为空")` |
| `@NotEmpty` | Required non-empty collection | `@NotEmpty(message = "列表不能为空")` |
| `@Size(min, max)` | String/collection length | `@Size(max = 200, message = "名称最多 200 字符")` |
| `@Min` / `@Max` | Numeric range | `@Min(value = 1, message = "数量至少为 1")` |
| `@DecimalMin` / `@DecimalMax` | Decimal range | `@DecimalMin("0.0", message = "金额不能为负")` |
| `@Pattern(regex)` | Regex pattern | `@Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")` |
| `@Email` | Email format | `@Email(message = "邮箱格式不正确")` |
| `@Past` / `@Future` | Date in past/future | `@Past(message = "日期必须在过去")` |

## Lombok Annotations (COLA Common)

| Annotation | Purpose |
|------------|---------|
| `@Data` | Getter + setter + toString + equals + hashCode |
| `@RequiredArgsConstructor` | Constructor for final fields (inject dependencies) |
| `@Slf4j` | `log` field for logging |
| `@NoArgsConstructor` | No-arg constructor (for DTO deserialization) |
| `@AllArgsConstructor` | All-args constructor (used by `Result.success(data)`) |

> **mvnd + JDK 21 + Lombok**: Must add `<forceLegacyJavacApi>true</forceLegacyJavacApi>` to maven-compiler-plugin → see `ddd-cola`.