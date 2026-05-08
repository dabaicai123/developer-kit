---
name: spring-boot-async-processing
description: "Spring Boot async processing with @Async, CompletableFuture, ThreadPoolTaskExecutor, async exception handling, and async+transaction boundary patterns. Use when implementing asynchronous execution in Spring Boot services."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Async Processing

## When to use this skill

- Adding asynchronous processing to Spring Boot services with `@Async` annotation
- Implementing fire-and-forget operations (notifications, logging, analytics)
- Composing async operations with `CompletableFuture` for parallel data fetch and aggregation
- Configuring `ThreadPoolTaskExecutor` beans with proper pool sizing and rejection policies
- Handling exceptions in `@Async` void methods via `AsyncUncaughtExceptionHandler`
- Combining `@Async` with `@Transactional` — understanding thread and transaction boundary issues
- Propagating security context, request context, or MDC to async threads via `TaskDecorator`

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

Maven dependency (included in `spring-boot-starter-web` or `spring-boot-starter`):

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter</artifactId>
</dependency>
```

## Instructions

### Declarative async with @Async

Annotate a service method with `@Async` to make it execute in a separate thread managed by Spring's task executor. The caller thread returns immediately.

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

**Validate:** Confirm the method executes on a different thread by logging `Thread.currentThread().getName()` inside the async method vs the caller.

See [async-method-patterns.md](references/async-method-patterns.md) for all `@Async` patterns.

### Programmatic async with CompletableFuture

Use `CompletableFuture` for async methods that need result composition, error handling, or chaining.

```java
@Service
public class OrderQueryService {
    @Async
    public CompletableFuture<OrderDto> findOrderAsync(String orderId) {
        return CompletableFuture.completedFuture(
            orderRepository.findById(orderId).map(OrderDto::from).orElse(null)
        );
    }
}
```

**Validate:** Call `CompletableFuture.get(timeout, unit)` and assert the result before proceeding.

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

**Validate:** After application startup, send multiple concurrent async requests and verify thread names start with your configured prefix in logs.

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

**Validate:** Throw an exception inside an `@Async void` method and confirm it appears in logs via your handler — not silently lost.

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

**Validate:** Confirm the `@Transactional` method commits its database changes by checking the database after the async task completes.

## Examples

### Example 1: @EnableAsync + @Async method on service (basic fire-and-forget)

```java
@Configuration
@EnableAsync
public class AsyncConfig {
}

@Service
public class AnalyticsService {
    @Async
    public void trackUserActivity(String userId, String action) {
        activityRepository.save(new UserActivity(userId, action, LocalDateTime.now()));
    }
}

// Caller — returns immediately, analytics processed in background
@RestController
@RequiredArgsConstructor
public class UserController {
    private final AnalyticsService analyticsService;

    @PostMapping("/users/{id}/login")
    public ResponseEntity<Void> login(@PathVariable String id) {
        analyticsService.trackUserActivity(id, "LOGIN");  // fire-and-forget
        return ResponseEntity.ok().build();
    }
}
```

### Example 2: @Async with CompletableFuture return type (composable async)

```java
@Service
public class ProductQueryService {
    @Async("productExecutor")
    public CompletableFuture<ProductDetailDto> getProductDetail(String productId) {
        Product product = productRepository.findById(productId).orElseThrow();
        return CompletableFuture.completedFuture(ProductDetailDto.from(product));
    }

    @Async("productExecutor")
    public CompletableFuture<List<ProductReviewDto>> getProductReviews(String productId) {
        return CompletableFuture.completedFuture(
            reviewRepository.findByProductId(productId)
                .stream().map(ProductReviewDto::from).toList()
        );
    }
}

// Caller — compose multiple async results
@Service
public class ProductAggregateService {
    private final ProductQueryService productQueryService;

    public ProductPageDto getProductPage(String productId) {
        CompletableFuture<ProductDetailDto> detailFuture = productQueryService.getProductDetail(productId);
        CompletableFuture<List<ProductReviewDto>> reviewsFuture = productQueryService.getProductReviews(productId);

        return CompletableFuture.allOf(detailFuture, reviewsFuture)
            .thenApply(v -> new ProductPageDto(detailFuture.join(), reviewsFuture.join()))
            .get(5, TimeUnit.SECONDS);
    }
}
```

### Example 3: Custom ThreadPoolTaskExecutor bean configuration

```java
@Configuration
@EnableAsync
public class AsyncExecutorConfig {

    @Bean("ioExecutor")
    public Executor ioExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(8);       // IO-bound: more threads than CPU cores
        executor.setMaxPoolSize(16);
        executor.setQueueCapacity(200);
        executor.setThreadNamePrefix("io-async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }

    @Bean("computeExecutor")
    public Executor computeExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);       // CPU-bound: ~CPU cores
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("compute-async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }
}

@Service
public class ReportService {
    @Async("computeExecutor")
    public CompletableFuture<ReportDto> generateReport(String reportId) {
        // Uses computeExecutor — CPU-intensive work
        return CompletableFuture.completedFuture(reportEngine.generate(reportId));
    }

    @Async("ioExecutor")
    public void exportToPdf(String reportId) {
        // Uses ioExecutor — IO-intensive work
        pdfExporter.export(reportEngine.generate(reportId));
    }
}
```

### Example 4: AsyncUncaughtExceptionHandler for @Async void methods

```java
@Slf4j
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

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return (ex, method, params) -> {
            log.error("Uncaught async exception — method: {}, params: {}, exception: {}",
                method.getName(),
                Arrays.toString(params),
                ex.getMessage(),
                ex);
            // Optionally: send to monitoring system, alert channel, etc.
        };
    }
}

@Service
public class EmailService {
    @Async
    public void sendNotification(String recipient, String subject) {
        // If this throws, the handler above catches it
        emailClient.send(recipient, subject, "body");
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
}
```

## Best Practices

- Always use a custom `ThreadPoolTaskExecutor` bean — never rely on `SimpleAsyncTaskExecutor` (creates unbounded threads)
- Name your executor beans and reference with `@Async("executorName")` to route tasks to appropriate pools
- Return `CompletableFuture` for methods that need composition or result checking
- Use `@Async` for fire-and-forget only when the result is truly irrelevant
- Separate `@Transactional` and `@Async` into different service beans to avoid proxy self-invocation
- Configure thread pool sizing: `corePoolSize` = CPU cores, `maxPoolSize` = 2*CPU cores, `queueCapacity` = 100-500
- Use `CallerRunsPolicy` as rejection handler — prevents silent task loss
- Set `waitForTasksToCompleteOnShutdown=true` and `awaitTerminationSeconds` for graceful shutdown
- Use `TaskDecorator` to propagate security context, MDC, and request context to async threads

## Constraints and Warnings

- **Self-invocation:** `@Async` on same-class method calls is silently ignored (same as `@Transactional` — Spring AOP proxy limitation)
- **Transaction boundary:** `@Async` methods run in a separate thread — they don't inherit the caller's transaction context. Each `@Async` method needs its own `@Transactional`
- **Thread pool exhaustion:** without proper `TaskExecutor` configuration, async tasks may silently fail or queue indefinitely
- **Context propagation:** Spring Security context, `RequestContextHolder`, and MDC are NOT automatically propagated to async threads — use `TaskDecorator` to propagate
- **Never `@Async` + `@Transactional` on the same method** — it creates confusing proxy ordering and unpredictable behavior

## References

- **[async-method-patterns.md](references/async-method-patterns.md)** — @Async patterns: void, CompletableFuture, executor selection, class-level, exception handling, MdcTaskDecorator
- **[completable-future-chaining.md](references/completable-future-chaining.md)** — CompletableFuture operations, chaining, combining, error handling, parallel data fetch
- **[threadpool-taskexecutor-config.md](references/threadpool-taskexecutor-config.md)** — ThreadPoolTaskExecutor bean configuration, sizing guidelines, multiple executors, monitoring, yml approach
- [Spring @Async Documentation](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/annotation/Async.html)
- [Spring Task Execution Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.task-execution-and-scheduling)
- [CompletableFuture API](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html)

## Related Skills

- `spring-boot-transaction-management` — @Transactional patterns, propagation, isolation
- `spring-boot-event-driven-patterns` — @TransactionalEventListener for async event handling after commit
- `spring-boot-scheduled-tasks` — @Scheduled patterns, XXL-Job, distributed scheduling

## Keywords

@Async, CompletableFuture, TaskExecutor, thread pool, async exception, ContextPropagation, TaskDecorator