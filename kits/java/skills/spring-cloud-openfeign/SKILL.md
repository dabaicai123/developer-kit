---
name: spring-cloud-openfeign
description: "Spring Cloud OpenFeign: Feign client definition, timeout/retry, error decoder, Resilience4j fallback, interceptors, and connection pool tuning. Use when making service-to-service HTTP calls in microservices."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Cloud OpenFeign

## When to use this skill

- Making service-to-service HTTP calls in microservices
- Replacing `RestTemplate` / `WebClient` with declarative Feign clients
- Configuring Feign timeout, retry, and logger levels per client
- Implementing error decoder patterns for remote exception translation
- Adding Resilience4j circuit breaker and fallback to Feign clients
- Propagating JWT tokens and tracing headers via request interceptors
- Tuning connection pools with Apache HttpClient 5 or OkHttp
- Supporting pagination, file upload, and multipart requests via Feign

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

BOM for Spring Cloud + OpenFeign version alignment:

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

NOT: Do NOT add `@EnableDiscoveryClient` — service discovery auto-configures in Spring Boot 3.x.

### 2. Define Feign client interface

Use `name` matching the Nacos/Eureka service ID for automatic load balancing. Use `contextId` when multiple clients target the same service:

```java
@FeignClient(
    name = "user-service",
    fallbackFactory = UserClientFallbackFactory.class
)
public interface UserClient {

    @GetMapping("/v1/users/{id}")
    Result<UserDTO> getUser(@PathVariable("id") Long id);

    @PostMapping("/v1/users")
    Result<UserDTO> createUser(@RequestBody CreateUserCmd request);

    @GetMapping("/v1/users")
    Result<PageResult<UserDTO>> searchUsers(
        @RequestParam("keyword") String keyword,
        @RequestParam("page") int page,
        @RequestParam("pageSize") int pageSize
    );
}

// Second client targeting the same user-service — requires contextId to avoid bean name collision
@FeignClient(
    name = "user-service",
    contextId = "userAdminClient",
    path = "/v1/admin/users"
)
public interface UserAdminClient {

    @DeleteMapping("/{id}")
    Result<Void> deleteUser(@PathVariable("id") Long id);

    @PutMapping("/{id}/status")
    Result<Void> updateStatus(@PathVariable("id") Long id,
                              @RequestBody UpdateStatusRequest request);
}
```

NOT: Use `fallbackFactory`, NOT plain `fallback` — plain fallback hides the exception cause, making debugging impossible.

### 3. Configure timeout and logger level

Set explicit timeouts per client. Default timeouts are unbounded — never rely on defaults:

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connectTimeout: 3000
            readTimeout: 5000
            loggerLevel: BASIC
          user-service:
            connectTimeout: 1000
            readTimeout: 3000
            loggerLevel: FULL
          payment-service:
            connectTimeout: 5000
            readTimeout: 10000
```

**Logger levels:**

| Level | What is logged | Use when |
|---|---|---|
| `NONE` | Nothing | Production (default) |
| `BASIC` | Request method, URL, response status | Production monitoring |
| `HEADERS` | BASIC + request/response headers | Debugging |
| `FULL` | Headers, body, metadata | Development only |

Enable Feign logging by setting the client logger to DEBUG:

```yaml
logging:
  level:
    com.example.order.client.UserClient: DEBUG
```

NOT: Logger level `FULL` in production — large output degrades performance and leaks sensitive data in headers/body.

### 4. Configure retryer

Define a custom `Retryer` bean for retry logic — YAML sub-properties (`period/maxPeriod/maxAttempts`) are NOT supported:

```java
@Configuration
public class FeignRetryConfig {

    @Bean
    public Retryer retryer() {
        // Retry with 100ms initial interval, 1s max interval, 3 max attempts
        return new Retryer.Default(100, 1000, 3);
    }
}
```

Per-client retryer via YAML:

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          payment-service:
            retryer: com.example.order.client.FeignRetryConfig
```

NOT: Do NOT configure retry on non-idempotent operations (POST, PATCH) — retrying creates duplicate side effects. Apply retry only to GET or idempotent endpoints.

### 5. Implement error decoder for remote exception translation

`ErrorDecoder` translates remote HTTP errors into local exceptions. Without it, Feign throws generic `FeignException` with no business context:

```java
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
            String body = Util.toString(response.body().asReader(StandardCharsets.UTF_8));
            Result<Void> result = objectMapper.readValue(body, new TypeReference<Result<Void>>() {});

            if (result != null && result.getCode() != 200) {
                log.warn("Remote service error: method={}, status={}, code={}, msg={}",
                    methodKey, status, result.getCode(), result.getMsg());

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

        return new Default().decode(methodKey, response);
    }
}
```

Register globally or per-client:

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            errorDecoder: com.example.order.client.FeignErrorDecoder
```

NOT: Do NOT swallow remote errors silently — always translate to a specific local exception or fall through to `Default().decode()`.

### 6. Add Resilience4j fallback with fallbackFactory

Use `fallbackFactory` to access the exception cause for logging:

```java
@Component
@Slf4j
public class UserClientFallbackFactory implements FallbackFactory<UserClient> {

    @Override
    public UserClient create(Throwable cause) {
        log.warn("UserClient fallback triggered: {}", cause.getMessage());

        return new UserClient() {
            @Override
            public Result<UserDTO> getUser(Long id) {
                return Result.fail(503, "user-service unavailable, user lookup failed for id: " + id);
            }

            @Override
            public Result<UserDTO> createUser(CreateUserCmd request) {
                throw new ServiceUnavailableException("user-service unavailable, cannot create user");
            }

            @Override
            public Result<PageResult<UserDTO>> searchUsers(String keyword, int page, int pageSize) {
                return Result.fail(503, "user-service unavailable, search temporarily disabled");
            }
        };
    }
}
```

Enable Resilience4j circuit breaker for Feign:

```yaml
spring:
  cloud:
    openfeign:
      circuitbreaker:
        enabled: true
        alphanumeric-ids:
          enabled: true
```

NOT: Do NOT skip `alphanumeric-ids.enabled: true` — without it, circuit breaker instance names contain illegal characters (e.g., `#`) that break Resilience4j configuration.

NOT: Fallback methods MUST match every method in the Feign interface — missing methods cause runtime errors.

For circuit breaker configuration (sliding window, failure rate, wait duration), see `spring-boot-resilience4j`.

### 7. Implement request interceptor for header propagation

Propagate JWT and tracing headers across service boundaries:

```java
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
```

NOT: `RequestContextHolder` only works in servlet (non-reactive) applications — it returns `null` in WebFlux. For reactive, use custom header propagation via `WebClient` exchange context.

### 8. Configure connection pool with Apache HttpClient 5

Spring Cloud OpenFeign 4.x (Spring Boot 3.x) dropped Apache HttpClient 4 support. Use `feign-hc5` for HttpClient 5:

```xml
<dependency>
    <groupId>io.github.openfeign</groupId>
    <artifactId>feign-hc5</artifactId>
</dependency>
```

NOT: Do NOT use `feign-httpclient` — Apache HttpClient 4 is NOT supported in OpenFeign 4.x / Spring Boot 3.x. Use `feign-hc5` instead.

```yaml
spring:
  cloud:
    openfeign:
      httpclient:
        hc5:
          enabled: true
        max-connections: 200
        max-connections-per-route: 50
        connection-timeout: 3000
        follow-redirects: true
        disable-ssl-validation: false
```

NOT: Do NOT pin `feign-hc5` version explicitly — Spring Cloud BOM manages the version.

**OkHttp alternative:** Use `io.github.openfeign:feign-okhttp` dependency and set `spring.cloud.openfeign.okhttp.enabled: true` for HTTP/2 support.

### 9. Enable response compression

For large response payloads, enable GZIP compression:

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

### 10. Pagination support

Feign clients can return `PageResult<T>` for paginated remote endpoints:

```java
@FeignClient(name = "user-service", fallbackFactory = UserClientFallbackFactory.class)
public interface UserClient {

    @GetMapping("/v1/users")
    Result<PageResult<UserDTO>> searchUsers(
        @RequestParam("keyword") String keyword,
        @RequestParam("page") int page,
        @RequestParam("pageSize") int pageSize
    );
}
```

NOT: If remote and local `Result` classes differ in structure, do NOT use the same `Result<T>` type — create a separate `RemoteResult<T>` DTO for Feign responses.

### 11. File upload and multipart requests

Use `MultipartFile` with `@RequestPart` for file uploads:

```java
@FeignClient(name = "storage-service", fallbackFactory = StorageClientFallbackFactory.class)
public interface StorageClient {

    @PostMapping(value = "/v1/files/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    Result<FileResponse> uploadFile(
        @RequestPart("file") MultipartFile file,
        @RequestPart("metadata") FileMetadata metadata
    );
}
```

Add multipart encoder configuration:

```java
@Configuration
public class FeignMultipartConfig {

    @Bean
    public SpringFormEncoder springFormEncoder(ObjectMapper objectMapper) {
        return new SpringFormEncoder(new SpringEncoder(new SpringFormEncoder(), objectMapper));
    }
}
```

## Constraints and Warnings

- No timeout config — unbounded timeouts hang indefinitely; always set `connectTimeout` and `readTimeout`.
- No ErrorDecoder — Feign throws generic `FeignException` with no business context.
- Hardcoded URLs bypassing service discovery — defeats load balancing; always use `name` to resolve via Nacos/Eureka.
- Feign for async/streaming calls — Feign is strictly request-response; use `WebClient` for streaming, Kafka for async.
- Circuit breaker wraps the entire Feign client — all methods share one circuit; you cannot selectively fallback on some methods.
- Connection pool exhaustion — if `max-connections` is too low, requests timeout waiting for connections. Monitor via Actuator.
- `@FeignClient` does NOT support WebSocket or SSE.
- Jackson serialization must be compatible between producer and consumer — custom `ObjectMapper` configurations (date format, null handling) must be aligned across services.

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