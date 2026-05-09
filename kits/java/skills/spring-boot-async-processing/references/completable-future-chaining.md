# CompletableFuture Chaining and Composition

## Basic operations: supplyAsync, runAsync

### supplyAsync — produce a result asynchronously

```java
CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
    return userRepository.findById("U001").orElseThrow().getName();
});
```

`supplyAsync` runs the supplier in `ForkJoinPool.commonPool()` by default. Pass a custom executor for production use:

```java
CompletableFuture<String> future = CompletableFuture.supplyAsync(
    () -> userRepository.findById("U001").orElseThrow().getName(),
    ioExecutor  // custom ThreadPoolTaskExecutor
);
```

### runAsync — execute without returning a result

```java
CompletableFuture<Void> future = CompletableFuture.runAsync(() -> {
    log.info("Background cleanup started");
    cleanupRepository.deleteExpiredRecords();
}, ioExecutor);
```

## Chaining operations

| Method | Purpose | Thread Behavior |
|--------|---------|-----------------|
| `thenApply` | Transform result (sync) | Runs in the completing thread (same as previous stage) |
| `thenApplyAsync` | Transform result (async) | Submits to a separate executor — use for CPU-intensive transformations |
| `thenAccept` | Consume result (no return) | Runs in the completing thread |
| `thenCompose` | Chain dependent futures (flatMap) | Flattens nested `CompletableFuture<CompletableFuture<...>>` |
| `thenCombine` | Combine two independent futures | Both must complete before combiner executes |

### thenCompose — chain dependent futures

`thenCompose` is used when the next step returns another `CompletableFuture` — it flattens the nested future:

```java
CompletableFuture<OrderDto> resultFuture = orderService.findOrderAsync("O001")
    .thenCompose(order -> paymentService.findPaymentAsync(order.getPaymentId()));
```

Without `thenCompose`, you get nested `CompletableFuture<CompletableFuture<...>>`:

```java
// WRONG — nested future
CompletableFuture<CompletableFuture<PaymentDto>> nested = orderService.findOrderAsync("O001")
    .thenApply(order -> paymentService.findPaymentAsync(order.getPaymentId()));

// CORRECT — flattened with thenCompose
CompletableFuture<PaymentDto> flat = orderService.findOrderAsync("O001")
    .thenCompose(order -> paymentService.findPaymentAsync(order.getPaymentId()));
```

## Combining operations

### thenCombine — combine two independent futures

```java
CompletableFuture<ProductDetailDto> detailFuture = productService.getProductDetailAsync("P001");
CompletableFuture<List<ProductReviewDto>> reviewFuture = reviewService.getProductReviewsAsync("P001");

CompletableFuture<ProductPageDto> pageFuture = detailFuture.thenCombine(reviewFuture,
    (detail, reviews) -> new ProductPageDto(detail, reviews)
);
```

Both futures must complete before the combiner function executes.

### allOf — wait for all futures to complete

```java
CompletableFuture<ProductDetailDto> detailFuture = productService.getProductDetailAsync("P001");
CompletableFuture<List<ProductReviewDto>> reviewFuture = reviewService.getProductReviewsAsync("P001");
CompletableFuture<PriceHistoryDto> priceFuture = priceService.getPriceHistoryAsync("P001");

CompletableFuture<Void> allFutures = CompletableFuture.allOf(detailFuture, reviewFuture, priceFuture);

// After allOf completes, join each future to get results
ProductPageDto pageDto = allFutures.thenApply(v ->
    new ProductPageDto(detailFuture.join(), reviewFuture.join(), priceFuture.join())
).get(5, TimeUnit.SECONDS);
```

**Note:** `allOf` returns `CompletableFuture<Void>` — you must call `.join()` on each individual future to retrieve results after `allOf` completes.

### anyOf — return first completed result

```java
CompletableFuture<String> primaryFuture = cacheService.getAsync("key");
CompletableFuture<String> fallbackFuture = dbService.getAsync("key");

CompletableFuture<Object> fastestFuture = CompletableFuture.anyOf(primaryFuture, fallbackFuture);

String result = (String) fastestFuture.get(3, TimeUnit.SECONDS);
```

`anyOf` returns `CompletableFuture<Object>` — you need to cast the result. Useful for failover patterns where the fastest response wins.

## Error handling

### exceptionally — handle exception, provide fallback

```java
CompletableFuture<ProductDto> future = productService.findProductAsync("P001")
    .exceptionally(ex -> {
        log.warn("Product lookup failed: {}", ex.getMessage());
        return ProductDto.empty();  // fallback value
    });
```

### handle — handle both result and exception

```java
CompletableFuture<ProductDto> future = productService.findProductAsync("P001")
    .handle((result, ex) -> {
        if (ex != null) {
            log.error("Async error: {}", ex.getMessage(), ex);
            return ProductDto.empty();
        }
        return result;
    });
```

`handle` always executes regardless of success or failure — useful for logging, metrics, and cleanup.

### whenComplete — side effect without modifying result

```java
CompletableFuture<ProductDto> future = productService.findProductAsync("P001")
    .whenComplete((result, ex) -> {
        if (ex != null) {
            metricsService.recordFailure("product_lookup", ex);
        } else {
            metricsService.recordSuccess("product_lookup");
        }
    });
```

`whenComplete` does NOT transform the result — it is for side effects only. The original future result (or exception) passes through unchanged.

## Async vs sync execution in CompletableFuture chain

| Method | Thread Behavior | When to Use |
|--------|-----------------|--------------|
| `thenApply` (sync) | Runs in the completing thread | Lightweight transformations — avoids thread-switching overhead |
| `thenApplyAsync` (async) | Submits to a separate executor | Heavy (CPU-intensive) transformations that need a different executor |
| Default `thenApplyAsync` | Uses `ForkJoinPool.commonPool()` | Never rely on this in production; always pass your executor |

See async-method-patterns.md for `@Async` CompletableFuture patterns.

## Practical example: parallel data fetch + aggregation

A common pattern in e-commerce systems — fetching product detail, reviews, and price history concurrently:

```java
@Service
@RequiredArgsConstructor
public class ProductPageService {
    private final ProductQueryService productQueryService;
    private final ReviewQueryService reviewQueryService;
    private final PriceQueryService priceQueryService;

    public ProductPageDto getProductPage(String productId) {
        // Step 1: Launch all async queries concurrently
        CompletableFuture<ProductDetailDto> detailFuture =
            productQueryService.getProductDetailAsync(productId);
        CompletableFuture<List<ReviewDto>> reviewFuture =
            reviewQueryService.getProductReviewsAsync(productId);
        CompletableFuture<PriceHistoryDto> priceFuture =
            priceQueryService.getPriceHistoryAsync(productId);

        // Step 2: Wait for all to complete, then aggregate
        try {
            CompletableFuture.allOf(detailFuture, reviewFuture, priceFuture).get(5, TimeUnit.SECONDS);

            return new ProductPageDto(
                detailFuture.join(),
                reviewFuture.join(),
                priceFuture.join()
            );
        } catch (TimeoutException ex) {
            log.error("Product page aggregation timed out for {}", productId);
            throw new ServiceUnavailableException("Product page data unavailable");
        } catch (ExecutionException ex) {
            log.error("Product page aggregation failed: {}", ex.getCause().getMessage());
            throw new ServiceException("Failed to load product page", ex.getCause());
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new ServiceException("Interrupted while loading product page", ex);
        }
    }
}

@Service
public class ProductQueryService {
    @Async("ioExecutor")
    public CompletableFuture<ProductDetailDto> getProductDetailAsync(String productId) {
        Product product = productRepository.findById(productId).orElseThrow();
        return CompletableFuture.completedFuture(ProductDetailDto.from(product));
    }
}

@Service
public class ReviewQueryService {
    @Async("ioExecutor")
    public CompletableFuture<List<ReviewDto>> getProductReviewsAsync(String productId) {
        List<Review> reviews = reviewRepository.findByProductId(productId);
        return CompletableFuture.completedFuture(
            reviews.stream().map(ReviewDto::from).toList()
        );
    }
}

@Service
public class PriceQueryService {
    @Async("ioExecutor")
    public CompletableFuture<PriceHistoryDto> getPriceHistoryAsync(String productId) {
        List<PriceRecord> records = priceRepository.findByProductIdOrderByDateDesc(productId);
        return CompletableFuture.completedFuture(PriceHistoryDto.from(records));
    }
}
```

### Alternative: pure CompletableFuture without @Async

When you don't need Spring's executor routing, use `supplyAsync` directly:

```java
@Service
@RequiredArgsConstructor
public class ProductPageService {
    private final Executor ioExecutor;

    public ProductPageDto getProductPage(String productId) {
        CompletableFuture<ProductDetailDto> detailFuture = CompletableFuture.supplyAsync(
            () -> ProductDetailDto.from(productRepository.findById(productId).orElseThrow()),
            ioExecutor
        );
        CompletableFuture<List<ReviewDto>> reviewFuture = CompletableFuture.supplyAsync(
            () -> reviewRepository.findByProductId(productId).stream().map(ReviewDto::from).toList(),
            ioExecutor
        );
        CompletableFuture<PriceHistoryDto> priceFuture = CompletableFuture.supplyAsync(
            () -> PriceHistoryDto.from(priceRepository.findByProductIdOrderByDateDesc(productId)),
            ioExecutor
        );

        return CompletableFuture.allOf(detailFuture, reviewFuture, priceFuture)
            .thenApply(v -> new ProductPageDto(
                detailFuture.join(),
                reviewFuture.join(),
                priceFuture.join()
            ))
            .get(5, TimeUnit.SECONDS);
    }
}
```

**Trade-off:** `supplyAsync` is simpler (no proxy, no `@EnableAsync`) but loses Spring's executor-name routing (`@Async("beanName")`).

## Timeout patterns

### CompletableFuture.orTimeout (Java 9+)

```java
CompletableFuture<ProductDto> future = productService.findProductAsync("P001")
    .orTimeout(5, TimeUnit.SECONDS);

// On timeout: CompletableFuture completes with TimeoutException
future.exceptionally(ex -> {
    if (ex instanceof TimeoutException) {
        log.warn("Product lookup timed out");
        return ProductDto.empty();
    }
    return ProductDto.empty();
});
```

### CompletableFuture.completeOnTimeout (Java 9+)

```java
CompletableFuture<ProductDto> future = productService.findProductAsync("P001")
    .completeOnTimeout(ProductDto.empty(), 3, TimeUnit.SECONDS);
// On timeout: completes with ProductDto.empty() instead of TimeoutException
```

### Manual timeout with get()

```java
try {
    ProductDto result = productService.findProductAsync("P001").get(5, TimeUnit.SECONDS);
} catch (TimeoutException ex) {
    // Future is NOT cancelled automatically — cancel it explicitly
    future.cancel(true);
    throw new ServiceTimeoutException("Product lookup timed out");
}
```

**Important:** `.get(timeout, unit)` does NOT cancel the underlying async task on timeout. The task continues running in the background. Use `.cancel(true)` if you want to interrupt the task.