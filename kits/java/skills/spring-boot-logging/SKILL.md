---
name: spring-boot-logging
description: "Logging with built-in structured JSON logging (Logback), Log4j2 alternative, MDC/ThreadContext correlation, async logging, and anti-patterns. Use when configuring application logging, enabling JSON output, or setting per-package log levels."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Logging

Logging configuration for Spring Boot 3.5.x — built-in structured logging with Logback (default), plus Log4j2 as an alternative.

## When to use this skill

- Enabling Spring Boot 3.5 built-in structured JSON logging (ECS, Logstash, GELF)
- Setting log levels per package or class
- Adding MDC or ThreadContext entries for request correlation
- Switching to JSON logging for production observability
- Configuring Log4j2 async logging with LMAX Disruptor
- Customizing structured logging JSON output

## Instructions

### 1. Built-in Structured Logging (Recommended)

Spring Boot 3.5 provides built-in structured logging with Logback — no framework switch needed. Set one property to enable JSON output:

```yaml
logging:
  structured:
    format:
      console: ecs        # options: ecs, logstash, gelf
      file: ecs
```

Supported formats:
- **ecs** — Elastic Common Schema (ECS) JSON format
- **logstash** — Logstash JSON format
- **gelf** — Graylog Extended Log Format

MDC key-value pairs are **automatically included** in structured output. Use the SLF4J fluent API to add inline key-value pairs:

```java
log.atInfo()
    .addKeyValue("userId", userId)
    .addKeyValue("action", "login")
    .log("User logged in");
```

Customize JSON output via properties:

```yaml
logging:
  structured:
    format:
      console: ecs
    json:
      include: timestamp,level,message,logger,traceId
      exclude: process.pid
      rename:
        process.id: procid
      add:
        corpname: mycorp
```

For custom formats, implement `StructuredLogFormatter<ILoggingEvent>` and reference it by fully qualified class name:

```java
public class MyFormat implements StructuredLogFormatter<ILoggingEvent> {
    @Override
    public String format(ILoggingEvent event) {
        return "time=" + event.getInstant()
            + " level=" + event.getLevel()
            + " message=" + event.getMessage() + "\n";
    }
}
```

Set: `logging.structured.format.console=com.example.MyFormat`

### 2. MDC Request Correlation (Logback)

With built-in structured logging, MDC entries appear automatically in JSON output. Populate them via a servlet filter:

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

The `traceId`, `requestPath`, and `method` entries appear automatically in ECS/Logstash/GELF JSON output — no custom template needed.

### 3. Per-Environment Log Levels

```yaml
# application-dev.yml
logging:
  level:
    root: DEBUG
    com.example.service: DEBUG
    org.springframework.web: DEBUG

# application-prod.yml
logging:
  level:
    root: WARN
    com.example.service: INFO
    org.springframework.web: WARN
```

### 4. Log4j2 Setup (Alternative)

Use Log4j2 only if you need specific Log4j2 features (Disruptor-based async logging, custom appenders, or mixed sync/async logger routing). For most applications, Spring Boot's built-in Logback structured logging is sufficient.

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

#### Log4j2 Configuration

Full config via `log4j2-spring.xml` (place in `src/main/resources/`):

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

#### Log4j2 JSON Structured Logging

Use `JsonTemplateLayout` for JSON output with Log4j2:

```xml
<Console name="JSON-Console" target="SYSTEM_OUT">
    <JsonTemplateLayout eventTemplateUri="classpath:JsonLayout.json"/>
</Console>
```

Place `JsonLayout.json` in `src/main/resources/`:

> `ThreadContext.put("traceId", ...)` is resolved by `{"$resolver": "mdc", "key": "traceId"}` in JsonTemplateLayout.

```json
{
  "timestamp": {"$resolver": "timestamp"},
  "level": {"$resolver": "level"},
  "logger": {"$resolver": "loggerName"},
  "message": {"$resolver": "message"},
  "thread": {"$resolver": "threadName"},
  "traceId": {"$resolver": "mdc", "key": "traceId"},
  "requestPath": {"$resolver": "mdc", "key": "requestPath"}
}
```

Use `<SpringProfile>` for environment-specific config:

```xml
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
```

#### Log4j2 ThreadContext Correlation

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
            chain.doFilter(request, response);
        } finally {
            ThreadContext.clearAll();
        }
    }
}
```

### 5. Log4j2 Async Logging

**Production deployments using Log4j2 must use async logging** to prevent I/O from blocking business threads.

Add Disruptor dependency:

```xml
<dependency>
    <groupId>com.lmax</groupId>
    <artifactId>disruptor</artifactId>
    <version>4.0</version>
    <scope>runtime</scope>
</dependency>
```

#### All-Async (Recommended)

Set system property before Spring context starts:

```java
@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        System.setProperty("log4j2.contextSelector",
            "org.apache.logging.log4j.core.async.AsyncLoggerContextSelector");
        SpringApplication.run(Application.class, args);
    }
}
```

Or JVM argument: `-Dlog4j2.contextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector`

When all-async is enabled, use regular `<Logger>` and `<Root>` — no `<AsyncLogger>` needed.

#### Mixed Async (Selective)

Use `<AsyncLogger>` for high-frequency loggers, `<Logger>` for sync ones that need immediate flush:

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

#### Async Tuning

```properties
# Ring buffer size — must be power of 2 (default: 262144 = 256K)
log4j2.asyncLoggerRingBufferSize=262144

# Wait strategy: Block (highest throughput), Timeout, Sleep, Yield
log4j2.asyncLoggerWaitStrategy=Timeout

# Queue full policy: Discard drops DEBUG/TRACE when busy
log4j2.asyncQueueFullPolicy=Discard

# Discard threshold — events at this level or below are dropped when queue is full
log4j2.discardThreshold=INFO
```

#### includeLocation="false"

`includeLocation="false"` disables class/method/line-number in log output. Location lookup is **10x slower** in async mode because it happens on the business thread before enqueue. Production should disable it unless debugging. When disabled, use parameterized logging: `log.info("userId={}", id)`.

## Constraints and Warnings

**Anti-patterns**:

- **Replacing Logback with Log4j2 just for JSON logging** — Spring Boot 3.5 provides built-in structured logging with Logback via `logging.structured.format.*`. Switching frameworks is unnecessary for most applications. Use Log4j2 only if you need specific features like Disruptor-based async logging or custom appenders.
- **String concatenation in log statements** — `log.info("userId=" + id)` creates strings even when the level is disabled. Use parameterized logging: `log.info("userId={}", id)`.
- **Logging passwords, tokens, JWT secrets, or PII** — never log credentials or personally identifiable information in exception messages or log output.
- **Setting `includeLocation="true"` on all loggers in production** — location lookup is 10x slower in async mode. Set `includeLocation="true"` only on specific debug loggers.
- **Using MDC or ThreadContext without clearing in `finally`** — context leaks to subsequent requests on the same thread. Always clear in `finally`.
- **Blocking business threads on I/O for logging** — production must use async logging (Disruptor for Log4j2, or Logback's `AsyncAppender`) to prevent log I/O from slowing request processing.
- **Logging 4xx errors at ERROR level** — client errors are expected behavior, not system failures. Use WARN for 4xx, ERROR for 5xx.

**Technical constraints**:

- **Spring Boot 3.5's built-in structured logging uses Logback only** — it does not work with Log4j2. If you switch to Log4j2, you lose `logging.structured.format.*` support and must configure JSON output manually via `JsonTemplateLayout`.
- **Log4j2 async mode requires `log4j2.contextSelector` set before Spring context starts** — setting it after `SpringApplication.run()` has no effect. Set it in `main()` before the run call, or via JVM `-D` argument.
- **`log4j2-spring.xml` uses `<SpringProfile>` while `logback-spring.xml` uses `<springProfile>`** — the element name differs between frameworks.
- **Disruptor 4.0 requires Java 11+** — compatible with Spring Boot 3.5's Java 17 minimum.

## References

- Spring Boot 3.5 Reference — Logging: https://docs.spring.io/spring-boot/3.5/reference/features/logging.html

## Related Skills

- `spring-boot-actuator` — log level management via Actuator endpoints
- `spring-boot-exception-handling` — exception logging patterns in global exception handler

## Keywords

logging, structured logging, JSON logging, ECS, Logstash, GELF, Logback, Log4j2, MDC, ThreadContext, async logging, Disruptor, traceId, request correlation, log levels, per-package levels, RollingFile, JsonTemplateLayout, structured.format, SLF4J fluent API, addKeyValue, StructuredLogFormatter