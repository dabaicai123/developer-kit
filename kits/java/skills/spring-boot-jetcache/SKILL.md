---
name: spring-boot-jetcache
description: "JetCache two-level caching (Caffeine LOCAL + Redisson REMOTE) and Redisson distributed lock with @Cached/@CacheInvalidate, QuickConfig, RLock, and syncLocal. Use when adding declarative caching, configuring distributed locks, or setting up two-level cache in Spring Boot."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# JetCache + Redisson Two-Level Cache and Distributed Services

JetCache two-level caching (Caffeine LOCAL + Redisson REMOTE) and Redisson distributed services, sharing a single Redisson connection pool.

```
redisson-spring-boot-starter
    └── RedissonClient            ──→ Distributed lock (RLock), Pub/Sub (RTopic), Rate limiting (RRateLimiter)
    └── RedissonConnectionFactory ──→ RedisTemplate (Spring Data Redis)
    └── JetCache remote           ──→ jetcache-starter-redis-redisson
All three share the same Redisson connection pool, only need to configure spring.data.redis.* once
```

## When to use this skill

- Add declarative caching to Service methods (`@Cached`, `@CacheUpdate`, `@CacheInvalidate`)
- Configure Caffeine + Redisson two-level cache, set TTL, area, syncLocal strategies
- Create programmatic Cache instances using `QuickConfig`
- Use `@CacheRefresh` to prevent cache avalanche, `@CachePenetrationProtect` to prevent cache penetration
- Implement Redisson distributed locks (RLock, RReadWriteLock)
- Use `RedisUtils` / `DistributedLockUtils` utility classes to simplify operations

## When NOT to Use

- Persistent message queue → `spring-kafka`
- API gateway-level rate limiting → `spring-cloud-gateway`

## Related Skills

- Transaction management → `spring-boot-transaction-management`
- Async processing → `spring-boot-async-processing`
- Resilience patterns → `spring-boot-resilience4j`
- Monitoring & metrics → `spring-boot-actuator`
- MyBatis-Plus data access → `mybatis-plus-patterns`

## Dependencies

```xml
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson-spring-boot-starter</artifactId>
    <version>3.52.0</version>
</dependency>
<dependency>
    <groupId>com.alicp.jetcache</groupId>
    <artifactId>jetcache-starter-redis-redisson</artifactId>
    <version>2.7.8</version>
</dependency>
```

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

    @Override
    public OrderDO getOrder(Long orderId) {
        return orderCache.computeIfAbsent(orderId, id -> getById(id));
    }

    @Override
    public void updateOrder(OrderDO order) {
        updateById(order);
        orderCache.put(order.getId(), order);
    }

    @Override
    public void removeOrder(Long orderId) {
        removeById(orderId);
        orderCache.remove(orderId);
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

## Best Practices

- **Use JetCache @Cached for caching**, not RedisTemplate or @Cacheable
- **When using BOTH two-level cache, localExpire < expire**
- **Always set expire**, JetCache defaults to infinity
- **Use kryo5 for remote cache valueEncoder**
- **Prefer DistributedLockUtils for distributed locks**, call unlock in finally block
- **Multi-instance deployment must configure broadcastChannel + syncLocal(true)**
- **Add -parameters compiler flag**, otherwise SpEL parameter name references won't work

## Gotchas

- Using @Cacheable instead of @Cached — always use @Cached
- forgetting to set expire — JetCache defaults to infinity, must be explicitly set
- @CacheInvalidate/@CacheUpdate area/name not matching @Cached — must exactly match
- Using @CreateCache — deprecated in 2.7+, use QuickConfig instead
- BOTH without broadcastChannel — syncLocal won't work
- Self-invocation bypassing proxy — inject service or call through interface

## References

- [`references/jetcache-annotation-reference.md`](references/jetcache-annotation-reference.md): Complete parameter tables for @Cached, @CacheInvalidate, @CacheUpdate, @CacheRefresh, @CachePenetrationProtect
- [`references/jetcache-configuration-reference.md`](references/jetcache-configuration-reference.md): YAML configuration reference, Redisson connection configuration
- [`references/jetcache-examples.md`](references/jetcache-examples.md): Progressive examples and testing
- [`references/jetcache-api-reference.md`](references/jetcache-api-reference.md): Cache API, QuickConfig builder, distributed lock API
- [`references/redis-utils.md`](references/redis-utils.md): RedisUtils utility class (String/Hash/List/Set/ZSet/expiry)
- [`references/distributed-lock-utils.md`](references/distributed-lock-utils.md): DistributedLockUtils utility class (reentrant lock, read-write lock, tryLock)

## Keywords

jetcache, caffeine, redisson, @Cached, @CacheInvalidate, @CacheUpdate, CacheType.BOTH, QuickConfig, syncLocal, @CacheRefresh, @CachePenetrationProtect, RLock, RReadWriteLock, RRateLimiter, RTopic, RedissonClient, RedisTemplate, RedisUtils, DistributedLockUtils