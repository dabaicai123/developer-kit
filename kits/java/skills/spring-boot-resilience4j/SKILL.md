---
name: spring-boot-resilience4j
description: "Resilience4j fault tolerance for Spring Boot 3.x: circuit breaker, retry, rate limiter, bulkhead, time limiter, and fallback implementations. Use when implementing circuit breakers, adding retry logic, configuring rate limiters, or protecting services from cascading failures."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Resilience4j Patterns

## When to use this skill

- Implementing fault tolerance and preventing cascading failures
- Adding circuit breakers, retry logic, or rate limiting to service calls
- Handling transient failures with exponential backoff
- Protecting services from overload and resource exhaustion
- Combining multiple patterns for comprehensive resilience

> **Resilience4j vs Sentinel**: Use Resilience4j for single-service or non-Alibaba-stack projects. Use Spring Cloud Alibaba Sentinel if your project already uses Nacos/Spring Cloud Alibaba — Sentinel integrates with Nacos dashboard and provides cluster-level flow control. Both provide circuit breaking and rate limiting; the choice depends on your microservice stack.

## Instructions

### 1. Setup and Dependencies

Add Resilience4j dependencies to your project. For Maven, add to `pom.xml`:

```xml
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
    <version>2.4.0</version>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

For Gradle, add to `build.gradle`:

```gradle
implementation "io.github.resilience4j:resilience4j-spring-boot3:2.4.0"
implementation "org.springframework.boot:spring-boot-starter-aop"
implementation "org.springframework.boot:spring-boot-starter-actuator"
```

### 2. Circuit Breaker Pattern

Apply `@CircuitBreaker` annotation to methods calling external services:

```java
@Service
public class PaymentService {
    private final PaymentClient paymentClient;

    public PaymentService(PaymentClient paymentClient) {
        this.paymentClient = paymentClient;
    }

    @CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
    public PaymentResponse processPayment(PaymentRequest request) {
        return paymentClient.processPayment(request);
    }

    private PaymentResponse paymentFallback(PaymentRequest request, Exception ex) {
        return PaymentResponse.builder()
            .status("PENDING")
            .message("Service temporarily unavailable")
            .build();
    }
}
```

Configure in `application.yml`:

```yaml
resilience4j:
  circuitbreaker:
    configs:
      default:
        registerHealthIndicator: true
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
        failureRateThreshold: 50
        waitDurationInOpenState: 10s
    instances:
      paymentService:
        baseConfig: default
```

See references/configuration-reference.md for complete circuit breaker configuration options.

### 3. Retry Pattern

Apply `@Retry` annotation for transient failure recovery:

```java
@Service
public class ProductService {
    private final ProductClient productClient;

    public ProductService(ProductClient productClient) {
        this.productClient = productClient;
    }

    @Retry(name = "productService", fallbackMethod = "getProductFallback")
    public Product getProduct(Long productId) {
        return productClient.getProduct(productId);
    }

    private Product getProductFallback(Long productId, Exception ex) {
        return Product.builder()
            .id(productId)
            .name("Unavailable")
            .available(false)
            .build();
    }
}
```

Configure retry in `application.yml`:

```yaml
resilience4j:
  retry:
    configs:
      default:
        maxAttempts: 3
        waitDuration: 500ms
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2
    instances:
      productService:
        baseConfig: default
        maxAttempts: 5
```

See references/configuration-reference.md for retry exception configuration.

### 4. Rate Limiter Pattern

Apply `@RateLimiter` to control request rates:

```java
@Service
public class NotificationService {
    private final EmailClient emailClient;

    public NotificationService(EmailClient emailClient) {
        this.emailClient = emailClient;
    }

    @RateLimiter(name = "notificationService",
        fallbackMethod = "rateLimitFallback")
    public void sendEmail(EmailRequest request) {
        emailClient.send(request);
    }

    private void rateLimitFallback(EmailRequest request, Exception ex) {
        throw new RateLimitExceededException(
            "Too many requests. Please try again later.");
    }
}
```

Configure in `application.yml`:

```yaml
resilience4j:
  ratelimiter:
    configs:
      default:
        registerHealthIndicator: true
        limitForPeriod: 10
        limitRefreshPeriod: 1s
        timeoutDuration: 500ms
    instances:
      notificationService:
        baseConfig: default
        limitForPeriod: 5
```

### 5. Bulkhead Pattern

Apply `@Bulkhead` to isolate resources. Use `type = SEMAPHORE` for synchronous methods:

```java
@Service
public class ReportService {
    private final ReportGenerator reportGenerator;

    public ReportService(ReportGenerator reportGenerator) {
        this.reportGenerator = reportGenerator;
    }

    @Bulkhead(name = "reportService", type = Bulkhead.Type.SEMAPHORE)
    public Report generateReport(ReportRequest request) {
        return reportGenerator.generate(request);
    }
}
```

Use `type = THREADPOOL` for async/CompletableFuture methods:

```java
@Service
public class AnalyticsService {
    @Bulkhead(name = "analyticsService", type = Bulkhead.Type.THREADPOOL)
    public CompletableFuture<AnalyticsResult> runAnalytics(
            AnalyticsRequest request) {
        return CompletableFuture.supplyAsync(() ->
            analyticsEngine.analyze(request));
    }
}
```

Configure in `application.yml`:

```yaml
resilience4j:
  bulkhead:
    configs:
      default:
        maxConcurrentCalls: 10
        maxWaitDuration: 100ms
    instances:
      reportService:
        baseConfig: default
        maxConcurrentCalls: 5

  thread-pool-bulkhead:
    instances:
      analyticsService:
        maxThreadPoolSize: 8
```

### 6. Time Limiter Pattern

Apply `@TimeLimiter` to async methods to enforce timeout boundaries:

```java
@Service
public class SearchService {
    @TimeLimiter(name = "searchService", fallbackMethod = "searchFallback")
    public CompletableFuture<SearchResults> search(SearchQuery query) {
        return CompletableFuture.supplyAsync(() ->
            searchEngine.executeSearch(query));
    }

    private CompletableFuture<SearchResults> searchFallback(
            SearchQuery query, Exception ex) {
        return CompletableFuture.completedFuture(
            SearchResults.empty("Search timed out"));
    }
}
```

Configure in `application.yml`:

```yaml
resilience4j:
  timelimiter:
    configs:
      default:
        timeoutDuration: 2s
        cancelRunningFuture: true
    instances:
      searchService:
        baseConfig: default
        timeoutDuration: 3s
```

### 7. Combining Multiple Patterns

Stack multiple patterns on a single method for comprehensive fault tolerance:

```java
@Service
public class OrderService {
    @CircuitBreaker(name = "orderService")
    @Retry(name = "orderService")
    @RateLimiter(name = "orderService")
    @Bulkhead(name = "orderService")
    public Order createOrder(OrderRequest request) {
        return orderClient.createOrder(request);
    }
}
```

Execution order: Retry → CircuitBreaker → RateLimiter → Bulkhead → Method

All patterns should reference the same named configuration instance for consistency.

### 8. Exception Handling and Monitoring

Create a global exception handler using `@RestControllerAdvice`:

```java
@RestControllerAdvice
public class ResilienceExceptionHandler {

    @ExceptionHandler(CallNotPermittedException.class)
    public Result<Void> handleCircuitOpen(CallNotPermittedException ex) {
        return Result.fail(503, "Service currently unavailable");
    }

    @ExceptionHandler(RequestNotPermitted.class)
    public Result<Void> handleRateLimited(RequestNotPermitted ex) {
        return Result.fail(429, "Rate limit exceeded");
    }

    @ExceptionHandler(BulkheadFullException.class)
    public Result<Void> handleBulkheadFull(BulkheadFullException ex) {
        return Result.fail(503, "Service at capacity");
    }
}
```

Enable Actuator endpoints for monitoring resilience patterns in `application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,metrics,circuitbreakers,retries,ratelimiters
  endpoint:
    health:
      show-details: always
  health:
    circuitbreakers:
      enabled: true
    ratelimiters:
      enabled: true
```

Access monitoring endpoints:
- `GET /actuator/health` - Overall health including resilience patterns
- `GET /actuator/circuitbreakers` - Circuit breaker states
- `GET /actuator/metrics` - Custom resilience metrics

### Testing & Verification

Verify each pattern via Actuator: `/actuator/circuitbreakers` (state transitions), `/actuator/ratelimiters` (limited counts), `/actuator/metrics` (retry counts). For test strategies, see `references/testing-patterns.md`.

## Best Practices

- **Retry only transient errors** (5xx, timeouts; skip 4xx and business exceptions)
- **Size bulkheads based on expected concurrency**

## Constraints and Warnings

- Fallback methods must have the same signature plus an optional exception parameter
- Circuit breaker state is per-instance; ensure proper bean scoping in multi-tenant scenarios
- Retry operations must be idempotent (may execute multiple times)
- Do not use circuit breakers for operations that must always complete; use timeouts instead
- Rate limiters can cause thread blocking; configure appropriate wait durations
- Be cautious with `@Retry` on non-idempotent operations like POST requests
- Monitor memory when using thread pool bulkheads with high concurrency

## Related Skills

- `spring-cloud-openfeign` — Feign client resilience integration, retry and circuit breaker configuration
- `spring-boot-actuator` — Resilience4j health indicators and metrics endpoints
- `spring-boot-exception-handling` — CallNotPermittedException, RequestNotPermitted exception handling

## References

- [Configuration Reference](references/configuration-reference.md)
- [Testing Patterns](references/testing-patterns.md)
- [Examples](references/examples.md)
- [Resilience4j Docs](https://resilience4j.readme.io/)
