# JetCache API Reference

Complete reference for JetCache Cache interface, QuickConfig builder, and advanced features.

## Cache Interface Methods

### Standard (Lowercase) API

| Method | Description |
|--------|-------------|
| `V get(K key)` | Get cached value. Returns null on miss |
| `void put(K key, V value)` | Put value into cache |
| `void put(K key, V value, long expireAfterWrite, TimeUnit timeUnit)` | Put with custom TTL (overrides default) |
| `boolean putIfAbsent(K key, V value)` | Put only if key does not exist. Returns true if put succeeded |
| `boolean remove(K key)` | Remove cached entry. Returns true if entry existed |
| `Map<K,V> getAll(Set<? extends K> keys)` | Get multiple values. Missing keys return null in the map |
| `void putAll(Map<? extends K,? extends V> map)` | Put multiple entries |
| `void removeAll(Set<? extends K> keys)` | Remove multiple entries |

### ComputeIfAbsent API

| Method | Description |
|--------|-------------|
| `V computeIfAbsent(K key, Function<K,V> loader)` | Get or load. On miss, calls loader and caches result |
| `V computeIfAbsent(K key, Function<K,V> loader, boolean cacheNullWhenLoaderReturnNull)` | Same with null caching control |
| `V computeIfAbsent(K key, Function<K,V> loader, boolean cacheNullWhenLoaderReturnNull, long expireAfterWrite, TimeUnit timeUnit)` | Same with custom TTL |

> `computeIfAbsent` is the recommended pattern for read-through caching. It combines cache lookup + loader invocation + cache write in a single call.

### Uppercase (Result) API

Returns `CacheGetResult`, `CacheResult`, or `MultiGetResult` with full status information. Supports async access.

| Method | Return Type | Description |
|--------|-------------|-------------|
| `CacheGetResult<V> GET(K key)` | CacheGetResult | Get with detailed result (success, miss, null-value, error) |
| `MultiGetResult<K,V> GET_ALL(Set<? extends K> keys)` | MultiGetResult | Batch get with per-key results |
| `CacheResult PUT(K key, V value)` | CacheResult | Put with result status |
| `CacheResult PUT(K key, V value, long expireAfterWrite, TimeUnit timeUnit)` | CacheResult | Put with TTL |
| `CacheResult PUT_ALL(Map<? extends K,? extends V> map)` | CacheResult | Batch put |
| `CacheResult PUT_ALL(Map<? extends K,? extends V> map, long expireAfterWrite, TimeUnit timeUnit)` | CacheResult | Batch put with TTL |
| `CacheResult REMOVE(K key)` | CacheResult | Remove with result |
| `CacheResult REMOVE_ALL(Set<? extends K> keys)` | CacheResult | Batch remove |
| `CacheResult PUT_IF_ABSENT(K key, V value, long expireAfterWrite, TimeUnit timeUnit)` | CacheResult | Conditional put |

### Result Object Details

```java
CacheGetResult<V> result = cache.GET(key);

result.isSuccess();    // true if cache hit (including null-value hit)
result.getValue();     // cached value (null if cacheNullValue=true and stored null)
result.isNullValue();  // true if this was a null-value cache hit
result.getResultCode(); // SUCCESS, NOT_FOUND, EXPIRED, ERROR, PARTIAL_SUCCESS
result.future();       // CompletableFuture for async access
```

### Async Access Pattern

```java
// Async GET with callback
cache.GET(key).future().thenAccept(result -> {
    if (result.isSuccess()) {
        processValue(result.getValue());
    }
});

// Async PUT
cache.PUT(key, value).future().thenAccept(result -> {
    if (result.isSuccess()) {
        log.info("Cache PUT succeeded");
    }
});

// Note: Redisson-based setups have limited async Cache API support.
```

## Distributed Lock API

| Method | Description |
|--------|-------------|
| `AutoReleaseLock tryLock(K key, long expire, TimeUnit timeUnit)` | Acquire distributed lock on cache key. Returns lock object (auto-release on close) |
| `boolean tryLockAndRun(K key, long expire, TimeUnit timeUnit, Runnable action)` | Try lock and execute action. Returns true if lock acquired and action executed |

```java
// Pattern 1: tryLock with manual release
AutoReleaseLock lock = cache.tryLock("order:123", 10, TimeUnit.SECONDS);
if (lock != null) {
    try {
        // Exclusive access for 10 seconds
        processOrder(orderId);
    } finally {
        lock.close(); // Auto-release
    }
}

// Pattern 2: tryLockAndRun (simpler)
boolean executed = cache.tryLockAndRun("order:123", 10, TimeUnit.SECONDS, () -> {
    processOrder(orderId);
});
```

## QuickConfig Builder (JetCache 2.7+)

```java
QuickConfig qc = QuickConfig.newBuilder("cacheName:")
    .expire(Duration.ofSeconds(3600))           // Remote TTL
    .localExpire(Duration.ofSeconds(300))       // Local TTL (BOTH only)
    .cacheType(CacheType.BOTH)                  // LOCAL / REMOTE / BOTH
    .localLimit(50)                             // Max local elements
    .syncLocal(true)                            // Enable multi-instance sync
    .keyConvertor(KeyConvertor.FASTJSON2)       // Key converter (recommended for JetCache 2.7+)
    .serialPolicy(SerialPolicy.KRYO5)           // Value serialization (recommended)
    .area("default")                            // Cache area
    .cacheNullValue(true)                       // Cache null returns
    .penetrationProtect(true)                   // Enable penetration protect
    .refreshPolicy(RefreshPolicy.newPolicy(
        Duration.ofSeconds(1800),
        Duration.ofSeconds(7200)))              // Auto refresh
    .build();

Cache<String, Order> cache = cacheManager.getOrCreateCache(qc);
```

### QuickConfig Builder Methods

| Method | Type | Description |
|--------|------|-------------|
| `newBuilder(String name)` | static | Create builder with cache name prefix |
| `expire(Duration)` | builder | Remote cache TTL |
| `localExpire(Duration)` | builder | Local cache TTL (BOTH only, should < expire) |
| `cacheType(CacheType)` | builder | Cache type: REMOTE / LOCAL / BOTH |
| `localLimit(int)` | builder | Max local cache elements |
| `syncLocal(boolean)` | builder | Enable Redis Pub/Sub invalidation for local cache across JVMs |
| `keyConvertor(KeyConvertor)` | builder | Key converter strategy |
| `serialPolicy(SerialPolicy)` | builder | Value serialization for remote |
| `area(String)` | builder | Cache area name |
| `cacheNullValue(boolean)` | builder | Cache null method returns |
| `penetrationProtect(boolean)` | builder | Single-JVM concurrent load protection |
| `refreshPolicy(RefreshPolicy)` | builder | Auto refresh configuration |

## LoadingCache (Read-Through)

```java
QuickConfig qc = QuickConfig.newBuilder("user:")
    .cacheType(CacheType.BOTH)
    .expire(Duration.ofSeconds(3600))
    .build();
Cache<Long, User> cache = cacheManager.getOrCreateCache(qc);

// Set loader programmatically
cache.config().setLoader(userId -> userRepository.findById(userId).orElse(null));

// Now lowercase get() calls loader on miss
// But uppercase GET() only reads cache, does NOT call loader
User user = cache.get(userId);         // Read-through: miss → loader → cache
CacheGetResult<User> r = cache.GET(userId); // Pure cache read: miss → NOT_FOUND
```

## RefreshCache (Auto Refresh)

```java
RefreshPolicy policy = RefreshPolicy.newPolicy(
    Duration.ofSeconds(1800),         // refresh interval
    Duration.ofSeconds(7200));        // stop after this idle time

QuickConfig qc = QuickConfig.newBuilder("catalog:")
    .cacheType(CacheType.BOTH)
    .expire(Duration.ofSeconds(3600))
    .refreshPolicy(policy)
    .build();
Cache<Long, Catalog> cache = cacheManager.getOrCreateCache(qc);

// For BOTH/REMOTE: only one server refreshes at a time via tryLock
// For LOCAL: each JVM refreshes independently
```

## Cache Statistics

JetCache automatically collects statistics when `statIntervalMinutes > 0`.

## Common Pitfalls

### Pitfall 1: Self-Invocation Bypasses Cache Proxy

```java
@Service
public class UserService {
    @Cached(name = "user:", key = "#id")
    public User getUser(Long id) { ... }

    public User getUserDetails(Long id) {
        return this.getUser(id);  // ❌ Bypasses proxy, no caching
    }
}

// Solution: Inject service or call through interface
@Service
@RequiredArgsConstructor
public class DetailsService {
    private final UserService userService;

    public User getUserDetails(Long id) {
        return userService.getUser(id);  // ✅ Uses proxy, caching works
    }
}
```

### Pitfall 2: Area/Name Mismatch

```java
// ❌ Mismatch: @Cached uses area="default", @CacheInvalidate uses area="orders"
@Cached(name = "product:", key = "#id", area = "default")
public Product getProduct(Long id) { ... }

@CacheInvalidate(name = "product:", key = "#id", area = "orders")  // Wrong area!
public void deleteProduct(Long id) { ... }

// ✅ Fix: area and name must match exactly
@CacheInvalidate(name = "product:", key = "#id", area = "default")
public void deleteProduct(Long id) { ... }
```

### Pitfall 3: SpEL Parameter Name Without -parameters

```java
// ❌ Fails if javac -parameters flag is not set
@Cached(name = "user:", key = "#userId")
public User getUser(Long userId) { ... }

// ✅ Use index notation instead
@Cached(name = "user:", key = "#args[0]")
public User getUser(Long userId) { ... }
```

### Pitfall 4: JDK Serialization in Redis

```java
// ❌ valueEncoder=java: slow, unreadable binary format
jetcache:
  remote:
    default:
      valueEncoder: java
      valueDecoder: java

// ✅ Use kryo5: fast, compact
jetcache:
  remote:
    default:
      valueEncoder: kryo5
      valueDecoder: kryo5
```

### Pitfall 5: No TTL Set

```java
// ❌ No expire set → infinite TTL → stale data forever
@Cached(name = "config:", key = "#key")
public Config getConfig(String key) { ... }

// ✅ Always set explicit TTL
@Cached(name = "config:", key = "#key", expire = 600)
public Config getConfig(String key) { ... }
```

## See Also

- [`jetcache-annotation-reference.md`](jetcache-annotation-reference.md): Complete annotation parameter tables
- [`jetcache-configuration-reference.md`](jetcache-configuration-reference.md): YAML configuration reference
- [`jetcache-examples.md`](jetcache-examples.md): Progressive examples and testing
- [`redis-utils.md`](redis-utils.md): RedisUtils utility class (direct Redis operations for non-caching scenarios)
- [`distributed-lock-utils.md`](distributed-lock-utils.md): DistributedLockUtils utility class (reentrant lock, read-write lock)