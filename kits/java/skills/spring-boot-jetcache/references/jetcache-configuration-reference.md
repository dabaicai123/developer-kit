# JetCache Configuration Reference

Full YAML configuration reference for JetCache in Spring Boot.

## Minimal Configuration (Redis Remote Only)

```yaml
jetcache:
  statIntervalMinutes: 15
  remote:
    default:
      type: redis.redisson
      keyConvertor: fastjson2
      valueEncoder: java
      valueDecoder: java
      host: ${redis.host:localhost}
      port: ${redis.port:6379}
```

## Full Configuration (Two-Level Cache: Caffeine + Redis)

```yaml
jetcache:
  statIntervalMinutes: 15
  areaInCacheName: false
  hiddenPackages: com.company.myapp
  local:
    default:
      type: caffeine
      keyConvertor: fastjson2
      limit: 100
      expireAfterWriteInMillis: 100000
    orders:
      type: caffeine
      keyConvertor: fastjson2
      limit: 200
      expireAfterWriteInMillis: 60000
      expireAfterAccessInMillis: 30000
  remote:
    default:
      type: redis.redisson
      keyConvertor: fastjson2
      broadcastChannel: myProjectChannel
      valueEncoder: kryo5
      valueDecoder: kryo5
      host: ${redis.host:localhost}
      port: ${redis.port:6379}
    orders:
      type: redis.redisson
      keyConvertor: fastjson2
      broadcastChannel: myProjectChannel
      valueEncoder: kryo5
      valueDecoder: kryo5
      host: ${redis.host:localhost}
      port: ${redis.port:6379}
```

## Global Settings

| Property | Default | Description |
|----------|---------|-------------|
| `jetcache.statIntervalMinutes` | 0 | Statistics interval in minutes. 0 = no statistics. Recommended: 15 for production |
| `jetcache.areaInCacheName` | true (2.6-) / false (2.7+) | Whether areaName appears in remote cache key prefix. Set to `false` for new projects |
| `jetcache.hiddenPackages` | None | Package prefixes stripped from auto-generated cache names to keep names short |

## Local Area Settings (`jetcache.local.${area}.*`)

| Property | Default | Description |
|----------|---------|-------------|
| `type` | — | **Required.** Local cache type: `caffeine` or `linkedhashmap` |
| `keyConvertor` | fastjson2 | Key converter: `fastjson2` / `jackson` / `none` (LOCAL only, uses equals for comparison) |
| `limit` | 100 | Max elements per cache instance. Note: per-instance, not total across all instances |
| `expireAfterWriteInMillis` | Infinity | Write-based TTL in milliseconds |
| `expireAfterAccessInMillis` | 0 | Access-based TTL in milliseconds (JetCache 2.2+, local only). 0 = disabled |

## Remote Area Settings (`jetcache.remote.${area}.*`)

| Property | Default | Description |
|----------|---------|-------------|
| `type` | — | **Required.** Remote cache type: `redis.redisson` |
| `keyConvertor` | fastjson2 | Key converter: `fastjson2` / `jackson`. Method caching must specify a converter |
| `valueEncoder` | java | Value serialization for remote cache: `java` / `kryo` / `kryo5` (2.7+) |
| `valueDecoder` | java | Value deserialization: `java` / `kryo` / `kryo5` (2.7+) |
| `broadcastChannel` | None | Redis Pub/Sub channel for syncLocal (JetCache 2.7+). Required for multi-instance local cache invalidation |
| `expireAfterWriteInMillis` | Infinity | Write-based TTL in milliseconds |
| `host` | — | Redis host |
| `port` | — | Redis port |
| `redissonClient` | — | Reference a named RedissonClient bean (optional; defaults to auto-detected RedissonClient) |

## Area Configuration Notes

- `${area}` corresponds to the `area` attribute in `@Cached`, `@CacheInvalidate`, `@CacheUpdate`, and `QuickConfig`
- If annotation does not specify `area`, default value is `"default"`
- Each area must have both local and remote sections if you use `CacheType.BOTH` with that area
- Area name in yml (e.g., `orders`) must exactly match the `area` attribute in annotations

## Serialization Comparison

| Encoder | Performance | Readability | Size | Recommendation |
|---------|-------------|-------------|------|---------------|
| java | Slow | Poor (binary) | Large | Default, but not recommended for production |
| kryo | Fast | Poor (binary) | Small | Good for performance |
| kryo5 | Fast | Poor (binary) | Small | **Recommended** (JetCache 2.7+) |

## Key Converter Comparison

| Converter | Performance | Use Case |
|-----------|-------------|----------|
| fastjson2 | Fast | **Recommended** (JetCache 2.6.5+) |
| jackson | Moderate | Alternative if already using Jackson in project |
| fastjson | Moderate | Legacy (JetCache 2.6.5-) |
| none | Fast | LOCAL cache only; uses equals() for key comparison |

## Maven Dependencies

```xml
<!-- JetCache with Redisson -->
<dependency>
    <groupId>com.alicp.jetcache</groupId>
    <artifactId>jetcache-starter-redis-redisson</artifactId>
    <version>2.7.8</version>
</dependency>

<!-- Redisson Spring Boot Starter (default: redisson-spring-data-3x, works with all Spring Boot 3.x) -->
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson-spring-boot-starter</artifactId>
    <version>3.52.0</version>
</dependency>

<!-- Kryo5 serializer (recommended valueEncoder/valueDecoder) -->
<dependency>
    <groupId>com.alicp.jetcache</groupId>
    <artifactId>jetcache-kryo5-serializer</artifactId>
    <version>2.7.8</version>
</dependency>

<!-- Caffeine (local cache) -->
<dependency>
    <groupId>com.github.ben-manes.caffeine</groupId>
    <artifactId>caffeine</artifactId>
    <version>3.1.8</version>
</dependency>

<!-- Kryo5 (recommended value encoder/decoder) -->
<dependency>
    <groupId>com.alicp.jetcache</groupId>
    <artifactId>jetcache-kryo5-serializer</artifactId>
    <version>2.7.8</version>
</dependency>
```

## Spring Boot 3.5.x Redisson Alignment

`redisson-spring-boot-starter` defaults to `redisson-spring-data-3x` (generic Spring Boot 3.x). For precise Spring Boot 3.5.x alignment with Spring Data Redis 3.5.x, exclude it and use `redisson-spring-data-35`:

```xml
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson-spring-boot-starter</artifactId>
    <version>3.50.0</version>
    <exclusions>
        <exclusion>
            <groupId>org.redisson</groupId>
            <artifactId>redisson-spring-data-3x</artifactId>
        </exclusion>
    </exclusions>
</dependency>
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson-spring-data-35</artifactId>
    <version>3.50.0</version>
</dependency>
```

> The generic `redisson-spring-data-3x` also works with Spring Boot 3.5.x — use it if you don't need strict version alignment.

## External Resources

- [JetCache GitHub](https://github.com/alibaba/jetcache)
- [JetCache Configuration (CN)](https://github.com/alibaba/jetcache/blob/master/docs/CN/Config.md)
- [JetCache Method Cache (CN)](https://github.com/alibaba/jetcache/blob/master/docs/CN/MethodCache.md)
- [JetCache Cache API (CN)](https://github.com/alibaba/jetcache/blob/master/docs/CN/CacheAPI.md)
- [JetCache Advanced API (CN)](https://github.com/alibaba/jetcache/blob/master/docs/CN/AdvancedCacheAPI.md)

## See Also

- [`jetcache-annotation-reference.md`](jetcache-annotation-reference.md): Complete annotation parameter tables
- [`jetcache-api-reference.md`](jetcache-api-reference.md): Cache API, QuickConfig builder
- [`jetcache-examples.md`](jetcache-examples.md): Progressive examples and testing
- [`redis-utils.md`](redis-utils.md): RedisUtils utility class (direct Redis operations for non-caching scenarios)
- [`distributed-lock-utils.md`](distributed-lock-utils.md): DistributedLockUtils utility class (reentrant lock, read-write lock)