---
name: spring-boot-logging
description: Spring Boot logging configuration patterns covering Logback, structured JSON logging, log levels per-package, and MDC correlation. Use when configuring application logging for production observability.
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Logging

Logging configuration patterns for Spring Boot 3.5.x.

## When to Use

- Configuring Logback for structured logging
- Setting log levels per package or class
- Adding MDC (Mapped Diagnostic Context) for request correlation
- Switching to JSON logging for production

## Configuration

### Basic (application.yml)

```yaml
logging:
  level:
    root: INFO
    com.example.service: DEBUG
    org.springframework.web: WARN
    org.mybatis: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
  file:
    name: ${LOG_PATH:/var/log/app}/application.log
    max-size: 50MB
    max-history: 30
    total-size-cap: 1GB
```

### JSON Structured Logging (logback-spring.xml)

```xml
<configuration>
    <springProfile name="prod">
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeContext>true</includeContext>
                <includeMdc>true</includeMdc>
                <customFields>{"app_name":"${spring.application.name}"}</customFields>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="JSON"/>
        </root>
    </springProfile>

    <springProfile name="dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %highlight(%-5level) %cyan(%logger{36}) - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="DEBUG">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>
</configuration>
```

Dependency for JSON encoder:
```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>8.0</version>
</dependency>
```

## MDC Request Correlation

```java
@Component
@Order(1)
public class MdcFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        try {
            String traceId = request.getHeader("X-Trace-Id");
            if (traceId == null) {
                traceId = UUID.randomUUID().toString();
            }
            MDC.put("traceId", traceId);
            MDC.put("requestPath", request.getRequestURI());
            MDC.put("method", request.getMethod());
            chain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}
```

## Logging Best Practices in Code

```java
@Service
@Slf4j
public class OrderService {

    // Good: include key identifiers
    public Order createOrder(CreateOrderRequest request) {
        log.info("Creating order for userId={}", request.getUserId());
        // ...
        log.debug("Order created: orderId={}", order.getId());
        return order;
    }

    // Bad: log entire objects or use string concatenation
    // log.info("Order: " + order);  — avoid this
    // log.info("Creating order for user " + user);  — use parameterized logging
}
```

## Per-Environment Levels

```yaml
# application-dev.yml
logging:
  level:
    root: DEBUG
    org.mybatis: DEBUG

# application-prod.yml
logging:
  level:
    root: WARN
    com.example.service: INFO
```

## Best Practices

- Use parameterized logging: `log.info("userId={}", id)` — not string concatenation
- Add `traceId` via MDC filter for request correlation across logs
- Use JSON structured logging in production for easy parsing by ELK/Loki
- Set per-package levels: `DEBUG` for your code, `WARN` for framework code
- Never log sensitive data (passwords, tokens, PII)
- Use `logback-spring.xml` with `<springProfile>` for environment-specific config
- Always clear MDC in filter's `finally` block to prevent context leaking