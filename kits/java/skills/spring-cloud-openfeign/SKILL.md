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

### 2. Define Feign client interface

Use `name` matching the Nacos/Eureka service ID for automatic load balancing. Use `contextId` when multiple clients target the same service. Use `fallbackFactory` (not plain `fallback`) to access exception causes:

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

// Second client targeting the same service — requires contextId to avoid bean name collision
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

### 3. Configure timeout and logger level

Set explicit timeouts per client (defaults are unbounded):

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

logging:
  level:
    com.example.order.client.UserClient: DEBUG
```

**Logger levels:** `NONE` (production), `BASIC` (prod monitoring), `HEADERS` (debugging), `FULL` (dev only — leaks sensitive data).

### 4. Configure retryer

Define a custom `Retryer` bean (YAML sub-properties are NOT supported). Only retry idempotent operations (GET) — retrying POST/PATCH creates duplicate side effects:

```java
@Configuration
public class FeignRetryConfig {
    @Bean
    public Retryer retryer() {
        return new Retryer.Default(100, 1000, 3); // 100ms initial, 1s max, 3 attempts
    }
}
```

### 5. Implement error decoder for remote exception translation

`ErrorDecoder` translates remote HTTP errors into local exceptions:

```java
@Component
@Slf4j
public class FeignErrorDecoder implements ErrorDecoder {
    private final ObjectMapper objectMapper;

    @Override
    public Exception decode(String methodKey, Response response) {
        int status = response.status();
        try {
            String body = Util.toString(response.body().asReader(StandardCharsets.UTF_8));
            Result<Void> result = objectMapper.readValue(body, new TypeReference<>() {});

            if (result != null && result.getCode() != 200) {
                return switch (status) {
                    case 400 -> new ValidationException(result.getMsg());
                    case 401 -> new UnauthorizedException(result.getMsg());
                    case 403 -> new ForbiddenException(result.getMsg());
                    case 404 -> new NotFoundException("Remote resource", methodKey);
                    case 503 -> new ServiceUnavailableException("Remote: " + methodKey);
                    default  -> new BusinessException(status * 1000, result.getMsg());
                };
            }
        } catch (IOException e) {
            log.error("Failed to parse remote error: method={}, status={}", methodKey, status, e);
        }
        return new Default().decode(methodKey, response);
    }
}
```

### 6. Add Resilience4j fallback with fallbackFactory

Use `fallbackFactory` to access exception causes. Fallback methods MUST match every method in the Feign interface:

```java
@Component
@Slf4j
public class UserClientFallbackFactory implements FallbackFactory<UserClient> {
    @Override
    public UserClient create(Throwable cause) {
        log.warn("UserClient fallback: {}", cause.getMessage());
        return new UserClient() {
            @Override
            public Result<UserDTO> getUser(Long id) {
                return Result.fail(503, "user-service unavailable");
            }
            @Override
            public Result<UserDTO> createUser(CreateUserCmd request) {
                throw new ServiceUnavailableException("user-service unavailable");
            }
            @Override
            public Result<PageResult<UserDTO>> searchUsers(String keyword, int page, int pageSize) {
                return Result.fail(503, "search temporarily disabled");
            }
        };
    }
}
```

Enable circuit breaker (requires `alphanumeric-ids` to avoid illegal characters in instance names):

```yaml
spring:
  cloud:
    openfeign:
      circuitbreaker:
        enabled: true
        alphanumeric-ids:
          enabled: true
```

### 7. Implement request interceptor for header propagation

Propagate JWT and tracing headers (`RequestContextHolder` only works in servlet apps, not WebFlux):

```java
@Component
public class FeignAuthInterceptor implements RequestInterceptor {
    @Override
    public void apply(RequestTemplate template) {
        ServletRequestAttributes attrs = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attrs != null) {
            String token = attrs.getRequest().getHeader(HttpHeaders.AUTHORIZATION);
            if (token != null) template.header(HttpHeaders.AUTHORIZATION, token);
        }
    }
}
```

### 8. Configure connection pool with Apache HttpClient 5

Use `feign-hc5` (HttpClient 4 is NOT supported in OpenFeign 4.x / Spring Boot 3.x):

```xml
<dependency>
    <groupId>io.github.openfeign</groupId>
    <artifactId>feign-hc5</artifactId>
</dependency>
```

```yaml
spring:
  cloud:
    openfeign:
      httpclient:
        hc5:
          enabled: true
        max-connections: 200
        max-connections-per-route: 50
```

**OkHttp alternative:** Use `feign-okhttp` dependency with `spring.cloud.openfeign.okhttp.enabled: true` for HTTP/2 support.

### 9. Additional patterns

**Response compression:**

```yaml
spring:
  cloud:
    openfeign:
      compression:
        response:
          enabled: true
```

**File upload:**

```java
@FeignClient(name = "storage-service")
public interface StorageClient {
    @PostMapping(value = "/v1/files/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    Result<FileResponse> uploadFile(@RequestPart("file") MultipartFile file);
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