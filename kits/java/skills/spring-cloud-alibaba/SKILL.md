---
name: spring-cloud-alibaba
description: "Spring Cloud Alibaba with Nacos, Sentinel, RocketMQ, and Seata. Use for service discovery, flow control, or Alibaba Cloud integration in microservices."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Cloud Alibaba Development Guide

## When to use this skill

- Setting up Spring Cloud Alibaba components (Nacos, Sentinel, RocketMQ, Seata)
- Implementing service discovery or flow control in microservices

## Core Components

### 1. Nacos (Service Registration and Configuration Center)

**Nacos Server Installation**:

```bash
# Download and start Nacos
wget https://github.com/alibaba/nacos/releases/download/3.0.3/nacos-server-3.0.3.tar.gz
tar -xzf nacos-server-3.0.3.tar.gz
cd nacos/bin
sh startup.sh -m standalone
```

**Service Registration**:

NOT annotate `@EnableDiscoveryClient` — auto-configuration registers the service when the Nacos discovery dependency is present.

```java
@SpringBootApplication
public class UserServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(UserServiceApplication.class, args);
    }
}
```

**application.yml**:

```yaml
spring:
  application:
    name: user-service
  cloud:
    nacos:
      discovery:
        server-addr: localhost:8848
        namespace: dev
        group: DEFAULT_GROUP
```

**Configuration Management** (Spring Boot 3.x):

Use `spring.config.import` in `application.yml` — NOT `bootstrap.yml` (removed in Boot 3.x).

```yaml
spring:
  application:
    name: user-service
  profiles:
    active: dev
  cloud:
    nacos:
      config:
        server-addr: localhost:8848
        namespace: dev
        group: DEFAULT_GROUP
        file-extension: yaml
  config:
    import:
      - optional:nacos:user-service.yaml
      - optional:nacos:user-service-dev.yaml
      - optional:nacos:shared-datasource.yaml?group=SHARED_GROUP
```

**Naming convention for Nacos config files**:

| Config file in Nacos | Purpose |
|---------------------|---------|
| `${app-name}.yaml` | Application base config (all profiles) |
| `${app-name}-${profile}.yaml` | Profile-specific config (dev/test/prod) |
| `shared-*.yaml` | Shared configs across services (datasource, redis, etc.) |

- `optional:` prefix — app starts normally even if the config is missing in Nacos
- `?group=XXX` suffix — specify non-default group for shared configs
- Load order: later entries override earlier ones (profile-specific overrides base)

For detailed Nacos Config patterns (shared/extension configs, @RefreshScope, ConfigListener), see `spring-boot-configuration-management`.

### 2. Sentinel (Flow Control)

**Dependency**:

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-sentinel</artifactId>
</dependency>
```

**Configuration**:

```yaml
spring:
  cloud:
    sentinel:
      transport:
        dashboard: localhost:8080
        port: 8719
      datasource:
        flow:
          nacos:
            server-addr: localhost:8848
            dataId: ${spring.application.name}-flow-rules
            groupId: SENTINEL_GROUP
            rule-type: flow
```

**Flow Control**:

```java
@Service
public class UserService {
    @SentinelResource(value = "getUser", blockHandler = "getUserBlockHandler")
    public User getUser(Long id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
    }

    public User getUserBlockHandler(Long id, BlockException ex) {
        return new User();
    }
}
```

**Circuit Breaker and Degradation**:

```java
@SentinelResource(
    value = "getUser",
    fallback = "getUserFallback",
    blockHandler = "getUserBlockHandler"
)
public User getUser(Long id) { ... }

public User getUserFallback(Long id, Throwable ex) {
    return new User();
}
```

### 3. RocketMQ (Message Queue)

**Dependency**:

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-rocketmq</artifactId>
</dependency>
```

**Configuration**:

```yaml
spring:
  cloud:
    stream:
      rocketmq:
        binder:
          name-server: localhost:9876
        bindings:
          output:
            producer:
              group: user-service-group
```

**Message Sending**:

```java
@Service
public class UserService {
    private final RocketMQTemplate rocketMQTemplate;

    public UserService(RocketMQTemplate rocketMQTemplate) {
        this.rocketMQTemplate = rocketMQTemplate;
    }

    public void sendUserCreatedEvent(User user) {
        rocketMQTemplate.convertAndSend("user-topic", user);
    }
}
```

**Message Receiving**:

```java
@Slf4j
@Component
@RocketMQMessageListener(topic = "user-topic", consumerGroup = "user-consumer-group")
public class UserEventListener implements RocketMQListener<User> {
    @Override
    public void onMessage(User user) {
        log.info("Received user: {}", user.getName());
    }
}
```

### 4. Seata (Distributed Transactions)

NOT include Seata unless strong-consistency distributed transactions are confirmed necessary. Prefer local transactions + event-driven eventual consistency.

**Dependency** (only when strong consistency is required):

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-seata</artifactId>
</dependency>
```

## Common Dependencies

```xml
<!-- BOM (Spring Boot 3.5.x / Spring Cloud 2025.0.x) -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>2025.0.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>

<!-- Nacos Discovery -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
</dependency>

<!-- Nacos Config -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
</dependency>

<!-- Sentinel -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-sentinel</artifactId>
</dependency>

<!-- RocketMQ -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-rocketmq</artifactId>
</dependency>

<!-- OpenFeign (deprecated in Spring Cloud 2025.x; prefer RestClient) -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
```

## Constraints

- NOT use `@EnableDiscoveryClient` — auto-configuration handles service registration when the dependency is present
- NOT use `bootstrap.yml` for Nacos config — use `spring.config.import=nacos:` in application.yml
- NOT use Seata unless strong consistency is strictly required — heavy business intrusion (proxied data sources, undo_log tables, global locks)
- NOT use Dubbo for inter-service calls — requires separate RPC ports and binary protocol, incompatible with REST ecosystem; use OpenFeign or RestClient
- NOT store Sentinel rules locally — lost on restart; persist in Nacos datasource
- NOT share Nacos namespace across environments — always configure separate namespaces (dev, test, prod) to prevent config conflicts
- NOT mismatch BOM versions — Spring Cloud Alibaba version must align with Spring Boot and Spring Cloud versions (2025.0.0.0 = Boot 3.5.x + Cloud 2025.0.x)

## Keywords

`spring-cloud-alibaba`, `nacos`, `sentinel`, `rocketmq`, `seata`, `openfeign`, `restclient`, `dubbo`, `service-discovery`, `configuration-management`, `flow-control`, `circuit-breaker`, `rate-limiting`, `distributed-transaction`, `eventual-consistency`, `microservices`

## Related Skills

- `spring-boot-event-driven-patterns` — Event-driven patterns for eventual consistency
- `spring-cloud-gateway` — API gateway routing and filtering
- `spring-cloud-openfeign` — Declarative HTTP client (deprecated; prefer RestClient)
- `spring-boot-rest-client` — RestClient for HTTP calls (recommended over OpenFeign)
- `spring-boot-resilience4j` — Circuit breaker patterns (alternative to Sentinel)
- `spring-boot-actuator` — Monitoring, health checks, observability
- `ddd-cola` — DDD architecture and COLA framework for microservice design