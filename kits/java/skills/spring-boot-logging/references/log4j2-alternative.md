# Log4j2 Alternative Setup

Use Log4j2 only if you need Disruptor-based async logging, custom appenders, or mixed sync/async logger routing. For most applications, Spring Boot's built-in Logback structured logging is sufficient.

> Spring Boot 3.5's `logging.structured.format.*` does NOT work with Log4j2. Switching to Log4j2 means managing JSON output yourself via JsonTemplateLayout.

## Dependency Setup

Exclude default Logback and add Log4j2:

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

## Log4j2 Configuration

Place `log4j2-spring.xml` in `src/main/resources/`:

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

## JSON Structured Logging (JsonTemplateLayout)

Use `JsonTemplateLayout` for JSON output with Log4j2:

```xml
<Console name="JSON-Console" target="SYSTEM_OUT">
    <JsonTemplateLayout eventTemplateUri="classpath:JsonLayout.json"/>
</Console>
```

Place `JsonLayout.json` in `src/main/resources/`:

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

## ThreadContext Correlation

Log4j2 uses `ThreadContext` instead of SLF4J MDC:

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

## Async Logging (Disruptor)

Production deployments using Log4j2 should use async logging to prevent I/O from blocking business threads.

Add Disruptor dependency:

```xml
<dependency>
    <groupId>com.lmax</groupId>
    <artifactId>disruptor</artifactId>
    <version>4.0</version>
    <scope>runtime</scope>
</dependency>
```

**All-Async (Recommended):** Set system property before Spring context starts:

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

**Async Tuning:**

```properties
log4j2.asyncLoggerRingBufferSize=262144  # Must be power of 2
log4j2.asyncLoggerWaitStrategy=Timeout
log4j2.asyncQueueFullPolicy=Discard
```

**includeLocation="false":** Disables class/method/line-number in log output. Location lookup is 10x slower in async mode. Production should disable it unless debugging.
