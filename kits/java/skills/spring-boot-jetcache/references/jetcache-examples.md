# JetCache Examples

Progressive examples demonstrating JetCache caching patterns from basic to advanced scenarios.

## Example 1: Basic @Cached Usage (Remote Only)

```java
@Service
public class ProductService {

    @Cached(name = "product:", key = "#productId", expire = 3600)
    public Product getProductById(Long productId) {
        return productRepository.findById(productId)
            .orElseThrow(() -> new ResourceNotFoundException("Product not found"));
    }

    @CacheUpdate(name = "product:", key = "#product.id", value = "#product")
    public Product updateProduct(Product product) {
        return productRepository.save(product);
    }

    @CacheInvalidate(name = "product:", key = "#productId")
    public void deleteProduct(Long productId) {
        productRepository.deleteById(productId);
    }
}
```

**Test:**

```java
@SpringBootTest
class ProductServiceCacheTest {

    @Autowired
    private ProductService productService;

    @SpyBean
    private ProductRepository productRepository;

    @Test
    void shouldCacheProductAfterFirstCall() {
        Product product = new Product(1L, "Laptop", BigDecimal.valueOf(999.99));
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));

        // First call — cache miss, repository invoked
        Product result1 = productService.getProductById(1L);
        verify(productRepository, times(1)).findById(1L);

        // Second call — cache hit, repository skipped
        Product result2 = productService.getProductById(1L);
        verify(productRepository, times(1)).findById(1L); // still 1x
        assertThat(result2).isEqualTo(result1);
    }

    @Test
    void shouldEvictCacheOnDelete() {
        Product product = new Product(1L, "Laptop", BigDecimal.valueOf(999.99));
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));

        // Populate cache
        productService.getProductById(1L);
        verify(productRepository, times(1)).findById(1L);

        // Delete — cache invalidated
        productService.deleteProduct(1L);

        // Next call — cache miss, repository invoked again
        productService.getProductById(1L);
        verify(productRepository, times(2)).findById(1L);
    }
}
```

---

## Example 2: Two-Level Cache (BOTH)

Local Caffeine + Remote Redis with separate local TTL.

```java
@Service
public class UserService {

    @Cached(name = "user:", key = "#userId", expire = 3600,
            cacheType = CacheType.BOTH, localExpire = 300, localLimit = 50)
    public User getUserById(Long userId) {
        return userRepository.findById(userId).orElse(null);
    }

    @CacheInvalidate(name = "user:", key = "#userId")
    public void deleteUser(Long userId) {
        userRepository.deleteById(userId);
    }
}
```

**Flow:**
```
First call → local miss → remote miss → load from DB → write local (300s TTL) + remote (3600s TTL)
Second call → local hit → return immediately (no remote call)
After 300s → local expired → remote hit → refresh local
After 3600s → both expired → load from DB
```

---

## Example 3: Conditional Caching with SpEL

```java
@Service
public class PremiumProductService {

    @Cached(name = "premiumProduct:", key = "#productId", expire = 3600,
            condition = "#price > 500", cacheNullValue = true)
    public Product getPremiumProduct(Long productId, BigDecimal price) {
        return productRepository.findById(productId).orElse(null);
    }

    @Cached(name = "discountProduct:", key = "#productId", expire = 1800,
            postCondition = "#result != null && #result.price < 50")
    public Product getDiscountProduct(Long productId) {
        return productRepository.findById(productId).orElse(null);
    }
}
```

**Test:**

```java
@Test
void shouldCachePremiumProductsOnly() {
    // Cheap product (price=29.99) — condition=false, not cached
    premiumProductService.getPremiumProduct(1L, BigDecimal.valueOf(29.99));
    verify(productRepository, times(1)).findById(1L);

    // Second call still hits DB (not cached)
    premiumProductService.getPremiumProduct(1L, BigDecimal.valueOf(29.99));
    verify(productRepository, times(2)).findById(1L);
}
```

---

## Example 4: QuickConfig Programmatic Cache

```java
@Service
public class OrderService {

    private Cache<String, Order> orderCache;

    @Autowired
    private CacheManager cacheManager;

    @PostConstruct
    public void init() {
        QuickConfig qc = QuickConfig.newBuilder("order:")
            .expire(Duration.ofSeconds(3600))
            .localExpire(Duration.ofSeconds(300))
            .cacheType(CacheType.BOTH)
            .localLimit(50)
            .syncLocal(true)
            .build();
        orderCache = cacheManager.getOrCreateCache(qc);
    }

    public Order getOrder(String orderNumber) {
        return orderCache.computeIfAbsent(orderNumber, num ->
            orderRepository.findByOrderNumber(num).orElse(null));
    }

    public void updateOrder(Order order) {
        orderRepository.save(order);
        orderCache.put(order.getOrderNumber(), order);
    }

    public void removeOrder(String orderNumber) {
        orderRepository.deleteByOrderNumber(orderNumber);
        orderCache.remove(orderNumber);
    }
}
```

---

## Example 5: syncLocal Multi-Instance Consistency

```yaml
jetcache:
  remote:
    default:
      type: redis.redisson
      broadcastChannel: orderServiceChannel  # Required for syncLocal
      ...
```

```java
QuickConfig qc = QuickConfig.newBuilder("order:")
    .cacheType(CacheType.BOTH)
    .syncLocal(true)  // When this instance updates, broadcast invalidates other instances' local cache
    .build();
```

**Flow:**
```
Instance A: put("order:123", order) → writes local + remote → publishes invalidation on broadcastChannel
Instance B: receives invalidation → evicts "order:123" from local cache → next access reads fresh from remote
```

---

## Example 6: Auto Refresh with @CacheRefresh

Prevent cache stampede by refreshing before expiry.

```java
@Service
public class CatalogService {

    @Cached(name = "catalog:", key = "#catalogId", expire = 3600,
            cacheType = CacheType.BOTH)
    @CacheRefresh(refresh = 1800, stopRefreshAfterLastAccess = 7200,
                  refreshLockTimeout = 60)
    public Catalog getCatalog(Long catalogId) {
        return catalogRepository.findById(catalogId).orElse(null);
    }
}
```

**Flow:**
```
0s      → first access, cache loaded (TTL=3600s)
1800s   → auto refresh triggered (only one server refreshes via distributed lock)
3600s   → cache still fresh due to refresh (not expired)
7200s   → if no access since last refresh, stop refreshing
```

---

## Example 7: Penetration Protect

```java
@Service
public class StockService {

    @Cached(name = "stock:", key = "#sku", expire = 600,
            cacheType = CacheType.REMOTE, cacheNullValue = true)
    @CachePenetrationProtect
    public StockInfo getStock(String sku) {
        return stockRepository.findBySku(sku).orElse(null);
    }
}
```

**Flow:**
```
Concurrent 100 requests for same SKU → cache miss
  → @CachePenetrationProtect: only 1 thread loads, 99 threads wait
  → cacheNullValue=true: if result is null, still cache it (TTL=600s)
  → subsequent requests hit cache (even for null), no DB pressure
```

---

## Example 8: Complete Service with All JetCache Features

```java
@Service
@Slf4j
public class ProductCatalogService {

    // Two-level cache with auto refresh and penetration protect
    @Cached(name = "product:", key = "#productId", expire = 3600,
            cacheType = CacheType.BOTH, localExpire = 300,
            localLimit = 50, cacheNullValue = true, area = "catalog")
    @CacheRefresh(refresh = 1800, stopRefreshAfterLastAccess = 7200)
    @CachePenetrationProtect
    public Product getProduct(Long productId) {
        log.debug("Loading product {} from database", productId);
        return productRepository.findById(productId).orElse(null);
    }

    // Update — name and area must match @Cached
    @CacheUpdate(name = "product:", key = "#product.id", value = "#product", area = "catalog")
    public Product updateProduct(Product product) {
        return productRepository.save(product);
    }

    // Delete — name and area must match @Cached
    @CacheInvalidate(name = "product:", key = "#productId", area = "catalog")
    public void deleteProduct(Long productId) {
        productRepository.deleteById(productId);
    }
}
```

**Corresponding yml:**

```yaml
jetcache:
  areaInCacheName: false
  local:
    catalog:
      type: caffeine
      keyConvertor: fastjson2
      limit: 50
      expireAfterWriteInMillis: 300000
  remote:
    catalog:
      type: redis.redisson
      keyConvertor: fastjson2
      broadcastChannel: catalogChannel
      valueEncoder: kryo5
      valueDecoder: kryo5
      host: ${redis.host:localhost}
      port: ${redis.port:6379}
```

---

## Example 9: Testing JetCache Behavior

```java
@SpringBootTest
class ProductCatalogServiceJetCacheTest {

    @Autowired
    private ProductCatalogService service;

    @SpyBean
    private ProductRepository productRepository;

    @Test
    void shouldCacheWithBothTypeAndAutoRefresh() {
        Product product = new Product(1L, "Widget", BigDecimal.TEN);
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));

        // First call — both local and remote miss, DB invoked
        Product result1 = service.getProduct(1L);
        verify(productRepository, times(1)).findById(1L);

        // Second call — local hit, DB skipped
        Product result2 = service.getProduct(1L);
        verify(productRepository, times(1)).findById(1L); // still 1x
        assertThat(result2).isEqualTo(result1);
    }

    @Test
    void shouldInvalidateOnDelete() {
        Product product = new Product(1L, "Widget", BigDecimal.TEN);
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));

        // Populate cache
        service.getProduct(1L);

        // Invalidate via delete
        service.deleteProduct(1L);

        // Next call — cache miss, DB invoked
        when(productRepository.findById(1L)).thenReturn(Optional.empty());
        Product result = service.getProduct(1L);
        assertThat(result).isNull();
        verify(productRepository, times(2)).findById(1L);
    }
}

## See Also

- [`jetcache-annotation-reference.md`](jetcache-annotation-reference.md): Complete annotation parameter tables
- [`jetcache-configuration-reference.md`](jetcache-configuration-reference.md): YAML configuration reference
- [`jetcache-api-reference.md`](jetcache-api-reference.md): Cache API, QuickConfig builder
- [`redis-utils.md`](redis-utils.md): RedisUtils utility class (direct Redis operations for non-caching scenarios)
- [`distributed-lock-utils.md`](distributed-lock-utils.md): DistributedLockUtils utility class (reentrant lock, read-write lock)
```