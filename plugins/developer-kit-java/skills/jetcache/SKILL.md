---
name: jetcache
description: "JetCache 二级缓存 + Redisson 分布式服务: Caffeine LOCAL + Redisson REMOTE (@Cached/@CacheInvalidate/@CacheUpdate), QuickConfig, syncLocal, auto refresh, penetration protect, RLock 分布式锁, RTopic Pub/Sub, RRateLimiter 限流, RedisUtils, DistributedLockUtils。Spring Boot 3.x Redis / spring-data-redis 一站式 skill，所有组件共用 Redisson 连接池。触发词: redis, spring-data-redis, RedisTemplate, 缓存, 分布式锁, JetCache, Redisson。"
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# JetCache + Redisson 二级缓存与分布式服务

JetCache 二级缓存（Caffeine LOCAL + Redisson REMOTE）与 Redisson 分布式服务，共用一个 Redisson 连接池。

```
redisson-spring-boot-starter
    └── RedissonClient            ──→ 分布式锁 (RLock)、Pub/Sub (RTopic)、限流 (RRateLimiter)
    └── RedissonConnectionFactory ──→ RedisTemplate (Spring Data Redis)
    └── JetCache remote           ──→ jetcache-starter-redis-redisson
三者共用同一个 Redisson 连接池，只需配置一次 spring.data.redis.*
```

## When to Use

- 给 Service 方法添加声明式缓存 (`@Cached`, `@CacheUpdate`, `@CacheInvalidate`)
- 配置 Caffeine + Redisson 二级缓存，设置 TTL、area、syncLocal 策略
- 使用 `QuickConfig` 创建编程式 Cache 实例
- 使用 `@CacheRefresh` 防缓存雪崩，`@CachePenetrationProtect` 防缓存穿透
- 实现 Redisson 分布式锁（RLock、RReadWriteLock）
- 使用 `RedisUtils` / `DistributedLockUtils` 工具类简化操作

## When NOT to Use

- 持久化消息队列 → `spring-kafka`
- API 网关级限流 → `spring-cloud-gateway`

## Related Skills

- MyBatis-Plus 数据访问 → `mybatis-plus-patterns`
- Kafka 消息 → `spring-kafka`

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

## @Cached — 声明式缓存

```java
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserEntity> implements UserService {

    @Cached(name = "user:", key = "#userId", expire = 3600,
            cacheType = CacheType.BOTH, localExpire = 300,
            localLimit = 50, cacheNullValue = true)
    @CachePenetrationProtect
    @CacheRefresh(refresh = 1800, stopRefreshAfterLastAccess = 3600)
    @Override
    public UserEntity getUserById(Long userId) {
        return getById(userId);
    }

    @CacheUpdate(name = "user:", key = "#user.id", value = "#user")
    @Override
    public void updateUser(UserEntity user) {
        updateById(user);
    }

    @CacheInvalidate(name = "user:", key = "#userId")
    @Override
    public void deleteUser(Long userId) {
        removeById(userId);
    }
}
```

### @Cached 核心属性

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `name` | 自动生成 | 缓存唯一名称，也是远程缓存 key 前缀 |
| `key` | 自动生成 | SpEL 表达式指定 key |
| `expire` | 无穷大 | 超时时间（**必须显式设置**） |
| `cacheType` | REMOTE | `REMOTE` / `LOCAL` / `BOTH` |
| `localExpire` | 未定义 | 本地缓存独立 TTL（仅 BOTH，应 < expire） |
| `localLimit` | 100 | 本地缓存最大元素数 |
| `cacheNullValue` | false | 是否缓存 null 返回值 |

> @CacheUpdate / @CacheInvalidate 的 `area` 和 `name` 必须与 @Cached 完全一致！

## QuickConfig (编程式缓存)

```java
@Service
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderEntity> implements OrderService {

    private Cache<Long, OrderEntity> orderCache;

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
    public OrderEntity getOrder(Long orderId) {
        return orderCache.computeIfAbsent(orderId, id -> getById(id));
    }

    @Override
    public void updateOrder(OrderEntity order) {
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

## syncLocal (多实例本地缓存一致性)

```yaml
jetcache:
  remote:
    default:
      broadcastChannel: myProjectChannel  # 必须配置才能启用 syncLocal
```

```java
QuickConfig qc = QuickConfig.newBuilder("user:")
    .cacheType(CacheType.BOTH)
    .syncLocal(true)
    .build();
```

## Best Practices

- **缓存用 JetCache @Cached**，不要用 RedisTemplate 或 @Cacheable
- **BOTH 二级缓存时 localExpire < expire**
- **总是设置 expire**，JetCache 默认无穷大
- **远程缓存 valueEncoder 推荐 kryo5**
- **分布式锁优先用 DistributedLockUtils**，unlock 在 finally 中调用
- **多实例部署必须配置 broadcastChannel + syncLocal(true)**
- **编译参数加 -parameters**，否则 SpEL 参数名引用不生效

## Gotchas

- 使用 @Cacheable 而非 @Cached — 始终使用 @Cached
- 忘记设置 expire — JetCache 默认无穷大，必须显式设置
- @CacheInvalidate/@CacheUpdate 的 area/name 与 @Cached 不一致 — 必须完全匹配
- 使用 @CreateCache — 2.7+ 已废弃，改用 QuickConfig
- BOTH 未设 broadcastChannel — syncLocal 无效
- 自调用绕过代理 — 注入 service 或通过接口调用

## References

- [`references/jetcache-annotation-reference.md`](references/jetcache-annotation-reference.md): @Cached, @CacheInvalidate, @CacheUpdate, @CacheRefresh, @CachePenetrationProtect 完整参数表
- [`references/jetcache-configuration-reference.md`](references/jetcache-configuration-reference.md): YAML 配置参考、Redisson 连接配置
- [`references/jetcache-examples.md`](references/jetcache-examples.md): 渐进式示例与测试
- [`references/jetcache-api-reference.md`](references/jetcache-api-reference.md): Cache API、QuickConfig builder、分布式锁 API
- [`references/redis-utils.md`](references/redis-utils.md): RedisUtils 工具类（String/Hash/List/Set/ZSet/过期）
- [`references/distributed-lock-utils.md`](references/distributed-lock-utils.md): DistributedLockUtils 工具类（可重入锁、读写锁、tryLock）

## Keywords

jetcache, caffeine, redisson, @Cached, @CacheInvalidate, @CacheUpdate, CacheType.BOTH, QuickConfig, syncLocal, @CacheRefresh, @CachePenetrationProtect, RLock, RReadWriteLock, RRateLimiter, RTopic, RedissonClient, RedisTemplate, RedisUtils, DistributedLockUtils
