# Resilience4j Configuration & Testing Reference

Supplement to SKILL.md. Contains YAML defaults, aspect order config, and testing patterns.

## Aspect Order (Spring Boot 3)

Default annotation order (outer → inner): `Retry → CircuitBreaker → RateLimiter → TimeLimiter → Bulkhead → Method`.

**Problem**: By default, Retry wraps CircuitBreaker. Each retry attempt is counted as a separate failure by CircuitBreaker, inflating failure rates and causing premature circuit opening.

**Fix**: Set `circuitBreakerAspectOrder` lower than `retryAspectOrder` so CircuitBreaker wraps Retry — each failed call (after all retries exhausted) counts as one failure:

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

| Aspect | Default Order | Recommended Order | Why |
|--------|--------------|-------------------|-----|
| CircuitBreaker | LOWEST_PRECEDENCE - 3 | 1 | Must wrap Retry to avoid inflated failure counts |
| Retry | LOWEST_PRECEDENCE - 4 | 2 | Inner to CircuitBreaker; retries are transparent to CB |
| RateLimiter | LOWEST_PRECEDENCE - 2 | 3 | Rate limit before executing |
| TimeLimiter | LOWEST_PRECEDENCE - 1 | 4 | Timeout enforcement |
| Bulkhead | LOWEST_PRECEDENCE - 5 (fixed) | 5 | Resource isolation (fixed order, cannot be changed) |

## YAML Default Values

| Instance Property | Default | Notes |
|---|---|---|
| `slidingWindowSize` | 100 | Calls in sliding window |
| `slidingWindowType` | COUNT_BASED | Or TIME_BASED for rate |
| `failureRateThreshold` | 50 | % failures to open circuit |
| `slowCallRateThreshold` | 100 | % slow calls to open |
| `slowCallDurationThreshold` | 60s | Threshold for "slow" |
| `waitDurationInOpenState` | 60s | Time before half-open |
| `permittedNumberOfCallsInHalfOpenState` | 10 | Calls in half-open |
| `minimumNumberOfCalls` | 100 | Min calls before rate calc |
| `recordExceptions` | all | Exceptions counted as failures |
| `ignoreExceptions` | empty | Exceptions ignored |
| `automaticTransitionFromOpenToHalfOpenEnabled` | false | Auto half-open |

## Programmatic Configuration (Advanced)

```java
CircuitBreakerConfig config = CircuitBreakerConfig.custom()
    .failureRateThreshold(50)
    .waitDurationInOpenState(Duration.ofSeconds(30))
    .slidingWindowSize(100)
    .permittedNumberOfCallsInHalfOpenState(5)
    .recordExceptions(BusinessException.class)
    .ignoreExceptions(NotFoundException.class)
    .build();
CircuitBreaker circuitBreaker = CircuitBreaker.of("orderService", config);
```

## Testing Patterns

### CircuitBreaker Testing

```java
@SpringBootTest
class OrderServiceCircuitBreakerTest {
    @Autowired OrderService orderService;
    @Autowired CircuitBreakerRegistry registry;

    @Test
    void fallbackOnExternalFailure() {
        CircuitBreaker cb = registry.circuitBreaker("orderService");
        for (int i = 0; i < 10; i++) {
            assertThatThrownBy(() -> orderService.getExternalOrder("fail"))
                .isInstanceOf(BusinessException.class);
        }
        Result<OrderDTO> result = orderService.getExternalOrder("any");
        assertThat(result.getCode()).isEqualTo(Result.FAIL);
    }
}
```

### Fallback Signature Pitfall

```java
// NOT mismatch fallback return type
@CircuitBreaker(name = "orderService", fallbackMethod = "fallback")
public Result<OrderDTO> getOrder(String id) { ... }
private Result<String> fallback(String id) { ... }  // WRONG — return type mismatch

// Correct — matching return type with Exception parameter
@CircuitBreaker(name = "orderService", fallbackMethod = "fallback")
public Result<OrderDTO> getOrder(String id) { ... }
private Result<OrderDTO> fallback(String id, Exception e) { ... }
```

### Retry Testing with Mockito

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceRetryTest {
    @Mock OrderGateway orderGateway;
    @InjectMocks OrderServiceImpl orderService;

    @Test
    void retriesOnTransientFailure() {
        when(orderGateway.findById("1"))
            .thenThrow(new BusinessException("transient"))
            .thenReturn(Optional.of(order));
        Result<OrderDTO> result = orderService.getOrder("1");
        assertThat(result.getData()).isNotNull();
        verify(orderGateway, times(2)).findById("1");
    }
}
```

### Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Fallback return type mismatch | Match original `Result<T>` return type |
| Sliding window too small (`minimumNumberOfCalls=5`) | Use 10+ for production |
| Fallback missing `Exception` parameter | Add `Exception e` as 2nd param |
| Default aspect order inflating CB failure counts | Set `circuitBreakerAspectOrder` < `retryAspectOrder` |
| Testing only with `@SpringBootTest` | Use targeted mock + registry inspection |
| Using `resilience4j-spring-boot2` artifact | Use `resilience4j-spring-boot3` for Spring Boot 3.x |