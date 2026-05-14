---
name: spring-cloud-alibaba
description: "Integrates Spring Cloud Alibaba with Nacos, Sentinel, RocketMQ, and Seata. Use when adding service discovery, configuration management, flow control, messaging, distributed transactions, or Alibaba Cloud microservice patterns."
version: "1.2.0"
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

NOT include Seata unless strong-consistency distributed transactions are confirmed necessary. Heavy business intrusion (proxied data sources, undo_log tables, global locks). Prefer local transactions + event-driven eventual consistency.

## BOM and Dependencies

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>2025.0.1.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

Component starters (add only what you need):

| Component | artifactId |
|-----------|-----------|
| Nacos Discovery | `spring-cloud-starter-alibaba-nacos-discovery` |
| Nacos Config | `spring-cloud-starter-alibaba-nacos-config` |
| Sentinel | `spring-cloud-starter-alibaba-sentinel` |
| RocketMQ | `spring-cloud-starter-alibaba-rocketmq` |
| Seata | `spring-cloud-starter-alibaba-seata` |
| OpenFeign | `spring-cloud-starter-openfeign` (deprecated; prefer RestClient) |

## Constraints

- NOT use `@EnableDiscoveryClient` — auto-configuration handles service registration when the dependency is present
- NOT use `bootstrap.yml` for Nacos config — use `spring.config.import=nacos:` in application.yml
- NOT use Seata unless strong consistency is strictly required — heavy business intrusion (proxied data sources, undo_log tables, global locks)
- NOT use Dubbo for inter-service calls — requires separate RPC ports and binary protocol, incompatible with REST ecosystem; use OpenFeign or RestClient
- NOT store Sentinel rules locally — lost on restart; persist in Nacos datasource
- NOT share Nacos namespace across environments — always configure separate namespaces (dev, test, prod) to prevent config conflicts
- NOT mismatch BOM versions — Spring Cloud Alibaba version must align with Spring Boot and Spring Cloud versions (2025.0.1.0 = Boot 3.5.x + Cloud 2025.0.x)

## Related Skills

`spring-boot-event-driven-patterns`, `spring-cloud-gateway`, `spring-cloud-openfeign`, `spring-boot-rest-client`, `spring-boot-resilience4j`, `spring-boot-actuator`, `ddd-cola`
