---
name: spring-boot-logging
description: "Spring Boot logging with Log4j2, structured JSON logging, log levels per-package, and ThreadContext correlation. Use when configuring application logging for production observability."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Logging (Log4j2)

Logging configuration patterns for Spring Boot 3.5.x with Log4j2.

## When to use this skill

- Configuring Log4j2 for structured logging
- Setting log levels per package or class
- Adding ThreadContext (MDC equivalent) for request correlation
- Switching to JSON logging for production

## Dependency Setup

Exclude default Logback and use Log4j2:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <exclusions>
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-logging</artifactId>
        </exclusion>
    </exclusions>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-log4j2</artifactId>
</dependency>
```

## Configuration

### Basic (application.yml)

```yaml
logging:
  level:
    root: INFO
    com.example.service: DEBUG
    org.springframework.web: WARN
    org.mybatis: DEBUG
```

### log4j2-spring.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Properties>
        <Property name="LOG_PATTERN">%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</Property>
        <Property name="LOG_PATH">${sys:LOG_PATH:-/var/log/app}</Property>
    </Properties>

    <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout pattern="${LOG_PATTERN}"/>
        </Console>

        <RollingFile name="File" fileName="${LOG_PATH}/application.log"
                     filePattern="${LOG_PATH}/application-%d{yyyy-MM-dd}-%i.log.gz">
            <PatternLayout pattern="${LOG_PATTERN}"/>
            <Policies>
                <SizeBasedTriggeringPolicy size="50MB"/>
                <TimeBasedTriggeringPolicy interval="1" modulate="true"/>
            </Policies>
            <DefaultRolloverStrategy max="30">
                <Delete basePath="${LOG_PATH}" maxDepth="1">
                    <IfFileName glob="application-*.log.gz"/>
                    <IfAccumulatedFileSize exceeds="1GB"/>
                </Delete>
            </DefaultRolloverStrategy>
        </RollingFile>
    </Appenders>

    <Loggers>
        <Root level="INFO">
            <AppenderRef ref="Console"/>
            <AppenderRef ref="File"/>
        </Root>
    </Loggers>
</Configuration>
```

### JSON Structured Logging

Use Log4j2's built-in `JsonTemplateLayout` (no external dependency needed):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Appenders>
        <Console name="JSON-Console" target="SYSTEM_OUT">
            <JsonTemplateLayout eventTemplateUri="classpath:JsonLayout.json"/>
        </Console>
    </Appenders>

    <Loggers>
        <SpringProfile name="prod">
            <Root level="INFO">
                <AppenderRef ref="JSON-Console"/>
            </Root>
        </SpringProfile>

        <SpringProfile name="dev">
            <Root level="DEBUG">
                <AppenderRef ref="Console"/>
            </Root>
        </SpringProfile>
    </Loggers>
</Configuration>
```

Minimal `JsonLayout.json` (place in `src/main/resources/`):

```json
{
  "timestamp": {"$resolver": "timestamp"},
  "level": {"$resolver": "level"},
  "logger": {"$resolver": "loggerName"},
  "message": {"$resolver": "message"},
  "thread": {"$resolver": "threadName"},
  "traceId": {"$resolver": "mdc", "key": "traceId"},
  "requestPath": {"$resolver": "mdc", "key": "requestPath"},
  "appName": {"$resolver": "mdc", "key": "appName"}
}
```

## ThreadContext (MDC) Request Correlation

```java
@Component
@Order(1)
public class TraceIdFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        try {
            String traceId = request.getHeader("X-Trace-Id");
            if (traceId == null) {
                traceId = UUID.randomUUID().toString();
            }
            ThreadContext.put("traceId", traceId);
            ThreadContext.put("requestPath", request.getRequestURI());
            ThreadContext.put("method", request.getMethod());
            chain.doFilter(request, response);
        } finally {
            ThreadContext.clearAll();
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
- Add `traceId` via ThreadContext filter for request correlation across logs
- Use JSON structured logging in production for easy parsing by ELK/Loki
- Set per-package levels: `DEBUG` for your code, `WARN` for framework code
- Never log sensitive data (passwords, tokens, PII)
- Use `log4j2-spring.xml` with `<SpringProfile>` for environment-specific config
- Always clear ThreadContext in filter's `finally` block to prevent context leaking
- Exclude `spring-boot-starter-logging` when using Log4j2 — Spring Boot defaults to Logback

## Related Skills

- `spring-boot-actuator` — log level management via Actuator endpoints
- `spring-boot-exception-handling` — exception logging patterns in global exception handler