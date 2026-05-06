# DistributedLockUtils

基于 Redisson `RLock` 的分布式锁工具类。

## DistributedLockUtils

```java
@Component
@RequiredArgsConstructor
public class DistributedLockUtils {

    private final RedissonClient redissonClient;

    /**
     * 加锁并执行，自动释放
     * leaseTime 到期自动释放，防止业务异常导致死锁
     */
    public <T> T executeWithLock(String lockKey, long leaseTime, TimeUnit unit, Supplier<T> action) {
        RLock lock = redissonClient.getLock(lockKey);
        lock.lock(leaseTime, unit);
        try {
            return action.get();
        } finally {
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }

    public void executeWithLock(String lockKey, long leaseTime, TimeUnit unit, Runnable action) {
        executeWithLock(lockKey, leaseTime, unit, () -> {
            action.run();
            return null;
        });
    }

    /**
     * 尝试获取锁，获取失败立即返回 false
     */
    public boolean tryLock(String lockKey, long leaseTime, TimeUnit unit) {
        RLock lock = redissonClient.getLock(lockKey);
        try {
            return lock.tryLock(0, leaseTime, unit);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }

    /**
     * 尝试获取锁（带等待时间），获取成功执行 action
     */
    public <T> Optional<T> tryLockAndExecute(String lockKey, long waitTime, long leaseTime,
                                              TimeUnit unit, Supplier<T> action) {
        RLock lock = redissonClient.getLock(lockKey);
        try {
            if (!lock.tryLock(waitTime, leaseTime, unit)) {
                return Optional.empty();
            }
            try {
                return Optional.ofNullable(action.get());
            } finally {
                if (lock.isHeldByCurrentThread()) {
                    lock.unlock();
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return Optional.empty();
        }
    }

    /**
     * 读写锁 — 读操作（共享）
     */
    public <T> T executeWithReadLock(String lockKey, long leaseTime, TimeUnit unit, Supplier<T> action) {
        RReadWriteLock rwLock = redissonClient.getReadWriteLock(lockKey);
        RLock readLock = rwLock.readLock();
        readLock.lock(leaseTime, unit);
        try {
            return action.get();
        } finally {
            if (readLock.isHeldByCurrentThread()) {
                readLock.unlock();
            }
        }
    }

    /**
     * 读写锁 — 写操作（独占）
     */
    public <T> T executeWithWriteLock(String lockKey, long leaseTime, TimeUnit unit, Supplier<T> action) {
        RReadWriteLock rwLock = redissonClient.getReadWriteLock(lockKey);
        RLock writeLock = rwLock.writeLock();
        writeLock.lock(leaseTime, unit);
        try {
            return action.get();
        } finally {
            if (writeLock.isHeldByCurrentThread()) {
                writeLock.unlock();
            }
        }
    }
}
```

## 使用示例

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final DistributedLockUtils lockUtils;

    // 加锁执行，30s 超时自动释放
    public Order createOrder(CreateOrderRequest req) {
        return lockUtils.executeWithLock(
            "order:create:" + req.getUserId(), 30, TimeUnit.SECONDS,
            () -> doCreateOrder(req)
        );
    }

    // 尝试获取锁，失败直接返回（幂等场景）
    public boolean processPayment(Long orderId) {
        return lockUtils.tryLock("payment:" + orderId, 60, TimeUnit.SECONDS);
    }

    // 读写锁：高并发读 + 低频写
    public ProductStock getStock(Long productId) {
        return lockUtils.executeWithReadLock(
            "stock:rw:" + productId, 5, TimeUnit.SECONDS,
            () -> stockRepository.findById(productId).orElseThrow()
        );
    }

    public void deductStock(Long productId, int quantity) {
        lockUtils.executeWithWriteLock(
            "stock:rw:" + productId, 10, TimeUnit.SECONDS,
            () -> stockRepository.deduct(productId, quantity)
        );
    }
}
```

## 选型指南

| 场景 | 方法 |
|------|------|
| 必须执行，不允许并发 | `executeWithLock` |
| 幂等操作，已有锁则跳过 | `tryLock` |
| 等待一段时间再放弃 | `tryLockAndExecute` |
| 高并发读 + 低频写 | `executeWithReadLock` / `executeWithWriteLock` |

> 简单缓存场景可用 JetCache `cache.tryLockAndRun()`，复杂业务锁用 `DistributedLockUtils`。
