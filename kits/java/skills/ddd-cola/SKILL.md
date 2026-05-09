---
name: ddd-cola
description: "COLA DDD architecture for Spring Boot: project scaffolding, layer structure (adapter/app/domain/infrastructure), dependency direction, gateway pattern, and naming conventions. Use when creating a Spring Boot project with COLA/DDD architecture or structuring layered applications."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

## When to use this skill

Use this skill whenever the user wants to:
- Create a new Spring Boot + MyBatis-Plus project
- Structure a project using COLA architecture (Adapter, Application, Domain, Infrastructure)
- Apply COLA's layered architecture with clear responsibilities per layer
- Implement domain-driven design with COLA while keeping the domain layer pure and dependency-inverted

## Project Setup

### 1. Generate from Spring Initializr

```bash
curl https://start.spring.io/starter.zip \
  -d artifactId=demo-java \
  -d bootVersion=3.5.1 \
  -d dependencies=lombok,configuration-processor,web,postgresql,data-redis,validation,cache,testcontainers \
  -d javaVersion=21 \
  -d packageName=com.example \
  -d type=maven-project \
  -o starter.zip

unzip starter.zip -d ./demo-java && rm starter.zip && cd demo-java
```

### 2. Add Dependencies

```xml
<!-- MyBatis-Plus -->
<dependency>
  <groupId>com.baomidou</groupId>
  <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
  <version>3.5.9</version>
</dependency>
<!-- Pagination plugin (required since 3.5.9) -->
<dependency>
  <groupId>com.baomidou</groupId>
  <artifactId>mybatis-plus-jsqlparser</artifactId>
  <version>3.5.9</version>
</dependency>
<!-- PostgreSQL Driver -->
<dependency>
  <groupId>org.postgresql</groupId>
  <artifactId>postgresql</artifactId>
  <scope>runtime</scope>
</dependency>
<!-- OpenAPI Documentation -->
<dependency>
  <groupId>org.springdoc</groupId>
  <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
  <version>2.8.6</version>
</dependency>
<!-- Architecture Testing -->
<dependency>
  <groupId>com.tngtech.archunit</groupId>
  <artifactId>archunit-junit5</artifactId>
  <version>1.2.1</version>
  <scope>test</scope>
</dependency>
```

### 3. .gitignore

Append to the generated `.gitignore`:

```gitignore
# Build
target/
*.jar
*.war

# IDE
.idea/
*.iml
.vscode/
.settings/
.classpath
.project

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Environment
.env
.env.local

# JAVA
target/
```

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

```yaml
services:
  postgres:
    image: postgres:18
    ports: ["5432:5432"]
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: demo
  redis:
    image: redis:7
    ports: ["6379:6379"]
```

### 6. Maven Commands

| Command | Description |
|---------|------------|
| `mvn clean test` | Clean build + run tests |
| `mvn dependency:tree` | View dependency tree |
| `mvn dependency:analyze` | Find unused/undeclared deps |
| `mvn versions:display-dependency-updates` | Check for updates |
| `mvn -B verify` | Batch mode build |
| `mvnd -t 4 compile` | mvnd parallel compile (4 threads) |

### 7. mvnd + JDK 21 + Lombok Compatibility

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

### 8. External HTTP Client

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
│   ├── executor/          # Use case executors (command handlers)
│   └── service/           # Application services (orchestration, transactions)
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
| Application | Executor | Executor | `CreateOrderExecutor` |
| Application | Command | Cmd | `CreateOrderCmd` |
| Infrastructure | Data Object | DO | `OrderDO` |
| Infrastructure | Gateway Impl | GatewayImpl | `OrderGatewayImpl` |
| Adapter | Controller | Controller | `OrderController` |

### Dependency Direction

```
Adapter → Application → Domain ← Infrastructure
```

- **Domain** depends on nothing
- **Application** depends on Domain
- **Adapter/Infrastructure** depend on Application and Domain
- Never: Domain → Application (upward), Domain → Infrastructure (upward)

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

// Application executor
@Component
public class CreateOrderExecutor {
    private final OrderGateway orderGateway;

    public CreateOrderExecutor(OrderGateway orderGateway) {
        this.orderGateway = orderGateway;
    }

    @Transactional
    public OrderDto execute(CreateOrderCmd cmd) {
        Order order = Order.create(cmd.getItems(), cmd.getCustomerId());
        orderGateway.save(order);
        return OrderDto.from(order);
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
- Follow COLA naming: `Cmd` for commands, `Executor` for handlers, `Gateway` for ports
- Domain entities use **bare names** (no suffix); Infrastructure DOs use **DO suffix**
- Use `@TableLogic(value = "", delval = "now()")` with `deleted_at TIMESTAMPTZ` for soft delete
- Use `@TableId(type = IdType.ASSIGN_ID)` for distributed ID generation
- Use `@TableName("xxx")` with plain snake_case — no prefix
- Use `@Transactional(readOnly = true)` for query executors → see `spring-boot-transaction-management`
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