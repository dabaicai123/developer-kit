# Spring Web + Jakarta Validation Annotations Reference

Core annotations for COLA/DDD REST controllers. Spring Boot 3.5 baseline: Jakarta EE 10+, JDK 21.

## Spring Web Annotations

### Controller

| Annotation | Purpose | Example |
|------------|---------|---------|
| `@RestController` | REST endpoint class | `@RestController` on adapter/web classes |
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
| `@ParameterObject` | Bind query params to object (Spring Boot 3.5+) | `@ParameterObject CustomerListQry qry` |
| `@RequestBody` | Request body (JSON) | `@RequestBody CreateOrderCmd cmd` |
| `@RequestHeader` | HTTP header | `@RequestHeader("Authorization") String auth` |
| `@Valid` | Trigger validation | `@Valid @RequestBody CreateOrderCmd cmd` |

NOT `javax.validation` → use `jakarta.validation` (Spring Boot 3.x+).
NOT manual `@RequestParam` for each query field → use `@ParameterObject` + Qry object.

## Jakarta Validation Annotations

SpringDoc auto-generates constraints from these → see `spring-boot-openapi-documentation`.

| Annotation | Purpose | Example |
|------------|---------|---------|
| `@NotBlank` | Required non-empty string | `@NotBlank(message = "Customer ID must not be blank")` |
| `@NotNull` | Required non-null value | `@NotNull(message = "Quantity must not be null")` |
| `@NotEmpty` | Required non-empty collection | `@NotEmpty(message = "List must not be empty")` |
| `@Size(min, max)` | String/collection length | `@Size(max = 200, message = "Name max 200 characters")` |
| `@Min` / `@Max` | Numeric range | `@Min(value = 1, message = "Quantity must be at least 1")` |
| `@DecimalMin` / `@DecimalMax` | Decimal range | `@DecimalMin("0.0", message = "Amount must not be negative")` |
| `@Pattern(regex)` | Regex pattern | `@Pattern(regexp = "^1[3-9]\\d{9}$", message = "Invalid phone format")` |
| `@Email` | Email format | `@Email(message = "Invalid email format")` |
| `@Past` / `@Future` | Date in past/future | `@Past(message = "Date must be in the past")` |

## Lombok Annotations (COLA Common)

| Annotation | Purpose |
|------------|---------|
| `@Data` | Getter + setter + toString + equals + hashCode |
| `@RequiredArgsConstructor` | Constructor for final fields (inject dependencies) |
| `@Slf4j` | `log` field for logging |
| `@NoArgsConstructor` | No-arg constructor (DTO deserialization) |
| `@AllArgsConstructor` | All-args constructor |

Lombok 1.18.30+ supports JDK 21 without `forceLegacyJavacApi`. Use Lombok ≥ 1.18.30 for Spring Boot 3.5. → see `ddd-cola`.