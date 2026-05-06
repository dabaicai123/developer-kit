---
name: ddd-cola
description: "COLA DDD architecture skill: project scaffolding, POM dependencies, COLA layer structure (adapter/app/domain/infrastructure), dependency direction, gateway pattern, naming conventions. Use when creating a Spring Boot project, setting up COLA/DDD architecture, or structuring layered applications."
version: "1.0.0"
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
  -d bootVersion=3.5.14 \
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

### 3. Configuration

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
      id-type: auto
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0
```

### 4. Docker Compose

```yaml
services:
  postgres:
    image: postgres:17
    ports: ["5432:5432"]
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: demo
  redis:
    image: redis:7
    ports: ["6379:6379"]
```

### 5. Maven Commands

| Command | Description |
|---------|------------|
| `mvn clean test` | Clean build + run tests |
| `mvn dependency:tree` | View dependency tree |
| `mvn dependency:analyze` | Find unused/undeclared deps |
| `mvn versions:display-dependency-updates` | Check for updates |
| `mvn -B verify` | Batch mode build |

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
│   │   ├── entity/
│   │   └── valueobject/
│   ├── service/           # Domain services
│   └── gateway/           # Repository and external service interfaces (ports)
└── infrastructure/
    ├── persistence/       # Repository implementations (MyBatis-Plus)
    ├── external/          # External API clients
    └── config/            # Spring configuration
```

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
// Domain gateway (port)
public interface OrderGateway {
    void save(Order order);
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

// Infrastructure implementation (MyBatis-Plus)
@Repository
public class OrderGatewayImpl implements OrderGateway {
    private final OrderMapper orderMapper;

    @Override
    public void save(Order order) {
        orderMapper.insert(OrderEntity.fromDomain(order));
    }
}
```

## Best Practices

- Domain logic belongs exclusively in the Domain layer; Application only orchestrates and manages transaction boundaries
- Define ports (interfaces) in Domain or Application; Infrastructure implements them
- Avoid business logic in Adapter layer; DTO/domain conversion at boundary
- Follow COLA naming: `Cmd` for commands, `Executor` for handlers, `Gateway` for ports
- Use `@Transactional(readOnly = true)` for query executors
- Use `LambdaQueryWrapper` in Infrastructure persistence, never raw `QueryWrapper`

## Keywords

cola, COLA architecture, COLA V5, DDD, project setup, spring boot project creation, adapter, application, domain, infrastructure, gateway, executor, dependency inversion