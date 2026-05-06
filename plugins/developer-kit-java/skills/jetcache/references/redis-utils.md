# RedisUtils

基于 `RedisTemplate<Object, Object>` 的常用操作工具类。

## RedissonConfiguration

```java
@Configuration
public class RedissonConfiguration {

    @Bean
    public RedisTemplate<Object, Object> redisTemplate(RedisConnectionFactory redisConnectionFactory) {
        RedisTemplate<Object, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(redisConnectionFactory);
        template.setKeySerializer(StringRedisSerializer.UTF_8);
        template.setHashKeySerializer(StringRedisSerializer.UTF_8);
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());
        return template;
    }

    @Bean
    public StringRedisTemplate stringRedisTemplate(RedisConnectionFactory redisConnectionFactory) {
        StringRedisTemplate template = new StringRedisTemplate();
        template.setConnectionFactory(redisConnectionFactory);
        return template;
    }
}
```

## RedisUtils

```java
@Component
@RequiredArgsConstructor
public class RedisUtils {

    private final RedisTemplate<Object, Object> redisTemplate;

    // ── 过期 ──────────────────────────────────────────────────────────────

    public boolean expire(String key, long timeout, TimeUnit unit) {
        return Boolean.TRUE.equals(redisTemplate.expire(key, timeout, unit));
    }

    public long getExpire(String key) {
        Long expire = redisTemplate.getExpire(key, TimeUnit.SECONDS);
        return expire == null ? -2 : expire;
    }

    public boolean hasKey(String key) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(key));
    }

    public void del(String... keys) {
        redisTemplate.delete(Arrays.asList(keys));
    }

    // ── String ────────────────────────────────────────────────────────────

    public Object get(String key) {
        return redisTemplate.opsForValue().get(key);
    }

    public void set(String key, Object value) {
        redisTemplate.opsForValue().set(key, value);
    }

    public void set(String key, Object value, long timeout, TimeUnit unit) {
        redisTemplate.opsForValue().set(key, value, timeout, unit);
    }

    public boolean setIfAbsent(String key, Object value, long timeout, TimeUnit unit) {
        return Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(key, value, timeout, unit));
    }

    public long incr(String key) {
        Long val = redisTemplate.opsForValue().increment(key);
        return val == null ? 0 : val;
    }

    public long incrBy(String key, long delta) {
        Long val = redisTemplate.opsForValue().increment(key, delta);
        return val == null ? 0 : val;
    }

    // ── Hash ──────────────────────────────────────────────────────────────

    public Object hGet(String key, String field) {
        return redisTemplate.opsForHash().get(key, field);
    }

    public Map<Object, Object> hGetAll(String key) {
        return redisTemplate.opsForHash().entries(key);
    }

    public void hSet(String key, String field, Object value) {
        redisTemplate.opsForHash().put(key, field, value);
    }

    public void hSetAll(String key, Map<String, Object> map) {
        redisTemplate.opsForHash().putAll(key, map);
    }

    public void hDel(String key, String... fields) {
        redisTemplate.opsForHash().delete(key, (Object[]) fields);
    }

    public boolean hHasKey(String key, String field) {
        return redisTemplate.opsForHash().hasKey(key, field);
    }

    // ── List ──────────────────────────────────────────────────────────────

    public List<Object> lRange(String key, long start, long end) {
        return redisTemplate.opsForList().range(key, start, end);
    }

    public long lSize(String key) {
        Long size = redisTemplate.opsForList().size(key);
        return size == null ? 0 : size;
    }

    public void lRightPush(String key, Object value) {
        redisTemplate.opsForList().rightPush(key, value);
    }

    public Object lLeftPop(String key) {
        return redisTemplate.opsForList().leftPop(key);
    }

    // ── Set ───────────────────────────────────────────────────────────────

    public Set<Object> sMembers(String key) {
        return redisTemplate.opsForSet().members(key);
    }

    public boolean sIsMember(String key, Object value) {
        return Boolean.TRUE.equals(redisTemplate.opsForSet().isMember(key, value));
    }

    public void sAdd(String key, Object... values) {
        redisTemplate.opsForSet().add(key, values);
    }

    public void sRemove(String key, Object... values) {
        redisTemplate.opsForSet().remove(key, values);
    }

    // ── ZSet ──────────────────────────────────────────────────────────────

    public void zAdd(String key, Object value, double score) {
        redisTemplate.opsForZSet().add(key, value, score);
    }

    public Set<Object> zRange(String key, long start, long end) {
        return redisTemplate.opsForZSet().range(key, start, end);
    }

    /** 按分数从高到低取 TopN */
    public Set<Object> zReverseRange(String key, long start, long end) {
        return redisTemplate.opsForZSet().reverseRange(key, start, end);
    }

    public Double zScore(String key, Object value) {
        return redisTemplate.opsForZSet().score(key, value);
    }

    public void zRemove(String key, Object... values) {
        redisTemplate.opsForZSet().remove(key, values);
    }
}
```

## 使用示例

```java
@Service
@RequiredArgsConstructor
public class TokenService {

    private final RedisUtils redisUtils;

    public void saveToken(String userId, String token) {
        redisUtils.set("token:" + userId, token, 7, TimeUnit.DAYS);
    }

    public String getToken(String userId) {
        Object val = redisUtils.get("token:" + userId);
        return val == null ? null : val.toString();
    }

    public void removeToken(String userId) {
        redisUtils.del("token:" + userId);
    }
}
```

> 缓存操作用 JetCache @Cached，RedisUtils 仅用于非缓存场景（Token、计数器、临时数据等）。
