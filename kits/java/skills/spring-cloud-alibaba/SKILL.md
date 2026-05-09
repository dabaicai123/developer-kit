---
name: spring-cloud-alibaba
description: "Spring Cloud Alibaba with Nacos, Sentinel, RocketMQ, and Alibaba Cloud integration. Use when implementing service discovery with Nacos, circuit breaking with Sentinel, or working with Alibaba Cloud services."
version: "1.0.0"
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
# Download Nacos
wget https://github.com/alibaba/nacos/releases/download/3.1.1/nacos-server-3.1.1.tar.gz

# Extract and start
tar -xzf nacos-server-3.1.1.tar.gz
cd nacos/bin
sh startup.sh -m standalone
```

**Service Registration**:

```java
@SpringBootApplication
@EnableDiscoveryClient
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

**Configuration Management**: For detailed Nacos Config patterns (bootstrap.yml, shared/extension configs, @RefreshScope, ConfigListener), see `spring-boot-configuration-management`.

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
        return new User(); // Degraded fallback response
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
public User getUser(Long id) {
    // Business logic
}

public User getUserFallback(Long id, Throwable ex) {
    // Degraded fallback handling
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
@Component
@RocketMQMessageListener(
    topic = "user-topic",
    consumerGroup = "user-consumer-group"
)
public class UserEventListener implements RocketMQListener<User> {
    @Override
    public void onMessage(User user) {
        // Process message
        System.out.println("Received user: " + user.getName());
    }
}
```

### 4. Seata (Distributed Transactions)

**Dependency** (only include when strong-consistency distributed transactions are confirmed necessary):

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-seata</artifactId>
</dependency>
```

## Microservice Architecture Example

### Project Structure

```
microservices/
├── nacos-server/           # Nacos service
├── gateway/                # API gateway
├── user-service/           # User service
├── order-service/          # Order service
└── product-service/        # Product service
```

For unified configuration management patterns, see `spring-boot-configuration-management`.

## Common Dependencies

```xml
<!-- BOM (Spring Boot 3.5.x) -->
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

<!-- OpenFeign (recommended over Dubbo) -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
```

## Constraints / Warnings

- **Seata**: Avoid unless strong consistency is strictly required. Heavy business intrusion (proxied data sources, undo_log tables, global transaction locks). Prefer local transactions + event-driven eventual consistency.
- **Dubbo**: Not recommended for inter-service calls. Requires additional RPC ports and binary protocol management, incompatible with Spring Cloud REST ecosystem. Use OpenFeign instead.
- **Nacos namespace**: Always configure separate namespaces for different environments (dev, test, prod) to prevent configuration conflicts.
- **Sentinel rules**: Store flow rules in Nacos for persistence; otherwise, rules are lost on application restart.
- **RocketMQ**: Ensure the name-server is accessible and the producer/consumer group names are unique across services.
- **Version alignment**: The Spring Cloud Alibaba BOM version must align with the Spring Boot and Spring Cloud versions. Check the official version mapping table before upgrading.

## Keywords

`spring-cloud-alibaba`, `nacos`, `sentinel`, `rocketmq`, `seata`, `openfeign`, `dubbo`, `service-discovery`, `configuration-management`, `flow-control`, `circuit-breaker`, `rate-limiting`, `distributed-transaction`, `event-driven`, `eventual-consistency`, `microservices`

## Related Skills

- [spring-boot-event-driven-patterns](../spring-boot-event-driven-patterns/SKILL.md) — Event-driven patterns for eventual consistency and async processing
- [spring-cloud-gateway](../spring-cloud-gateway/SKILL.md) — API gateway routing and filtering
- [spring-cloud-openfeign](../spring-cloud-openfeign/SKILL.md) — Declarative HTTP client configuration and best practices
- [spring-boot-resilience4j](../spring-boot-resilience4j/SKILL.md) — Circuit breaker and resilience patterns (alternative to Sentinel)
- [spring-boot-actuator](../spring-boot-actuator/SKILL.md) — Monitoring, health checks, and observability
- [ddd-cola](../ddd-cola/SKILL.md) — DDD architecture and COLA framework for microservice design