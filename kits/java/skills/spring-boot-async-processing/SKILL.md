---
name: spring-boot-async-processing
description: "Spring Boot async processing with @Async, CompletableFuture, ThreadPoolTaskExecutor, async exception handling, and async+transaction boundary patterns. Use when implementing asynchronous execution in Spring Boot services."
version: "1.0.0"
---

# Spring Boot Async Processing

## When to use this skill

- Adding asynchronous processing to Spring Boot services with `@Async` annotation
- Implementing fire-and-forget operations (notifications, logging, analytics)
- Composing async operations with `CompletableFuture` for parallel data fetch and aggregation
- Configuring `ThreadPoolTaskExecutor` beans with proper pool sizing and rejection policies
- Handling exceptions in `@Async` void methods via `AsyncUncaughtExceptionHandler`
- Combining `@Async` with `@Transactional` — understanding thread and transaction boundary issues
- Propagating security context, request context, or ThreadContext to async threads via `TaskDecorator`

> For unit testing `@Async` methods, see `unit-test-scheduled-async`. For event-driven architecture with `@TransactionalEventListener`, see `spring-boot-event-driven-patterns`.

## Project Setup — @EnableAsync configuration

```java
@Configuration
@EnableAsync
public class AsyncConfig {
    // @EnableAsync activates Spring's @Async annotation processing
    // Without this, @Async annotations are silently ignored
}
```

## Instructions

### Declarative async with @Async

Annotate a service method with `@Async` to make it execute in a separate thread managed by Spring's task executor. The caller thread returns immediately.

Verify async behavior by confirming methods execute on threads with your configured prefix (not the caller thread).

```java
@Service
public class NotificationService {
    @Async
    public void sendWelcomeEmail(String userId) {
        // Executes in background thread — caller does not wait
        emailClient.send(userId, "Welcome!");
    }
}
```

See [async-method-patterns.md](references/async-method-patterns.md) for all `@Async` patterns.

### Programmatic async with CompletableFuture

Use `CompletableFuture` for async methods that need result composition, error handling, or chaining.

```java
@Service
public class OrderQueryService {
    @Async
    public CompletableFuture<OrderDTO> findOrderAsync(String orderId) {
        return CompletableFuture.completedFuture(
            orderRepository.findById(orderId).map(OrderDTO::from).orElse(null)
        );
    }
}
```

See [completable-future-chaining.md](references/completable-future-chaining.md) for full chaining and composition patterns.

### Custom TaskExecutor configuration

Always define a custom `ThreadPoolTaskExecutor` bean. Spring's default `SimpleAsyncTaskExecutor` creates unbounded threads — unacceptable for production.

```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }
}
```

See [threadpool-taskexecutor-config.md](references/threadpool-taskexecutor-config.md) for detailed configuration, sizing guidelines, and monitoring.

### Async exception handling

For `@Async` methods with `void` return type, exceptions are silently swallowed unless you configure `AsyncUncaughtExceptionHandler`. For `CompletableFuture` return types, handle exceptions via `handle()`, `exceptionally()`, or `CompletableFuture.get()`.

```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return (ex, method, params) -> {
            log.error("Async exception in method {}: {}", method.getName(), ex.getMessage(), ex);
        };
    }
}
```

See [async-method-patterns.md](references/async-method-patterns.md) for exception handling patterns.

### Async + transaction boundary

`@Async` methods run in a separate thread and do NOT inherit the caller's transaction context. Never place `@Async` and `@Transactional` on the same method. Instead, separate them into different service beans:

```java
// WRONG — confusing proxy ordering
@Async
@Transactional  // DO NOT combine on same method
public void processOrderAsync(String orderId) { ... }

// CORRECT — @Async calls a separate @Transactional service
@Async
public void processOrderAsync(String orderId) {
    orderTransactionService.processOrder(orderId);  // Separate bean — proxy works
}
```

For full `@Transactional` patterns (propagation, rollback, self-invocation), see `spring-boot-transaction-management`.

## Examples

### Example 2: @Async with CompletableFuture return type (composable async)

```java
@Service
public class ProductQueryService {
    @Async("productExecutor")
    public CompletableFuture<ProductDetailDTO> getProductDetail(String productId) {
        Product product = productRepository.findById(productId).orElseThrow();
        return CompletableFuture.completedFuture(ProductDetailDTO.from(product));
    }

    @Async("productExecutor")
    public CompletableFuture<List<ProductReviewDTO>> getProductReviews(String productId) {
        return CompletableFuture.completedFuture(
            reviewRepository.findByProductId(productId)
                .stream().map(ProductReviewDTO::from).toList()
        );
    }
}

// Caller — compose multiple async results
@Service
public class ProductAggregateService {
    private final ProductQueryService productQueryService;

    public ProductPageDTO getProductPage(String productId) {
        CompletableFuture<ProductDetailDTO> detailFuture = productQueryService.getProductDetail(productId);
        CompletableFuture<List<ProductReviewDTO>> reviewsFuture = productQueryService.getProductReviews(productId);

        return CompletableFuture.allOf(detailFuture, reviewsFuture)
            .thenApply(v -> new ProductPageDTO(detailFuture.join(), reviewsFuture.join()))
            .get(5, TimeUnit.SECONDS);
    }
}
```

### Example 5: Async + transaction boundary — proper separation

```java
// The @Async method — no @Transactional here
@Service
@RequiredArgsConstructor
public class OrderAsyncService {
    private final OrderTransactionService orderTransactionService;

    @Async("orderExecutor")
    public CompletableFuture<Void> processOrderAsync(String orderId) {
        orderTransactionService.processOrder(orderId);  // Separate @Transactional bean
        return CompletableFuture.completedFuture(null);
    }
}

// The @Transactional method — owns the transaction boundary
// For full @Transactional patterns, see spring-boot-transaction-management
@Service
@RequiredArgsConstructor
public class OrderTransactionService {
    @Transactional(rollbackFor = Exception.class)
    public Order processOrder(String orderId) { ... }
}
```

## Best Practices

- Name your executor beans and reference with `@Async("executorName")` to route tasks to appropriate pools
- Return `CompletableFuture` for methods that need composition or result checking
- Use `@Async` for fire-and-forget only when the result is truly irrelevant
- Configure thread pool sizing: `corePoolSize` = CPU cores, `maxPoolSize` = 2*CPU cores, `queueCapacity` = 100-500
- Use `CallerRunsPolicy` as rejection handler — prevents silent task loss
- Set `waitForTasksToCompleteOnShutdown=true` and `awaitTerminationSeconds` for graceful shutdown
- Use `TaskDecorator` to propagate security context, ThreadContext, and request context to async threads

## Constraints and Warnings

- **Self-invocation:** `@Async` on same-class method calls is silently ignored (Spring AOP proxy limitation — see `spring-boot-transaction-management` for details)
- **Transaction boundary:** `@Async` methods run in a separate thread — they don't inherit the caller's transaction. Never `@Async` + `@Transactional` on the same method (see `spring-boot-transaction-management`)
- **Thread pool exhaustion:** without proper `TaskExecutor` configuration, async tasks may silently fail or queue indefinitely
- **Context propagation:** Spring Security context, `RequestContextHolder`, and ThreadContext are NOT automatically propagated to async threads — use `TaskDecorator` to propagate

## References

- **[async-method-patterns.md](references/async-method-patterns.md)** — @Async patterns: void, CompletableFuture, executor selection, class-level, exception handling, ThreadContextTaskDecorator
- **[completable-future-chaining.md](references/completable-future-chaining.md)** — CompletableFuture operations, chaining, combining, error handling, parallel data fetch
- **[threadpool-taskexecutor-config.md](references/threadpool-taskexecutor-config.md)** — ThreadPoolTaskExecutor bean configuration, sizing guidelines, multiple executors, monitoring, yml approach

## Related Skills

- `spring-boot-transaction-management`
- `spring-boot-event-driven-patterns`
- `spring-boot-scheduled-tasks`