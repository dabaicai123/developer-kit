---
name: ddd-cola
description: "COLA DDD architecture for Spring Boot: project scaffolding, layer structure (adapter/app/domain/infrastructure), dependency direction, gateway pattern, and naming conventions. Use when creating a Spring Boot project with COLA/DDD architecture or structuring layered applications."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# COLA DDD Architecture

## When to use this skill

Use when creating or structuring a Spring Boot project with COLA/DDD architecture, implementing domain-driven design with dependency-inverted layers.

## Quick Guide

| Your scenario | What to do |
|---------------|-----------|
| Starting a new project? | Follow **Project Setup** steps 1–7, then scaffold packages per **COLA Layer Structure** |
| Adding a new use case? | Pick CQRS path: Write → CmdExe → Domain → Gateway; Read → QryExe → Mapper |
| Unsure about a layer? | Adapter → `spring-boot-rest-api-standards` / `spring-boot-openapi-documentation`; Domain → this skill's Gateway + Entity examples; Infrastructure → `mybatis-plus-patterns` |
| Confused about naming? | See **Naming Per Layer** (Entity=none, Gateway=Gateway, DO=DO, CmdExe=CmdExe) |
| Confused about data flow? | Request → VO → DTO → Entity → DO → DB |

## Project Setup

### 1. Generate from Spring Initializr

Generate project from Spring Initializr with Java 21, Spring Boot 3.5.1, and dependencies: web, postgresql, data-redis, validation, lombok, configuration-processor, cache, testcontainers.

### 2. Add Dependencies

Add MyBatis-Plus and pagination plugin dependencies. See `mybatis-plus-patterns` for versions and configuration.

### 3. .gitignore

Use standard Java .gitignore patterns (target/, .idea/, *.iml, .DS_Store, *.log, .env).

### 4. Configuration

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/demo
    username: postgres
    password: postgres
    driver-class-name: org.postgresql.Driver
  data:
    redis:
      host: localhost
      port: 6379

mybatis-plus:
  configuration:
    map-underscore-to-camel-case: true
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl
  global-config:
    db-config:
      id-type: assign_id
      logic-delete-field: deletedAt
      logic-delete-value: "now()"
      logic-not-delete-value: ""
```

### 5. Docker Compose

Use Docker Compose for PostgreSQL and Redis. See `docker-expert` for production Compose patterns.

### 6. mvnd + JDK 21 + Lombok Compatibility

When using **mvnd (Maven Daemon)** with **JDK 21** and **Lombok**, annotation processing silently fails.
mvnd uses the JSR 199 `javax.tools.JavaCompiler` API, which blocks Lombok from accessing `com.sun.tools.javac.*`
internal APIs needed for AST modification. Symptoms include:
- `log` not found (from `@Slf4j`)
- `getId()` not found (from `@Data`)
- `builder()` not found (from `@Builder`)
- Constructor type inference failures (from `@AllArgsConstructor`)

**Fix**: Add `<forceLegacyJavacApi>true</forceLegacyJavacApi>` to `maven-compiler-plugin`:

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <configuration>
    <forceLegacyJavacApi>true</forceLegacyJavacApi>
  </configuration>
</plugin>
```

This forces mvnd to use the legacy javac API, restoring Lombok's annotation processing capability.

### 7. External HTTP Client

- Use **RestClient** (Spring 6.1+, included in `spring-boot-starter-web`, no extra dependency)
- **OkHttp3**: only for WebSocket or custom interceptor scenarios; not managed by Spring Boot parent
- For detailed configuration and usage → see `spring-boot-rest-client` skill

> **Note**: Dependencies not managed by `spring-boot-starter-parent` (e.g., OkHttp3, Fastjson2) require explicit `<version>`.

## COLA Layer Structure

```
com.example.app/
├── adapter/
│   ├── controller/        # HTTP inbound handlers
│   └── scheduler/         # Scheduled tasks
├── app/
│   ├── executor/          # Command/Query executors — actual use case handlers
│   └── service/           # Application service facade — delegates to executors
├── domain/
│   ├── model/             # Entities, Value Objects, Aggregates
│   │   ├── entity/        # Bare names (Order, Customer) — no suffix, no ORM annotations
│   │   └── valueobject/
│   ├── service/           # Domain services
│   └── gateway/           # Repository and external service interfaces (ports)
└── infrastructure/
    ├── gatewayimpl/        # Gateway implementations (implements domain gateway interfaces)
    ├── mapper/             # MyBatis Mapper interfaces + DO classes
    ├── external/           # External API clients (RestClient)
    └── config/             # Spring configuration
```

### Naming Per Layer

| Layer | Class Type | Suffix | Example |
|-------|-----------|--------|---------|
| Domain | Entity | none | `Order` |
| Domain | Gateway | Gateway | `OrderGateway` |
| Domain | Value Object | none | `Money` |
| Domain | Domain Event | Event | `OrderCreatedEvent` |
| Application | Service | none (interface ends with `I`) | `MetricsServiceI` |
| Application | Executor (Command) | CmdExe | `ATAMetricAddCmdExe` |
| Application | Executor (Query) | QryExe | `ATAMetricQryExe` |
| Application | Command | Cmd | `CreateOrderCmd` |
| Application | Query | Qry | `ATAMetricQry` |
| Infrastructure | Data Object | DO | `OrderDO` |
| Infrastructure | Gateway Impl | GatewayImpl | `OrderGatewayImpl` |
| Adapter | Controller | Controller | `OrderController` |

### App Layer: Service vs Executor

**Service** is the facade (entry point), **Executor** is the processor. They work together, not as alternatives.

```
Controller → Service (thin facade) → Executor (actual handler)
```

| Component | Package | Responsibility | Contains Logic? |
|-----------|---------|---------------|----------------|
| **Application Service** | `app/service/` | Implements client API interface; delegates each method to a specific Executor | No — pure delegation/routing |
| **Command Executor** | `app/executor/` | Handles write operations: orchestrates domain objects, manages transaction boundaries | Yes — coordinates Domain + Gateway |
| **Query Executor** | `app/executor/` | Handles read operations: queries Infrastructure directly, bypasses Domain for performance | Yes — assembles query results |

```java
// app/service/ — thin facade, no business logic
@Service
@RequiredArgsConstructor
public class MetricsServiceImpl implements MetricsServiceI {
    private final ATAMetricAddCmdExe ataMetricAddCmdExe;
    private final ATAMetricQryExe ataMetricQryExe;

    @Override
    public Response addATAMetric(ATAMetricAddCmd cmd) {
        return ataMetricAddCmdExe.execute(cmd);
    }

    @Override
    public MultiResponse<ATAMetricDTO> listATAMetrics(ATAMetricQry qry) {
        return ataMetricQryExe.execute(qry);
    }
}

// app/executor/ — write handler, goes through Domain
@Component
@RequiredArgsConstructor
public class ATAMetricAddCmdExe {
    private final MetricGateway metricGateway;

    @Transactional
    public Response execute(ATAMetricAddCmd cmd) {
        Metric metric = new Metric(cmd);
        metricGateway.save(metric);
        return Response.buildSuccess();
    }
}

// app/executor/ — read handler, bypasses Domain
@Component
@RequiredArgsConstructor
public class ATAMetricQryExe {
    private final MetricMapper metricMapper;

    public MultiResponse<ATAMetricDTO> execute(ATAMetricQry qry) {
        List<MetricDO> records = metricMapper.selectByQry(qry);
        return MultiResponse.of(records.stream().map(MetricDTO::fromDO).toList());
    }
}
```

> **Single-module (cola-archetype-light)**: Service can be omitted — Controller calls Executor directly.
> **Multi-module with Client**: Service is required — it implements the client API interface and is the only entry point to the Application layer.

### CQRS Paths

| Type | Path | Notes |
|------|------|-------|
| **Command (Write)** | Controller → Service → CmdExe → Domain → Gateway → DB | Must go through Domain layer to enforce business rules |
| **Query (Read)** | Controller → Service → QryExe → Mapper → DB | Bypasses Domain layer; queries Infrastructure directly for performance |

Key differences:
- **Write**: Domain entity handles validation and business logic; Gateway (port) abstracts persistence; Infrastructure implements Gateway
- **Read**: No domain entity needed; Query executor calls Mapper directly; returns DTO, never Domain entity or DO

### Dependency Direction

```
Adapter → Application → Domain ← Infrastructure
```

- **Domain** depends on nothing
- **Application** depends on Domain
- **Adapter/Infrastructure** depend on Application and Domain
- Never: Domain → Application (upward), Domain → Infrastructure (upward)

### Data Object Flow Per Layer

```
Request → VO → DTO → Entity → DO → DB
Response → DO → Entity → DTO → VO
```

Conversion tools: MapStruct at each boundary → see `mapstruct-patterns`

### Example: Use Case Executor

```java
// Domain entity — bare name, no suffix, no ORM annotations
public class Order {
    private String orderId;
    private List<OrderItem> items;
    private OrderStatus status;

    public static Order create(List<OrderItem> items, String customerId) {
        Order order = new Order();
        order.orderId = IdUtil.simpleUUID();
        order.items = items;
        order.status = OrderStatus.PENDING;
        return order;
    }
}

// Domain gateway (port) — define both insert and update methods
public interface OrderGateway {
    void save(Order order);
    void update(Order order);
    Optional<Order> findById(String id);
}

// Application executor (write — command handler)
@Component
public class CreateOrderCmdExe {
    private final OrderGateway orderGateway;

    public CreateOrderCmdExe(OrderGateway orderGateway) {
        this.orderGateway = orderGateway;
    }

    @Transactional
    public OrderDTO execute(CreateOrderCmd cmd) {
        Order order = Order.create(cmd.getItems(), cmd.getCustomerId());
        orderGateway.save(order);
        return OrderDTO.from(order);
    }
}

// Infrastructure DO — persistence mapping with MyBatis-Plus annotations
@TableName("order")
public class OrderDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
    private String orderId;
    private String status;

    @TableLogic(value = "", delval = "now()")
    private LocalDateTime deletedAt;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @Version
    private Integer version;

    // Manual conversion placeholder — use MapStruct converter → see mapstruct-patterns
    // Replace with: private final OrderDOConverter orderDOConverter;
    // orderDOConverter.toDO(order) / orderDOConverter.toDomain(orderDO)
    public static OrderDO fromDomain(Order order) { /* manual mapping */ }
    public Order toDomain() { /* manual mapping */ }
}

// Infrastructure gateway implementation (MyBatis-Plus)
// Package: infrastructure/gatewayimpl/
@Repository
public class OrderGatewayImpl implements OrderGateway {
    private final OrderMapper orderMapper;
    // Option A: Manual conversion (simple, few fields)
    // Option B: MapStruct converter → see mapstruct-patterns

    @Override
    public void save(Order order) {
        orderMapper.insert(OrderDO.fromDomain(order));  // INSERT — for new records
    }

    @Override
    public void update(Order order) {
        orderMapper.updateById(OrderDO.fromDomain(order));  // UPDATE — for existing records
    }

    @Override
    public Optional<Order> findById(String id) {
        return Optional.ofNullable(orderMapper.selectOne(
            new LambdaQueryWrapper<OrderDO>().eq(OrderDO::getOrderId, id)))
            .map(OrderDO::toDomain);
    }
}
```

## Best Practices

- Domain logic belongs exclusively in the Domain layer; Application only orchestrates and manages transaction boundaries → see `spring-boot-transaction-management`
- Define ports (interfaces) in Domain or Application; Infrastructure implements them
- Avoid business logic in Adapter layer; DTO/domain conversion at boundary
- Follow COLA naming: `Cmd` for commands, `CmdExe` for command handlers, `QryExe` for query handlers, `Gateway` for ports, `ServiceI` for application service interfaces
- Domain entities use **bare names** (no suffix); Infrastructure DOs use **DO suffix**
- Use `@TableLogic(value = "", delval = "now()")` with `deleted_at TIMESTAMPTZ` for soft delete
- Use `@TableId(type = IdType.ASSIGN_ID)` for distributed ID generation
- Use `@TableName("xxx")` with plain snake_case — no prefix
- Use `@Transactional(readOnly = true)` for multi-step query executors only (not single-statement queries) → see `spring-boot-transaction-management`
- Use `LambdaQueryWrapper` in Infrastructure persistence, never raw `QueryWrapper`
- Use MapStruct converters at layer boundaries instead of manual `fromDomain()/toDomain()` → see `mapstruct-patterns`
- **Sealed interface pattern**: when using `sealed interface` for commands/events:
  1. Import the sealed interface alongside its permit-listed subtypes — `import AuthorizeAccountCmd;` is required even when only casting to `OAuthAuthorizeCmd`
  2. Call subtype-specific methods only after pattern-match or explicit cast — sealed interface itself has no methods (`if (cmd instanceof OAuthAuthorizeCmd oauth) { oauth.clientId(); }`)
- **Verify import completeness** — after writing source or test files, check all symbols have explicit imports. Common misses: `java.util.Map`, sealed interface types, Hamcrest matchers

## Related Skills

- `ddd-event-driven` — domain event design, event stores, aggregate boundaries
- `spring-boot-transaction-management` — @Transactional patterns for executor and service layer
- `spring-boot-rest-client` — RestClient/WebClient/OkHttp selection, configuration, and testing for `infrastructure/external/`
- `mybatis-plus-patterns` — MyBatis-Plus persistence patterns for Infrastructure layer (MVC IService pattern)
- `mapstruct-patterns` — MapStruct converters for Domain ↔ DO and Domain ↔ DTO at layer boundaries
- `spring-boot-dependency-injection` — constructor injection, Bean lifecycle for COLA layers

## Keywords

cola, COLA architecture, COLA V5, DDD, project setup, spring boot project creation, adapter, application, domain, infrastructure, gateway, gatewayimpl, mapper, executor, dependency inversion, RestClient