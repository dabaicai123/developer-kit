---
name: spring-boot-resilience4j
description: "Resilience4j fault tolerance: circuit breaker, retry, rate limiter, bulkhead, time limiter, and fallback. Use when adding circuit breakers, retry logic, rate limiting, or protecting services from cascading failures."
version: "1.2.0"
---

# Spring Boot Resilience4j Patterns

## When to use this skill

- Implementing fault tolerance and preventing cascading failures
- Adding circuit breakers, retry logic, or rate limiting to service calls
- Handling transient failures with exponential backoff
- Protecting services from overload and resource exhaustion
- Combining multiple resilience patterns on a single method

> **Resilience4j vs Sentinel**: Use Resilience4j for single-service or non-Alibaba-stack projects. Use Spring Cloud Alibaba Sentinel if your project already uses Nacos/Spring Cloud Alibaba — Sentinel integrates with Nacos dashboard and provides cluster-level flow control.

## Instructions

### 1. Setup and Dependencies

Add to `pom.xml`:

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

### 2. Aspect Order Configuration (Spring Boot 3)

**Configure aspect order explicitly** — the Spring Boot 3 default places Retry outside CircuitBreaker, causing each retry attempt to be counted as a separate failure. This inflates CircuitBreaker failure rates and triggers premature circuit opening.

```yaml
resilience4j:
  circuitbreaker:
    circuitBreakerAspectOrder: 1
  retry:
    retryAspectOrder: 2
  ratelimiter:
    rateLimiterAspectOrder: 3
  timelimiter:
    timeLimiterAspectOrder: 4
  bulkhead:
    bulkheadAspectOrder: 5
```

Default execution order (outer → inner): `Retry → CircuitBreaker → RateLimiter → TimeLimiter → Bulkhead → Method`.

With the recommended config above, CircuitBreaker wraps Retry: each failed call (after all retries exhausted) counts as one failure, not N failures.

### 3. Circuit Breaker Pattern

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

### 4. Retry Pattern

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

### 5. Rate Limiter Pattern

```java
@RateLimiter(name = "notificationService", fallbackMethod = "rateLimitFallback")
public void sendEmail(EmailRequest request) {
    emailClient.send(request);
}
```

```yaml
resilience4j:
  ratelimiter:
    configs:
      default:
        limitForPeriod: 10
        limitRefreshPeriod: 1s
        timeoutDuration: 500ms
    instances:
      notificationService:
        baseConfig: default
        limitForPeriod: 5
```

### 6. Bulkhead Pattern

| Type | Use case | Return type |
|------|----------|-------------|
| `SEMAPHORE` | Synchronous methods | Direct return |
| `THREADPOOL` | Async methods | `CompletableFuture<T>` |

```java
@Bulkhead(name = "reportService", type = Bulkhead.Type.SEMAPHORE)
public Report generateReport(ReportRequest request) {
    return reportGenerator.generate(request);
}

@Bulkhead(name = "analyticsService", type = Bulkhead.Type.THREADPOOL)
public CompletableFuture<AnalyticsResult> runAnalytics(AnalyticsRequest request) {
    return CompletableFuture.supplyAsync(() -> analyticsEngine.analyze(request));
}
```

```yaml
resilience4j:
  bulkhead:
    configs:
      default:
        maxConcurrentCalls: 10
        maxWaitDuration: 100ms
  thread-pool-bulkhead:
    instances:
      analyticsService:
        maxThreadPoolSize: 8
```

### 7. Time Limiter Pattern

Apply `@TimeLimiter` to async methods returning `CompletableFuture`:

```java
@TimeLimiter(name = "searchService", fallbackMethod = "searchFallback")
public CompletableFuture<SearchResults> search(SearchQuery query) {
    return CompletableFuture.supplyAsync(() -> searchEngine.executeSearch(query));
}
```

```yaml
resilience4j:
  timelimiter:
    configs:
      default:
        timeoutDuration: 2s
        cancelRunningFuture: true
```

### 8. Combining Multiple Patterns

Stack multiple patterns on a single method:

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

Execution order depends on `aspectOrder` config (see Section 2). All patterns should reference the same named instance for consistency.

### 9. Monitoring

Verify via Actuator: `/actuator/circuitbreakers` (state transitions), `/actuator/ratelimiters` (limited counts), `/actuator/metrics` (retry counts). See `spring-boot-actuator` skill for endpoint configuration.

## Constraints and Warnings

- **Configure aspect order explicitly** — always set `circuitBreakerAspectOrder` < `retryAspectOrder` in Spring Boot 3. Default places Retry outside CircuitBreaker, inflating failure rates.
- **Retry only transient errors** — 5xx, timeouts; NOT 4xx or business exceptions
- **NOT retry on non-idempotent operations** — POST/PUT may execute multiple times
- **NOT use circuit breaker for must-complete operations** — circuit breaker blocks calls when open
- **Fallback must match return type** — same type as original method plus optional `Exception` parameter
- Circuit breaker state is per-instance; ensure proper bean scoping in multi-tenant scenarios
- Rate limiters can cause thread blocking; configure appropriate `timeoutDuration`
- `resilience4j-spring-boot3` for Spring Boot 3.x; `resilience4j-spring-boot4` for Spring Boot 4.x

## References

- [Configuration & Testing Reference](references/references.md) — YAML defaults, programmatic config, testing patterns, aspect order pitfalls

## Related Skills

`spring-boot-exception-handling`, `spring-boot-actuator`, `spring-cloud-openfeign`