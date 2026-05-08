---
name: spring-cloud-openfeign
description: "Spring Cloud OpenFeign for Spring Boot 3.5.x: Feign client definition, timeout/retry, error decoder, Resilience4j fallback, interceptors, and connection pool tuning. Use when making service-to-service HTTP calls in microservices."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Cloud OpenFeign

Declarative HTTP client for Spring Boot 3.5.x microservices — configuration, timeout/retry, error decoder, Resilience4j fallback, interceptors, connection pool tuning, pagination, file upload, and anti-patterns.

## When to use this skill

- Making service-to-service HTTP calls in microservices
- Replacing `RestTemplate` / `WebClient` with declarative Feign clients
- Configuring Feign timeout, retry, and logger levels per client
- Implementing error decoder patterns for remote exception translation
- Adding Resilience4j circuit breaker and fallback to Feign clients
- Propagating JWT tokens and tracing headers via request interceptors
- Tuning connection pools with Apache HttpClient or OkHttp
- Supporting pagination, file upload, and multipart requests via Feign

## Overview

Spring Cloud OpenFeign provides a declarative HTTP client that generates implementations from interfaces and annotations. Feign integrates with Spring Cloud service discovery (Nacos/Eureka) for load balancing and Resilience4j for fault tolerance.

| Concept | Description |
|---|---|
| **Feign Client** | Interface annotated with `@FeignClient` — Spring generates the implementation |
| **Service Discovery** | `name` attribute maps to Nacos/Eureka service ID for load balancing |
| **Error Decoder** | Translates remote HTTP error responses into local exceptions |
| **Fallback** | Resilience4j circuit breaker fallback when the remote service is unavailable |
| **Interceptor** | `RequestInterceptor` to propagate headers (JWT, tracing) |
| **Connection Pool** | Apache HttpClient or OkHttp for connection pooling and tuning |

## Instructions

### 1. Add dependencies and enable Feign

```xml
<!-- OpenFeign core -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>

<!-- Load balancer (required for service discovery-based routing) -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-loadbalancer</artifactId>
</dependency>

<!-- Resilience4j for circuit breaker fallback (optional but recommended) -->
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
</dependency>
```

BOM for Spring Cloud Alibaba + OpenFeign version alignment:

```xml
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
```

Enable Feign clients on the main application class:

```java
@SpringBootApplication
@EnableFeignClients
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
```

### 2. Define Feign client interface

Use `name` matching the Nacos/Eureka service ID for automatic load balancing. Use `contextId` when multiple clients target the same service:

```java
/**
 * Feign client for user-service.
 * <p>name = Nacos service ID, enables load-balanced routing.</p>
 */
@FeignClient(
    name = "user-service",
    fallbackFactory = UserClientFallbackFactory.class
)
public interface UserClient {

    @GetMapping("/api/v1/users/{id}")
    Result<UserResponse> getUser(@PathVariable("id") Long id);

    @PostMapping("/api/v1/users")
    Result<UserResponse> createUser(@RequestBody CreateUserRequest request);

    @GetMapping("/api/v1/users")
    Result<PageResult<UserResponse>> searchUsers(
        @RequestParam("keyword") String keyword,
        @RequestParam("page") int page,
        @RequestParam("pageSize") int pageSize
    );
}

/**
 * Second client targeting the same user-service — requires contextId
 * to avoid bean name collision.
 */
@FeignClient(
    name = "user-service",
    contextId = "userAdminClient",
    path = "/api/v1/admin/users"
)
public interface UserAdminClient {

    @DeleteMapping("/{id}")
    Result<Void> deleteUser(@PathVariable("id") Long id);

    @PutMapping("/{id}/status")
    Result<Void> updateStatus(@PathVariable("id") Long id,
                              @RequestBody UpdateStatusRequest request);
}
```

### 3. Configure timeout, retry, and logger level

Configure per-client settings for timeout, retry, and logging. Always set explicit timeouts — never rely on defaults:

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connect-timeout: 3000    # 3 seconds to establish connection
            read-timeout: 5000       # 5 seconds to wait for response
            logger-level: BASIC      # Log request method + URL + response status
          user-service:
            connect-timeout: 1000    # Tighter timeout for fast internal services
            read-timeout: 3000
            logger-level: FULL       # Log headers, body, metadata for debugging
          payment-service:
            connect-timeout: 5000    # Longer timeout for payment processing
            read-timeout: 10000
            retryer:
              period: 100            # Initial retry interval (ms)
              max-period: 1000       # Max retry interval (ms)
              max-attempts: 3        # Max retry attempts
```

**Logger levels:**

| Level | What is logged | Use when |
|---|---|---|
| `NONE` | Nothing | Production (default) |
| `BASIC` | Request method, URL, response status | Production monitoring |
| `HEADERS` | BASIC + request/response headers | Debugging |
| `FULL` | Headers, body, metadata | Development only (large output) |

Enable Feign logging by setting the client logger to DEBUG in application logging configuration:

```yaml
logging:
  level:
    com.example.order.client.UserClient: DEBUG
```

### 4. Implement error decoder for remote exception translation

`ErrorDecoder` translates remote HTTP error responses into local exceptions. Without it, Feign throws generic `FeignException` with no business context:

```java
/**
 * Custom ErrorDecoder — translates remote error responses into BusinessException.
 * <p>Ensures remote service errors are handled with the same exception hierarchy
 * as local errors, so the global @RestControllerAdvice handles them uniformly.</p>
 */
@Component
@Slf4j
public class FeignErrorDecoder implements ErrorDecoder {

    private final ObjectMapper objectMapper;

    public FeignErrorDecoder(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public Exception decode(String methodKey, Response response) {
        int status = response.status();

        try {
            // Parse remote Result<Void> error response body
            String body = Util.toString(response.body().asReader(StandardCharsets.UTF_8));
            Result<Void> result = objectMapper.readValue(body, new TypeReference<Result<Void>>() {});

            if (result != null && result.getCode() != 200) {
                log.warn("Remote service error: method={}, status={}, code={}, msg={}",
                    methodKey, status, result.getCode(), result.getMsg());

                // Map remote error to local BusinessException
                return switch (status) {
                    case 400 -> new ValidationException(result.getMsg());
                    case 401 -> new UnauthorizedException(result.getMsg());
                    case 403 -> new ForbiddenException(result.getMsg());
                    case 404 -> new NotFoundException("Remote resource", methodKey);
                    case 409 -> new ConflictException(result.getMsg());
                    case 503 -> new ServiceUnavailableException("Remote: " + methodKey);
                    default  -> new BusinessException(status * 1000, result.getMsg());
                };
            }
        } catch (IOException e) {
            log.error("Failed to parse remote error response: method={}, status={}",
                methodKey, status, e);
        }

        // Fallback to default FeignException if response body cannot be parsed
        return new Default().decode(methodKey, response);
    }
}
```

Register the custom error decoder globally or per-client:

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            error-decoder: com.example.order.client.FeignErrorDecoder
```

### 5. Add Resilience4j fallback with fallbackFactory

Combine Feign with Resilience4j circuit breaker for fault tolerance. Use `fallbackFactory` (not plain `fallback`) to access the exception cause for logging:

```java
/**
 * FallbackFactory — provides the exception that triggered the fallback.
 * <p>More useful than plain fallback because you can log and handle the root cause.</p>
 */
@Component
@Slf4j
public class UserClientFallbackFactory implements FallbackFactory<UserClient> {

    @Override
    public UserClient create(Throwable cause) {
        log.warn("UserClient fallback triggered: {}", cause.getMessage());

        return new UserClient() {
            @Override
            public Result<UserResponse> getUser(Long id) {
                // Graceful degradation — return cached/default value
                return Result.fail(503, "user-service unavailable, user lookup failed for id: " + id);
            }

            @Override
            public Result<UserResponse> createUser(CreateUserRequest request) {
                // Critical operation — throw to propagate failure
                throw new ServiceUnavailableException("user-service unavailable, cannot create user");
            }

            @Override
            public Result<PageResult<UserResponse>> searchUsers(String keyword, int page, int pageSize) {
                // Degraded search — return empty page
                return Result.fail(503, "user-service unavailable, search temporarily disabled");
            }
        };
    }
}
```

Enable Resilience4j circuit breaker for Feign and reference the resilience4j skill for full configuration:

```yaml
spring:
  cloud:
    openfeign:
      circuitbreaker:
        enabled: true
```

For circuit breaker configuration (sliding window, failure rate, wait duration, etc.), see `spring-boot-resilience4j`. OpenFeign integrates with Resilience4j via `resilience4j-spring-boot3` dependency.

### 6. Implement request/response interceptors

Use `RequestInterceptor` to propagate headers (JWT, tracing) across service boundaries:

```java
/**
 * JWT propagation interceptor — forwards Authorization header from
 * the incoming request to all outgoing Feign calls.
 */
@Component
public class FeignAuthInterceptor implements RequestInterceptor {

    @Override
    public void apply(RequestTemplate template) {
        ServletRequestAttributes attrs =
            (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attrs != null) {
            String token = attrs.getRequest().getHeader(HttpHeaders.AUTHORIZATION);
            if (token != null) {
                template.header(HttpHeaders.AUTHORIZATION, token);
            }
        }
    }
}

/**
 * Tracing propagation interceptor — forwards distributed tracing headers
 * (X-Request-Id, X-B3-TraceId) for observability across services.
 */
@Component
public class FeignTracingInterceptor implements RequestInterceptor {

    @Override
    public void apply(RequestTemplate template) {
        ServletRequestAttributes attrs =
            (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attrs != null) {
            String requestId = attrs.getRequest().getHeader("X-Request-Id");
            if (requestId != null) {
                template.header("X-Request-Id", requestId);
            }
            String traceId = attrs.getRequest().getHeader("X-B3-TraceId");
            if (traceId != null) {
                template.header("X-B3-TraceId", traceId);
            }
        }
    }
}
```

### 7. Configure connection pool tuning

By default, Feign uses `java.net.HttpURLConnection` with **no connection pooling** — every request creates a new connection. For production, configure Apache HttpClient or OkHttp for connection reuse:

**Apache HttpClient (recommended for most cases):**

```xml
<dependency>
    <groupId>io.github.openfeign</groupId>
    <artifactId>feign-httpclient</artifactId>
    <version>13.5</version>
</dependency>
```

```yaml
spring:
  cloud:
    openfeign:
      httpclient:
        enabled: true
        max-connections: 200          # Total connection pool size
        max-connections-per-route: 50 # Max connections per target host
        connection-timeout: 3000      # Connection acquire timeout (ms)
        follow-redirects: true
        disable-ssl-validation: false
```

**OkHttp alternative:** Use `io.github.openfeign:feign-okhttp:13.5` dependency and set `spring.cloud.openfeign.okhttp.enabled: true` for HTTP/2 support and lower latency. Connection pool parameters (`max-connections`, `max-connections-per-route`, `connection-timeout`) apply the same way.

**Connection pool sizing guidelines:**

| Parameter | Recommended Value | Calculation |
|---|---|---|
| `max-connections` | 200 | Total concurrent Feign calls across all services |
| `max-connections-per-route` | 50 | Peak concurrent calls to a single target service |
| `connection-timeout` | 3000 ms | Same as `connect-timeout` in Feign config |
| `read-timeout` | 5000 ms | Same as `read-timeout` in Feign config |

The pool size must accommodate peak concurrency. Monitor connection pool metrics via Actuator to detect exhaustion.

### 8. Enable response compression

For large response payloads, enable GZIP compression to reduce network transfer:

```yaml
spring:
  cloud:
    openfeign:
      compression:
        request:
          enabled: true
          mime-types: text/xml,application/xml,application/json
          min-request-size: 2048
        response:
          enabled: true
```

### 9. Pagination support

Feign clients can return `PageResult<T>` for paginated remote endpoints:

```java
@FeignClient(name = "user-service", fallbackFactory = UserClientFallbackFactory.class)
public interface UserClient {

    @GetMapping("/api/v1/users")
    Result<PageResult<UserResponse>> searchUsers(
        @RequestParam("keyword") String keyword,
        @RequestParam("page") int page,
        @RequestParam("pageSize") int pageSize
    );
}
```

The `Result<PageResult<UserResponse>>` response must match the remote service's `Result` structure exactly. If remote and local `Result` classes differ, use a separate `RemoteResult<T>` DTO for Feign responses.

### 10. File upload and multipart requests

For file uploads, use Spring's `MultipartFile` with `@RequestPart`:

```java
@FeignClient(name = "storage-service", fallbackFactory = StorageClientFallbackFactory.class)
public interface StorageClient {

    @PostMapping(value = "/api/v1/files/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    Result<FileResponse> uploadFile(
        @RequestPart("file") MultipartFile file,
        @RequestPart("metadata") FileMetadata metadata
    );
}
```

Ensure the Feign configuration includes a multipart encoder:

```java
@Configuration
public class FeignMultipartConfig {

    @Bean
    public SpringFormEncoder springFormEncoder(ObjectMapper objectMapper) {
        return new SpringFormEncoder(new SpringEncoder(new SpringFormEncoder(), objectMapper));
    }
}
```

## Best Practices

- **Always define fallbacks with `fallbackFactory`** — `fallbackFactory` provides the exception cause for logging; plain `fallback` does not
- **Use `name` matching Nacos service ID** — enables automatic load-balanced routing via Spring Cloud LoadBalancer
- **Set explicit timeouts per client** — never rely on defaults; fast internal services need shorter timeouts, payment/external services need longer
- **Implement `ErrorDecoder`** — translate remote error responses into local `BusinessException` subclasses so the global handler processes them uniformly
- **Propagate JWT via `RequestInterceptor`** — never hardcode tokens; forward the incoming request's Authorization header
- **Use `@FeignClient(contextId = "...")` for multiple clients targeting the same service** — prevents bean name collision
- **Configure connection pooling** — never use default `HttpURLConnection` (no pooling); choose Apache HttpClient or OkHttp for production
- **Log at `BASIC` level in production** — `FULL` logging produces large output and should only be used in development
- **Return `Result<T>` from Feign methods** — matches the local unified response contract; use `RemoteResult<T>` if remote and local Result differ
- **Graceful degradation for reads, throw for writes** — fallbacks for read operations return cached/empty data; fallbacks for critical writes throw to propagate the failure

## Anti-patterns

- **No timeout configuration** — relying on Feign's default (no timeout in older versions, 60 seconds in newer) causes long-hanging requests that consume connection pool threads. Always set explicit `connect-timeout` and `read-timeout`.
- **Feign for @Async service-to-service calls** — when the caller does not need the response immediately, use async messaging (Kafka/RocketMQ) instead of synchronous Feign. Feign blocks the calling thread; async messaging frees it.
- **Plain `fallback` instead of `fallbackFactory`** — plain fallback receives no exception information, making it impossible to log or handle the root cause. Always use `fallbackFactory`.
- **No ErrorDecoder** — without a custom error decoder, Feign throws `FeignException` with no business context. The global handler cannot produce meaningful error responses from `FeignException`.
- **RestTemplate mixed with Feign** — using both `RestTemplate` and `FeignClient` for service-to-service calls creates inconsistency. Choose one approach and use it consistently.
- **Feign for internal long-polling or streaming** — Feign is designed for request-response calls. Use `WebClient` for streaming, long-polling, or SSE connections.
- **Hardcoded URLs in `@FeignClient(url = "...")` in production** — this bypasses service discovery and load balancing. Use `url` only for testing or external third-party APIs.
- **Missing `contextId` for multiple clients targeting the same service** — causes bean name collision and Spring context failure.
- **Large file downloads via Feign** — Feign buffers the entire response in memory. For large files, use `RestTemplate` with streaming or direct HTTP client.

## Constraints and Warnings

- **RequestContextHolder only works in servlet-based (non-reactive) applications** — `RequestInterceptor` that reads from `RequestContextHolder` fails in WebFlux/reactive applications. For reactive, use custom header propagation via WebClient.
- **Fallback methods must match the Feign interface signature** — the anonymous class in `fallbackFactory.create()` must implement every method in the Feign interface. Missing methods cause runtime errors.
- **Circuit breaker fallback wraps the entire Feign call** — when the circuit is open, ALL methods on that Feign client return fallback values. You cannot selectively fallback on some methods.
- **Feign retry must be idempotent** — retrying non-idempotent operations (POST, PATCH) may cause duplicate side effects. Configure `retryer` only on GET operations or ensure the target endpoint is idempotent.
- **Connection pool exhaustion** — if `max-connections` is too low for peak concurrency, requests wait for available connections and may timeout. Monitor pool metrics via Actuator.
- **@FeignClient does not support WebSocket or SSE** — Feign is strictly request-response. Use `WebClient` for streaming protocols.
- **Feign serialization uses Jackson by default** — the `ObjectMapper` must be compatible between producer and consumer. Custom ObjectMapper configurations (date format, null handling) must be aligned across services.

## References

- Spring Cloud OpenFeign documentation: https://docs.spring.io/spring-cloud-openfeign/reference/
- OpenFeign GitHub: https://github.com/OpenFeign/feign
- `spring-boot-resilience4j` — circuit breaker, retry, and fallback patterns
- `spring-boot-exception-handling` — BusinessException hierarchy used by ErrorDecoder

## Related Skills

- `spring-boot-resilience4j` — circuit breaker, retry, and fallback patterns for Feign clients
- `spring-cloud-alibaba` — Nacos service discovery for Feign load balancing, Seata distributed transactions
- `spring-cloud-gateway` — API gateway routing before Feign calls reach downstream services
- `spring-boot-exception-handling` — global handler catches BusinessException from ErrorDecoder
- `spring-boot-transaction-management` — Outbox pattern and Saga choreography with inter-service Feign calls
- `spring-boot-async-processing` — async alternatives to synchronous Feign calls
- `ddd-event-driven` — event-driven communication as alternative to synchronous Feign for cross-service data

## Keywords

OpenFeign, Feign client, @FeignClient, error decoder, fallback, fallbackFactory, Resilience4j, circuit breaker, request interceptor, connection pool, Apache HttpClient, OkHttp, timeout, retry, JWT propagation, multipart, file upload, pagination, service discovery, Nacos, load balancing, anti-patterns