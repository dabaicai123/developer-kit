---
name: spring-boot-logging
description: "Spring Boot logging with Log4j2, structured JSON logging, log levels per-package, and ThreadContext correlation. Use when configuring application logging for production observability."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Logging

Logging configuration patterns for Spring Boot 3.5.x with Log4j2.

## When to use this skill

- Configuring Log4j2 for structured logging
- Setting log levels per package or class
- Adding ThreadContext (MDC equivalent) for request correlation
- Switching to JSON logging for production
- Enabling async logging with LMAX Disruptor for production performance

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
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout pattern="%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"/>
        </Console>
        <Console name="JSON-Console" target="SYSTEM_OUT">
            <JsonTemplateLayout eventTemplateUri="classpath:JsonLayout.json"/>
        </Console>
    </Appenders>

    <Loggers>
        <SpringProfile name="prod">
            <Root level="INFO" includeLocation="false">
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

> Note: Log4j2's JsonTemplateLayout uses `"mdc"` as the resolver key name for ThreadContext entries. `ThreadContext.put("traceId", ...)` is resolved by `{"$resolver": "mdc", "key": "traceId"}`.

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

## ThreadContext Request Correlation

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

## Async Logging (Required for Production)

Log4j2 supports two async logging modes. **Production deployments must use async logging** to prevent I/O from blocking business threads.

### Dependency

```xml
<dependency>
    <groupId>com.lmax</groupId>
    <artifactId>disruptor</artifactId>
    <version>4.0</version>
    <scope>runtime</scope>
</dependency>
```

### Mode 1: All-Async (Recommended)

All loggers become async via LMAX Disruptor ring buffer. Set system property before Spring context starts:

```java
@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        // Enable all-async loggers before Spring Boot starts
        System.setProperty("log4j2.contextSelector",
            "org.apache.logging.log4j.core.async.AsyncLoggerContextSelector");
        SpringApplication.run(Application, args);
    }
}
```

Or via JVM argument: `-Dlog4j2.contextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector`

When all-async is enabled, use **regular `<Logger>` and `<Root>`** in config (no `<AsyncLogger>` needed):

```xml
<Configuration status="WARN">
    <Properties>
        <Property name="LOG_PATH">${sys:LOG_PATH:-/var/log/app}</Property>
    </Properties>
    <Appenders>
        <RollingFile name="File" fileName="${LOG_PATH}/application.log"
                     filePattern="${LOG_PATH}/application-%d{yyyy-MM-dd}-%i.log.gz">
            <JsonTemplateLayout eventTemplateUri="classpath:JsonLayout.json"/>
            <Policies>
                <SizeBasedTriggeringPolicy size="50MB"/>
                <TimeBasedTriggeringPolicy interval="1" modulate="true"/>
            </Policies>
        </RollingFile>
        <Console name="Console" target="SYSTEM_OUT">
            <JsonTemplateLayout eventTemplateUri="classpath:JsonLayout.json"/>
        </Console>
    </Appenders>
    <Loggers>
        <Root level="INFO" includeLocation="false">
            <AppenderRef ref="Console"/>
            <AppenderRef ref="File"/>
        </Root>
    </Loggers>
</Configuration>
```

### Mode 2: Mixed Async (Selective)

Use `<AsyncLogger>` and `<AsyncRoot>` for specific loggers, `<Logger>` for sync ones. No system property needed:

```xml
<Loggers>
    <!-- Async: high-frequency business logs -->
    <AsyncLogger name="com.example" level="DEBUG" includeLocation="false">
        <AppenderRef ref="File"/>
        <AppenderRef ref="Console"/>
    </AsyncLogger>

    <!-- Sync: low-frequency audit logs need immediate flush -->
    <Logger name="com.example.audit" level="INFO">
        <AppenderRef ref="File"/>
    </Logger>

    <AsyncRoot level="INFO" includeLocation="false">
        <AppenderRef ref="Console"/>
        <AppenderRef ref="File"/>
    </AsyncRoot>
</Loggers>
```

### Async Tuning (application.yml or JVM args)

```properties
# Ring buffer size — must be power of 2 (default: 262144 = 256K)
log4j2.asyncLoggerRingBufferSize=262144

# Wait strategy: Block (highest throughput, lowest latency), Timeout, Sleep, Yield
log4j2.asyncLoggerWaitStrategy=Timeout

# Queue full policy: Discard (drop DEBUG/TRACE when busy), DiscardOldest, Enqueue (blocks caller)
log4j2.asyncQueueFullPolicy=Discard

# Discard threshold — events at this level or below are dropped when queue is full
log4j2.discardThreshold=INFO
```

### Critical: includeLocation="false"

`includeLocation="false"` disables class/method/line-number in log output. Location lookup is **10x slower** in async mode because it happens on the business thread before enqueue. Production should disable it unless debugging. If you need location for a specific logger, set `includeLocation="true"` only on that logger.

When `includeLocation="false"` is set, log output omits class/method/line-number. Use parameterized logging: `log.info("userId={}", id)` — not string concatenation.

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

- **Production must use async logging** — add Disruptor dependency + enable AsyncLoggerContextSelector
- Use parameterized logging: `log.info("userId={}", id)` — not string concatenation
- Add `traceId` via ThreadContext filter for request correlation across logs
- Use JSON structured logging in production for easy parsing by ELK/Loki
- Set per-package levels: `DEBUG` for your code, `WARN` for framework code
- Never log passwords, tokens, JWT secrets, or user PII (email, phone, SSN) in exception messages or log output
- Use `log4j2-spring.xml` with `<SpringProfile>` for environment-specific config
- Always clear ThreadContext in filter's `finally` block to prevent context leaking
- Exclude `spring-boot-starter-logging` when using Log4j2 — Spring Boot defaults to Logback
- Set `log4j2.asyncQueueFullPolicy=Discard` + `log4j2.discardThreshold=INFO` — drop DEBUG/TRACE when queue is full rather than blocking business threads

## Related Skills

- `spring-boot-actuator` — log level management via Actuator endpoints
- `spring-boot-exception-handling` — exception logging patterns in global exception handler