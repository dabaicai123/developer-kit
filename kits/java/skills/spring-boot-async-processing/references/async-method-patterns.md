# Async Method Patterns

## @Async void return — fire-and-forget

Use `@Async` with `void` return type for operations where the result is irrelevant: logging, analytics, notifications. The caller thread returns immediately; the async method runs on a background thread.

```java
@Service
@RequiredArgsConstructor
public class NotificationService {
    private final EmailClient emailClient;

    @Async
    public void sendWelcomeEmail(String userId) {
        // Runs in background — caller does not wait
        User user = userRepository.findById(userId).orElseThrow();
        emailClient.send(user.getEmail(), "Welcome!", "Welcome to our platform");
    }
}
```

**Key points:**
- Exceptions in `@Async void` methods are NOT propagated to the caller — they go to `AsyncUncaughtExceptionHandler`
- No way to check completion status from the caller
- Suitable only for truly disposable operations

## @Async CompletableFuture<T> return — composable

Use `CompletableFuture` when you need to compose results, check completion, or handle errors from the caller.

```java
@Service
public class ProductService {
    @Async("productExecutor")
    public CompletableFuture<ProductDto> findProductAsync(String productId) {
        Product product = productRepository.findById(productId).orElseThrow();
        return CompletableFuture.completedFuture(ProductDto.from(product));
    }
}
```

**Caller side:**

```java
CompletableFuture<ProductDto> future = productService.findProductAsync("P001");
ProductDto result = future.get(5, TimeUnit.SECONDS);  // block with timeout
```

**Composition:**

```java
CompletableFuture<ProductDto> productFuture = productService.findProductAsync("P001");
CompletableFuture<List<ReviewDto>> reviewFuture = reviewService.findReviewsAsync("P001");

CompletableFuture<ProductPageDto> pageFuture = productFuture.thenCombine(reviewFuture,
    (product, reviews) -> new ProductPageDto(product, reviews)
);
```

## @Async ListenableFuture (deprecated)

`ListenableFuture` was the original async return type in Spring 4.x. It is **deprecated since Spring 6.0** and replaced by `CompletableFuture`.

```java
// DEPRECATED — do not use in Spring Boot 3.x
@Async
public ListenableFuture<Product> findProduct(String id) {
    return new AsyncResult<>(productRepository.findById(id).orElseThrow());
}
```

**Migration:**

```java
// Use CompletableFuture instead
@Async
public CompletableFuture<Product> findProduct(String id) {
    return CompletableFuture.completedFuture(
        productRepository.findById(id).orElseThrow()
    );
}
```

## @Async with specific executor

When multiple `ThreadPoolTaskExecutor` beans exist, specify which one to use with `@Async("beanName")`.

```java
@Configuration
@EnableAsync
public class AsyncExecutorConfig {

    @Bean("ioExecutor")
    public Executor ioExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(8);
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
        executor.setCorePoolSize(4);
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
    @Async("computeExecutor")  // CPU-intensive work
    public CompletableFuture<ReportDto> generateReport(String reportId) {
        return CompletableFuture.completedFuture(reportEngine.generate(reportId));
    }

    @Async("ioExecutor")  // IO-intensive work
    public void exportToCloudStorage(String reportId) {
        storageClient.upload(reportEngine.generate(reportId).toFile());
    }
}
```

**Without `@Async("beanName")`**, Spring uses the default executor returned by `AsyncConfigurer.getAsyncExecutor()`, or `SimpleAsyncTaskExecutor` if no custom executor is configured.

## @Async on class level vs method level

### Class-level @Async

When `@Async` is placed on a class, ALL public methods become async:

```java
@Async("ioExecutor")
@Service
public class BackgroundNotificationService {
    // All public methods are async by default

    public void sendEmail(String userId, String subject) { ... }
    public void sendSms(String userId, String message) { ... }
}
```

**Caveats:**
- All public methods execute asynchronously — including methods that should be synchronous
- Harder to reason about which methods are async
- Cannot selectively make some methods synchronous

### Method-level @Async (preferred)

Apply `@Async` only on methods that need async execution — explicit and clear:

```java
@Service
public class NotificationService {
    @Async("ioExecutor")
    public void sendEmailAsync(String userId, String subject) { ... }

    @Async("ioExecutor")
    public void sendSmsAsync(String userId, String message) { ... }

    // This method is synchronous — intentional
    public EmailResult sendEmailSync(String userId, String subject) { ... }
}
```

**Recommendation:** Use method-level `@Async`. It is explicit, easier to test, and avoids accidental async execution.

## Exception handling

### AsyncUncaughtExceptionHandler for void methods

Exceptions thrown by `@Async void` methods are NOT propagated to the caller. They must be caught by `AsyncUncaughtExceptionHandler`:

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
            log.error("Uncaught async exception — method: {}, params: {}, message: {}",
                method.getName(),
                Arrays.toString(params),
                ex.getMessage(),
                ex);
        };
    }
}
```

**Without this handler, `@Async void` method exceptions are silently lost — no logs, no stack traces, no alerts.**

### try-catch for CompletableFuture methods

For `@Async` methods returning `CompletableFuture`, exceptions are wrapped in the future and can be handled by the caller:

```java
// Producer — throw inside CompletableFuture
@Async
public CompletableFuture<OrderDto> findOrderAsync(String orderId) {
    try {
        Order order = orderRepository.findById(orderId).orElseThrow();
        return CompletableFuture.completedFuture(OrderDto.from(order));
    } catch (Exception ex) {
        return CompletableFuture.failedFuture(ex);
    }
}

// Consumer — handle with exceptionally() or handle()
CompletableFuture<OrderDto> future = orderService.findOrderAsync("O001")
    .exceptionally(ex -> {
        log.warn("Failed to find order: {}", ex.getMessage());
        return null;  // fallback value
    })
    .handle((result, ex) -> {
        if (ex != null) {
            log.error("Async error: {}", ex.getMessage(), ex);
            return OrderDto.empty();
        }
        return result;
    });
```

### Manual try-catch inside @Async void methods

For `@Async void` methods, you can also catch exceptions manually before they reach the handler:

```java
@Async
public void sendNotification(String userId, String message) {
    try {
        notificationClient.send(userId, message);
    } catch (NotificationException ex) {
        log.error("Notification failed for user {}: {}", userId, ex.getMessage());
        // Optionally: save to retry queue, mark as failed in DB
        notificationFailureRepository.save(new NotificationFailure(userId, message, ex.getMessage()));
    }
}
```

## Context propagation: ThreadContextTaskDecorator pattern

Spring Security context, `RequestContextHolder`, and ThreadContext are NOT automatically propagated to async threads. Use `TaskDecorator` to copy context from the caller thread to the async thread.

### ThreadContextTaskDecorator — propagate ThreadContext (logging context)

```java
public class ThreadContextTaskDecorator implements TaskDecorator {
    @Override
    public Runnable decorate(Runnable runnable) {
        // Capture ThreadContext from caller thread
        Map<String, String> contextMap = ThreadContext.getContext();
        return () -> {
            try {
                // Set ThreadContext in async thread
                if (contextMap != null) {
                    ThreadContext.putAll(contextMap);
                }
                runnable.run();
            } finally {
                // Clean up ThreadContext to prevent thread contamination
                ThreadContext.clearAll();
            }
        };
    }
}
```

### Configure ThreadContextTaskDecorator on executor

```java
@Bean("ioExecutor")
public Executor ioExecutor() {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
    executor.setCorePoolSize(8);
    executor.setMaxPoolSize(16);
    executor.setQueueCapacity(200);
    executor.setThreadNamePrefix("io-async-");
    executor.setTaskDecorator(new ThreadContextTaskDecorator());
    executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
    executor.setWaitForTasksToCompleteOnShutdown(true);
    executor.setAwaitTerminationSeconds(30);
    executor.initialize();
    return executor;
}
```

### Combined SecurityContext + ThreadContext TaskDecorator

```java
public class ContextPropagatingTaskDecorator implements TaskDecorator {
    @Override
    public Runnable decorate(Runnable runnable) {
        Map<String, String> threadContext = ThreadContext.getContext();
        SecurityContext securityContext = SecurityContextHolder.getContext();
        RequestAttributes requestAttributes = RequestContextHolder.getRequestAttributes();

        return () -> {
            try {
                if (threadContext != null) {
                    ThreadContext.putAll(threadContext);
                }
                SecurityContextHolder.setContext(securityContext);
                if (requestAttributes != null) {
                    RequestContextHolder.setRequestAttributes(requestAttributes);
                }
                runnable.run();
            } finally {
                ThreadContext.clearAll();
                SecurityContextHolder.clearContext();
                RequestContextHolder.resetRequestAttributes();
            }
        };
    }
}
```

**Note:** Spring Boot 3.x provides `spring-boot-configuration-processor` and `ContextPropagation` from Spring Framework 6.1. For Spring Security, the `DelegatingSecurityContextRunnable` can be used instead of manual propagation.

## Self-invocation warning — @Async silently ignored

Calling an `@Async` method from within the same class bypasses the Spring AOP proxy — the method runs synchronously:

```java
@Service
public class OrderService {
    @Async
    public void notifyCustomer(String orderId) { ... }

    @Transactional
    public void createOrder(OrderRequest request) {
        orderRepository.save(Order.create(request));
        // WRONG — self-invocation, @Async is ignored
        this.notifyCustomer(request.getOrderId());  // runs synchronously!
    }
}
```

**Fix:** Inject a self-reference or move the async method to a separate service:

```java
// Option 1: Inject self-reference (works but not recommended)
@Service
@Lazy
public class OrderService {
    @Autowired @Lazy
    private OrderService self;

    @Async
    public void notifyCustomer(String orderId) { ... }

    @Transactional
    public void createOrder(OrderRequest request) {
        orderRepository.save(Order.create(request));
        self.notifyCustomer(request.getOrderId());  // proxy invoked — @Async works
    }
}

// Option 2: Separate service (recommended)
@Service
public class OrderService {
    private final NotificationAsyncService notificationAsyncService;

    @Transactional
    public void createOrder(OrderRequest request) {
        orderRepository.save(Order.create(request));
        notificationAsyncService.notifyCustomer(request.getOrderId());  // different bean — proxy works
    }
}

@Service
public class NotificationAsyncService {
    @Async
    public void notifyCustomer(String orderId) { ... }
}
```