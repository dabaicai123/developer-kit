# JetCache Annotation Reference

Complete annotation parameter tables for all JetCache annotations.

## @Cached

| Attribute | Default | Description |
|-----------|---------|-------------|
| `area` | "default" | Cache area name, maps to `jetcache.local.${area}` and `jetcache.remote.${area}` in yml |
| `name` | Auto-generated (className.methodName) | Unique cache name, used as remote cache key prefix. A meaningful short name improves readability in stats |
| `key` | Auto-generated from all params | SpEL expression for cache key |
| `expire` | Global config / infinity | Cache TTL |
| `timeUnit` | TimeUnit.SECONDS | Unit for expire |
| `cacheType` | CacheType.REMOTE | `REMOTE` / `LOCAL` / `BOTH` |
| `localLimit` | Global config / 100 | Max elements in local cache (LOCAL or BOTH) |
| `localExpire` | Undefined | Separate TTL for local cache (BOTH only, should be < expire) |
| `serialPolicy` | Global config / JAVA | Remote serialization: `SerialPolicy.JAVA` or `SerialPolicy.KRYO` |
| `keyConvertor` | Global config | Key conversion: `KeyConvertor.FASTJSON` or `KeyConvertor.NONE` |
| `enabled` | true | Whether caching is active. Set `enabled=false` to disable normally; use `CacheContext.enableCache()` to activate in specific callback scopes |
| `cacheNullValue` | false | Whether to cache null method returns |
| `condition` | Undefined | SpEL condition; cache is read only if expression returns true |
| `postCondition` | Undefined | SpEL condition; cache is updated only if expression returns true (can access #result) |

## @CacheInvalidate

| Attribute | Default | Description |
|-----------|---------|-------------|
| `area` | "default" | Must match the corresponding @Cached area |
| `name` | Undefined | Must match the corresponding @Cached name |
| `key` | Undefined | SpEL expression for the key to remove |
| `condition` | Undefined | SpEL condition; delete only if true (can access #result) |

## @CacheUpdate

| Attribute | Default | Description |
|-----------|---------|-------------|
| `area` | "default" | Must match the corresponding @Cached area |
| `name` | Undefined | Must match the corresponding @Cached name |
| `key` | Undefined | SpEL expression for the key |
| `value` | Undefined | SpEL expression for the value |
| `condition` | Undefined | SpEL condition; update only if true (can access #result) |

## @CacheRefresh

| Attribute | Default | Description |
|-----------|---------|-------------|
| `refresh` | Undefined | Auto-refresh interval |
| `timeUnit` | TimeUnit.SECONDS | Time unit for refresh |
| `stopRefreshAfterLastAccess` | Undefined | Stop refreshing after this duration of no access. If unspecified, refresh continues indefinitely |
| `refreshLockTimeout` | 60 seconds | Distributed lock timeout for BOTH/REMOTE refresh. Only one server refreshes at a time |

## @CachePenetrationProtect

When cache miss occurs, only one thread in the same JVM loads data for a given key; other threads wait for the result.

**Note:** This is single-JVM protection only. For cross-JVM protection, combine with `cacheNullValue=true` or use distributed `tryLock`.

## SpEL Context for Key Expressions

| Variable | Description |
|----------|-------------|
| `#<paramName>` | Method parameter by name (requires `-parameters` javac flag) |
| `#args[0]`, `#p0`, `#a0` | Method parameter by index (works without `-parameters`) |
| `#result` | Method result (available in @CacheUpdate value and @CacheInvalidate/@CacheUpdate condition) |

## TTL Priority Hierarchy

1. **Method-level TTL**: `put(key, value, expire, timeUnit)` — highest priority
2. **Annotation TTL**: `@Cached(expire=...)` or `QuickConfig.expire(...)` — second priority
3. **Global config TTL**: `jetcache.local.default.expireAfterWriteInMillis` / `jetcache.remote.default.expireAfterWriteInMillis` — third priority
4. **Default**: Infinity — if nothing is specified

## See Also

- [`jetcache-configuration-reference.md`](jetcache-configuration-reference.md): YAML 配置、序列化、连接配置
- [`jetcache-api-reference.md`](jetcache-api-reference.md): Cache API、QuickConfig builder、分布式锁 API
- [`jetcache-examples.md`](jetcache-examples.md): 渐进式示例与测试
- [`redis-utils.md`](redis-utils.md): RedisUtils 工具类（非缓存场景直接操作 Redis）
- [`distributed-lock-utils.md`](distributed-lock-utils.md): DistributedLockUtils 工具类（可重入锁、读写锁）