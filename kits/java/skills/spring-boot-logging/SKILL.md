---
name: spring-boot-logging
description: "Structured JSON logging with Logback (Spring Boot 3.5 built-in), MDC request correlation, per-environment log levels, and anti-patterns."
version: "2.0.0"
type: skill
---

# Spring Boot Logging

Logging configuration for Spring Boot 3.5.x — built-in structured logging with Logback (default). For Log4j2, see `references/log4j2-alternative.md`.

## Instructions

### 1. Built-in Structured Logging

Spring Boot 3.5 provides built-in structured logging with Logback. Set one property to enable JSON output:

```yaml
logging:
  structured:
    format:
      console: ecs        # options: ecs, logstash, gelf
      file: ecs
```

Supported formats: **ecs** (Elastic Common Schema), **logstash** (Logstash JSON), **gelf** (Graylog Extended Log Format).

MDC key-value pairs are automatically included in structured output. Use the SLF4J fluent API for inline key-value pairs:

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

For custom formats, implement `StructuredLogFormatter<ILoggingEvent>`:

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

### 2. MDC Request Correlation

MDC entries appear automatically in structured JSON output. Populate them via a servlet filter:

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

The `traceId`, `requestPath`, and `method` entries appear automatically in ECS/Logstash/GELF JSON output.

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

## Constraints and Warnings

- **String concatenation in log statements** — `log.info("userId=" + id)` creates strings even when level is disabled. Use parameterized logging: `log.info("userId={}", id)`.
- **Logging passwords, tokens, JWT secrets, or PII** — never log credentials or personally identifiable information.
- **Using MDC without clearing in `finally`** — context leaks to subsequent requests on the same thread.
- **Logging 4xx errors at ERROR level** — client errors are expected behavior. Use WARN for 4xx, ERROR for 5xx.
- **Replacing Logback with Log4j2 just for JSON** — Spring Boot 3.5 provides built-in structured logging. Use Log4j2 only for Disruptor-based async or custom appenders.

## References

- Spring Boot 3.5 Reference — Logging: https://docs.spring.io/spring-boot/3.5/reference/features/logging.html
- Log4j2 alternative setup: `references/log4j2-alternative.md`

## Related Skills

- `spring-boot-actuator`
- `spring-boot-exception-handling`
