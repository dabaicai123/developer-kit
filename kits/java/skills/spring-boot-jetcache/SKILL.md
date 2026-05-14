---
name: spring-boot-jetcache
description: "JetCache two-level caching (Caffeine LOCAL + Redisson REMOTE) and Redisson distributed lock with @Cached/@CacheInvalidate, QuickConfig, RLock, and syncLocal. Use when adding declarative caching, configuring distributed locks, or setting up two-level cache in Spring Boot."
version: "1.1.0"
---

# JetCache + Redisson Two-Level Cache and Distributed Services

```
redisson-spring-boot-starter
    └── RedissonClient            ──→ Distributed lock (RLock), Pub/Sub (RTopic), Rate limiting (RRateLimiter)
    └── RedissonConnectionFactory ──→ RedisTemplate (Spring Data Redis)
    └── JetCache remote           ──→ jetcache-starter-redis-redisson
```

## When to use this skill

- Add declarative caching to Service methods (`@Cached`, `@CacheUpdate`, `@CacheInvalidate`)
- Configure Caffeine + Redisson two-level cache, set TTL, area, syncLocal strategies
- Create programmatic Cache instances using `QuickConfig`
- Use `@CacheRefresh` to prevent cache stampede (refreshes before expiry), `@CachePenetrationProtect` for single-JVM concurrent load protection
- Use `cacheNullValue=true` to prevent cache penetration (queries for non-existent keys hitting DB)
- Implement Redisson distributed locks (RLock, RReadWriteLock)
- Use `RedisUtils` / `DistributedLockUtils` utility classes to simplify operations

## When NOT to Use

- Persistent message queue → `spring-kafka`
- API gateway-level rate limiting → `spring-cloud-gateway`

## Related Skills

`spring-boot-transaction-management`, `spring-boot-async-processing`, `spring-boot-resilience4j`, `spring-boot-actuator`, `mybatis-plus-patterns`

## Dependencies

```xml
<!-- JetCache with Redisson remote cache -->
<dependency>
    <groupId>com.alicp.jetcache</groupId>
    <artifactId>jetcache-starter-redis-redisson</artifactId>
    <version>2.7.8</version>
</dependency>
<!-- Redisson Spring Boot Starter (use redisson-spring-data-35 for Spring Boot 3.5.x) -->
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson-spring-boot-starter</artifactId>
    <version>3.52.0</version>
</dependency>
<!-- Kryo5 serializer (recommended for remote valueEncoder/valueDecoder) -->
<dependency>
    <groupId>com.alicp.jetcache</groupId>
    <artifactId>jetcache-kryo5-serializer</artifactId>
    <version>2.7.8</version>
</dependency>
```

> **Spring Boot 3.5.x alignment**: `redisson-spring-boot-starter` 3.52.0 ships with `redisson-spring-data-3x` (generic Spring Boot 3.x). For precise Spring Boot 3.5.x alignment, exclude it and use `redisson-spring-data-35`:
> ```xml
> <dependency>
>     <groupId>org.redisson</groupId>
>     <artifactId>redisson-spring-boot-starter</artifactId>
>     <version>3.50.0</version>
>     <exclusions>
>         <exclusion>
>             <groupId>org.redisson</groupId>
>             <artifactId>redisson-spring-data-3x</artifactId>
>         </exclusion>
>     </exclusions>
> </dependency>
> <dependency>
>     <groupId>org.redisson</groupId>
>     <artifactId>redisson-spring-data-35</artifactId>
>     <version>3.50.0</version>
> </dependency>
> ```

## application.yml

```yaml
spring:
  data:
    redis:
      timeout: 5000ms
      redisson:
        config: '{"singleServerConfig":{"address":"redis://localhost:6379","database":0}}'

jetcache:
  statIntervalMinutes: 15
  areaInCacheName: false
  local:
    default:
      type: caffeine
      keyConvertor: fastjson2
      limit: 100
      expireAfterWriteInMillis: 100000
  remote:
    default:
      type: redisson
      keyConvertor: fastjson2
      broadcastChannel: projectA
      valueEncoder: kryo5
      valueDecoder: kryo5
```

## Enable JetCache

```java
@SpringBootApplication
@EnableMethodCache(basePackages = "com.company.mypackage")
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

## @Cached — Declarative Caching

```java
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {

    @Cached(name = "user:", key = "#userId", expire = 3600,
            cacheType = CacheType.BOTH, localExpire = 300,
            localLimit = 50, cacheNullValue = true)
    @CachePenetrationProtect
    @CacheRefresh(refresh = 1800, stopRefreshAfterLastAccess = 3600)
    @Override
    public UserDO getUserById(Long userId) {
        return getById(userId);
    }

    @CacheUpdate(name = "user:", key = "#user.id", value = "#user")
    @Override
    public void updateUser(UserDO user) {
        updateById(user);
    }

    @CacheInvalidate(name = "user:", key = "#userId")
    @Override
    public void deleteUser(Long userId) {
        removeById(userId);
    }
}
```

### @Cached Core Attributes

| Attribute | Default | Description |
|------|--------|------|
| `name` | Auto-generated | Unique cache name, also serves as remote cache key prefix |
| `key` | Auto-generated | SpEL expression for cache key |
| `expire` | Infinity | TTL (**must be explicitly set**) |
| `cacheType` | REMOTE | `REMOTE` / `LOCAL` / `BOTH` |
| `localExpire` | Undefined | Separate TTL for local cache (BOTH only, should be < expire) |
| `localLimit` | 100 | Max elements in local cache |
| `cacheNullValue` | false | Whether to cache null return values |

> The `area` and `name` of @CacheUpdate / @CacheInvalidate must exactly match @Cached!

## QuickConfig (Programmatic Caching)

```java
@Service
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    private Cache<Long, OrderDO> orderCache;
    private final CacheManager cacheManager;

    public OrderServiceImpl(CacheManager cacheManager) {
        this.cacheManager = cacheManager;
    }

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

    public OrderDO getOrder(Long orderId) {
        return orderCache.computeIfAbsent(orderId, id -> getById(id));
    }

    public void updateOrder(OrderDO order) {
        updateById(order);
        orderCache.put(order.getId(), order);
    }
}
```

## syncLocal (Multi-Instance Local Cache Consistency)

```yaml
jetcache:
  remote:
    default:
      broadcastChannel: myProjectChannel  # Must be configured to enable syncLocal
```

```java
QuickConfig qc = QuickConfig.newBuilder("user:")
    .cacheType(CacheType.BOTH)
    .syncLocal(true)
    .build();
```

## Gotchas

- Use @Cached (not @Cacheable or RedisTemplate)
- Add -parameters compiler flag for SpEL
- Prefer DistributedLockUtils (see references/distributed-lock-utils.md)
- Use kryo5 for remote valueEncoder
- Multi-instance: configure broadcastChannel + syncLocal(true)
- Forgetting to set expire — JetCache defaults to infinity, must be explicitly set
- @CacheInvalidate/@CacheUpdate area/name not matching @Cached — must exactly match
- Using @CreateCache — deprecated in 2.7+, use QuickConfig instead
- BOTH without broadcastChannel — syncLocal won't work

## References

- [`references/jetcache-annotation-reference.md`](references/jetcache-annotation-reference.md): Complete parameter tables for @Cached, @CacheInvalidate, @CacheUpdate, @CacheRefresh, @CachePenetrationProtect
- [`references/jetcache-configuration-reference.md`](references/jetcache-configuration-reference.md): YAML configuration reference, Redisson connection configuration
- [`references/jetcache-examples.md`](references/jetcache-examples.md): Progressive examples and testing
- [`references/jetcache-api-reference.md`](references/jetcache-api-reference.md): Cache API, QuickConfig builder, distributed lock API
- [`references/redis-utils.md`](references/redis-utils.md): RedisUtils utility class (String/Hash/List/Set/ZSet/expiry)
- [`references/distributed-lock-utils.md`](references/distributed-lock-utils.md): DistributedLockUtils utility class (reentrant lock, read-write lock, tryLock)