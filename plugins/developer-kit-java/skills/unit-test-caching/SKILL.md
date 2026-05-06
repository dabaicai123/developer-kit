---
name: unit-test-caching
description: "Provides patterns for unit testing Spring Cache annotations (@Cacheable, @CachePut, @CacheEvict). Generates test code that mocks cache managers, verifies cache hit/miss behavior, tests cache key generation with SpEL expressions, validates eviction strategies, and checks conditional caching scenarios. Triggers: caching tests, test Spring cache, mock cache, Spring Boot caching, cache hit/miss verification, @Cacheable testing."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Unit Testing Spring Caching

## Overview

This skill provides patterns for unit testing Spring caching annotations (`@Cacheable`, `@CacheEvict`, `@CachePut`) without full Spring context. It covers cache hits/misses, invalidation, key generation, and conditional caching using in-memory `ConcurrentMapCacheManager`.

## When to use this skill

- Writing unit tests for `@Cacheable` method behavior
- Verifying `@CacheEvict` cache invalidation works correctly
- Testing `@CachePut` cache updates
- Validating cache key generation from SpEL expressions
- Testing conditional caching with `unless`/`condition` parameters
- Mocking cache managers in fast unit tests without Redis

## Instructions

1. **Configure in-memory CacheManager**: Use `ConcurrentMapCacheManager` for tests
2. **Set up test fixtures**: Mock repository and create service instance in `@BeforeEach`
3. **Verify repository call counts**: Use `times(n)` assertions to confirm cache behavior
4. **Test cache hit**: Call method twice, verify repository called once
5. **Test cache miss**: Verify repository called on each invocation
6. **Test eviction**: After `@CacheEvict`, verify repository called again on next read
7. **Test key generation**: Verify compound keys from SpEL expressions
8. **Validate conditional caching**: Test `unless` (null results) and `condition` (parameter-based)

**Validation checkpoints:**
- Run test → If cache not working: verify `@EnableCaching` annotation present
- If proxy issues: ensure method calls go through Spring proxy (no direct `this` calls)
- If key mismatches: log actual cache key and compare with `@Cacheable(key="...")` expression

## Examples

### Maven
```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-cache</artifactId>
</dependency>
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-test</artifactId>
  <scope>test</scope>
</dependency>
```

### Gradle
```kotlin
dependencies {
  implementation("org.springframework.boot:spring-boot-starter-cache")
  testImplementation("org.springframework.boot:spring-boot-starter-test")
}
```

### Testing `@Cacheable` (Cache Hit/Miss)

> **Important**: `@Cacheable` relies on Spring AOP proxying. Creating a service with `new UserService(userRepository)` bypasses the proxy, so caching annotations are silently ignored — the repository will be called on every invocation. Always use `@Autowired` to inject the service in a Spring context so the proxy wraps caching behavior correctly.

```java
// Service
@Service
public class UserService {
  private final UserRepository userRepository;

  public UserService(UserRepository userRepository) {
    this.userRepository = userRepository;
  }

  @Cacheable("users")
  public User getUserById(Long id) {
    return userRepository.findById(id).orElse(null);
  }
}

// Test - uses Spring context so @Cacheable proxy is active
@SpringBootTest
@EnableCaching
class UserServiceCachingTest {

  @Configuration
  @EnableCaching
  static class TestConfig {
    @Bean
    CacheManager cacheManager() {
      return new ConcurrentMapCacheManager("users");
    }
  }

  @MockBean private UserRepository userRepository;
  @Autowired private UserService userService;
  @Autowired private CacheManager cacheManager;

  @Test
  void shouldCacheUserAfterFirstCall() {
    User user = new User(1L, "Alice");
    when(userRepository.findById(1L)).thenReturn(Optional.of(user));

    // First call - hits database
    User firstCall = userService.getUserById(1L);
    // Second call - hits cache (no additional repository call)
    User secondCall = userService.getUserById(1L);

    assertThat(firstCall).isEqualTo(secondCall);
    verify(userRepository, times(1)).findById(1L); // Only once due to cache
  }

  @Test
  void shouldCallRepositoryAgainAfterCacheEviction() {
    User user = new User(1L, "Alice");
    when(userRepository.findById(1L)).thenReturn(Optional.of(user));

    userService.getUserById(1L);
    userService.getUserById(1L);
    verify(userRepository, times(1)).findById(1L); // Cached after first call

    // Evict cache manually and call again
    cacheManager.getCache("users").clear();
    userService.getUserById(1L);
    verify(userRepository, times(2)).findById(1L); // Cache miss after eviction
  }
}
```

### Testing `@CacheEvict`

> **Important**: `@CacheEvict` relies on Spring AOP proxying. Creating a service with `new ProductService(productRepository)` bypasses the proxy, so eviction annotations are silently ignored. Always use `@Autowired` to inject the service in a Spring context so the proxy handles eviction correctly.

```java
// Service
@Service
public class ProductService {
  private final ProductRepository productRepository;

  public ProductService(ProductRepository productRepository) {
    this.productRepository = productRepository;
  }

  @Cacheable("products")
  public Product getProductById(Long id) {
    return productRepository.findById(id).orElse(null);
  }

  @CacheEvict("products")
  public void deleteProduct(Long id) {
    productRepository.deleteById(id);
  }
}

// Test - uses Spring context so @CacheEvict proxy is active
@SpringBootTest
@EnableCaching
class ProductCacheEvictTest {

  @Configuration
  @EnableCaching
  static class TestConfig {
    @Bean
    CacheManager cacheManager() {
      return new ConcurrentMapCacheManager("products");
    }
  }

  @MockBean private ProductRepository productRepository;
  @Autowired private ProductService productService;

  @Test
  void shouldEvictProductFromCacheWhenDeleted() {
    Product product = new Product(1L, "Laptop", 999.99);
    when(productRepository.findById(1L)).thenReturn(Optional.of(product));
    when(productRepository.findById(anyLong())).thenAnswer(i ->
      Optional.of(new Product(i.getArgument(0), "Product", 10.0)));

    productService.getProductById(1L); // Cache the product
    productService.getProductById(1L); // Cache hit - no extra repository call
    verify(productRepository, times(1)).findById(1L);

    productService.deleteProduct(1L); // Evict from cache

    // Repository called again after eviction
    productService.getProductById(1L);
    verify(productRepository, times(2)).findById(1L); // Cache miss after eviction
  }

  @Test
  void shouldClearAllEntriesWithAllEntriesTrue() {
    Product product1 = new Product(1L, "Laptop", 999.99);
    Product product2 = new Product(2L, "Mouse", 29.99);
    when(productRepository.findById(anyLong())).thenAnswer(i ->
      Optional.of(new Product(i.getArgument(0), "Product", 10.0)));

    productService.getProductById(1L);
    productService.getProductById(2L);

    // Evict all entries - @CacheEvict(allEntries = true)
    productService.clearAllProducts();

    productService.getProductById(1L);
    productService.getProductById(2L);

    verify(productRepository, times(4)).findById(anyLong());
  }
}
```

### Testing `@CachePut`

> **Important**: `@CachePut` relies on Spring AOP proxying. Creating a service with `new OrderService(orderRepository)` bypasses the proxy, so cache update annotations are silently ignored. Always use `@Autowired` to inject the service in a Spring context so the proxy handles cache updates correctly.

```java
@Service
public class OrderService {
  private final OrderRepository orderRepository;

  public OrderService(OrderRepository orderRepository) {
    this.orderRepository = orderRepository;
  }

  @Cacheable("orders")
  public Order getOrder(Long id) {
    return orderRepository.findById(id).orElse(null);
  }

  @CachePut(value = "orders", key = "#order.id")
  public Order updateOrder(Order order) {
    return orderRepository.save(order);
  }
}

// Test - uses Spring context so @CachePut proxy is active
@SpringBootTest
@EnableCaching
class OrderCachePutTest {

  @Configuration
  @EnableCaching
  static class TestConfig {
    @Bean
    CacheManager cacheManager() {
      return new ConcurrentMapCacheManager("orders");
    }
  }

  @MockBean private OrderRepository orderRepository;
  @Autowired private OrderService orderService;

  @Test
  void shouldUpdateCacheWhenOrderIsUpdated() {
    Order original = new Order(1L, "Pending", 100.0);
    Order updated = new Order(1L, "Shipped", 100.0);

    when(orderRepository.findById(1L)).thenReturn(Optional.of(original));
    when(orderRepository.save(updated)).thenReturn(updated);

    orderService.getOrder(1L); // Cache original order
    orderService.updateOrder(updated); // @CachePut updates cache

    // Next call returns updated version from cache (not repository)
    verify(orderRepository, times(1)).findById(1L); // Only initial call hit repository
  }
}
```

### Testing Conditional Caching

```java
@Service
public class DataService {
  private final DataRepository dataRepository;

  public DataService(DataRepository dataRepository) {
    this.dataRepository = dataRepository;
  }

  // Don't cache null results
  @Cacheable(value = "data", unless = "#result == null")
  public Data getData(Long id) {
    return dataRepository.findById(id).orElse(null);
  }

  // Only cache when id > 0
  @Cacheable(value = "users", condition = "#id > 0")
  public User getUser(Long id) {
    return dataRepository.findById(id).map(u -> new User(u.getId(), u.getName())).orElse(null);
  }
}

class ConditionalCachingTest {

  @Test
  void shouldNotCacheNullResults() {
    DataRepository dataRepository = mock(DataRepository.class);
    when(dataRepository.findById(999L)).thenReturn(Optional.empty());
    DataService service = new DataService(dataRepository);

    service.getData(999L);
    service.getData(999L);

    verify(dataRepository, times(2)).findById(999L); // Called twice - no caching
  }

  @Test
  void shouldNotCacheWhenConditionIsFalse() {
    DataRepository dataRepository = mock(DataRepository.class);
    when(dataRepository.findById(-1L)).thenReturn(Optional.of(new Data(-1L, "Test")));

    DataService service = new DataService(dataRepository);

    service.getUser(-1L);
    service.getUser(-1L);

    verify(dataRepository, times(2)).findById(-1L); // Condition "#id > 0" = false
  }
}
```

### Testing Cache Keys with SpEL

```java
@Service
public class InventoryService {
  private final InventoryRepository inventoryRepository;

  public InventoryService(InventoryRepository inventoryRepository) {
    this.inventoryRepository = inventoryRepository;
  }

  // Compound key: productId-warehouseId
  @Cacheable(value = "inventory", key = "#productId + '-' + #warehouseId")
  public InventoryItem getInventory(Long productId, Long warehouseId) {
    return inventoryRepository.findByProductAndWarehouse(productId, warehouseId);
  }
}

class CacheKeyTest {

  @Test
  void shouldUseCorrectCacheKeyForDifferentCombinations() {
    InventoryRepository repository = mock(InventoryRepository.class);
    InventoryItem item = new InventoryItem(1L, 1L, 100);
    when(repository.findByProductAndWarehouse(1L, 1L)).thenReturn(item);

    InventoryService service = new InventoryService(repository);

    // Same key: "1-1" - should cache
    service.getInventory(1L, 1L);
    service.getInventory(1L, 1L); // Cache hit
    verify(repository, times(1)).findByProductAndWarehouse(1L, 1L);

    // Different key: "2-1" - cache miss
    service.getInventory(2L, 1L); // Cache miss
    verify(repository, times(2)).findByProductAndWarehouse(any(), any());
  }
}
```

## Best Practices

- **Mock repository calls**: Use `verify(mock, times(n))` to assert cache behavior
- **Test both hit and miss scenarios**: Don't just test the happy path
- **Clear cache state**: Reset between tests to avoid flaky results
- **Use `ConcurrentMapCacheManager`**: Fast, no external dependencies
- **Verify eviction**: Always test that `@CacheEvict` actually invalidates cached data

## Constraints and Warnings

- **`@Cacheable` requires proxy**: Direct method calls (`this.method()`) bypass caching - use dependency injection
- **Cache key collisions**: Compound keys from SpEL must be unique per dataset
- **Null caching**: Null results are cached by default - use `unless = "#result == null"` to exclude
- **`@CachePut` always executes**: Unlike `@Cacheable`, it always runs the method
- **Memory usage**: In-memory caches grow unbounded - consider TTL for long-running tests
- **Thread safety**: `ConcurrentMapCacheManager` is thread-safe; distributed caches may require additional config

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cache not working | Verify `@EnableCaching` on test config |
| Proxy bypass | Use autowired/constructor injection, not direct `this` calls |
| Key mismatch | Log cache key with `cache.getNativeKey()` to debug SpEL |
| Flaky tests | Clear cache in `@BeforeEach` before each test |

## References

- [Spring Caching Documentation](https://docs.spring.io/spring-framework/docs/current/reference/html/integration.html#cache)
- [Cacheable Annotation](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/cache/annotation/Cacheable.html)
- [SpEL Expressions](https://docs.spring.io/spring-framework/docs/current/reference/html/core.html#expressions)
