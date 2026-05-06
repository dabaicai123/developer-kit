# DistributedLockUtils

Distributed lock utility class based on Redisson `RLock`.

## DistributedLockUtils

```java
@Component
@RequiredArgsConstructor
public class DistributedLockUtils {

    private final RedissonClient redissonClient;

    /**
     * Acquire lock and execute, auto-release on completion
     * leaseTime expires automatically, preventing deadlocks from business exceptions
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
     * Try to acquire lock, return false immediately if acquisition fails
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
     * Try to acquire lock (with wait time), execute action on success
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
     * Read-write lock — read operation (shared)
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
     * Read-write lock — write operation (exclusive)
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

## Usage Examples

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final DistributedLockUtils lockUtils;

    // Lock and execute, 30s timeout auto-release
    public Order createOrder(CreateOrderRequest req) {
        return lockUtils.executeWithLock(
            "order:create:" + req.getUserId(), 30, TimeUnit.SECONDS,
            () -> doCreateOrder(req)
        );
    }

    // Try to acquire lock, return directly on failure (idempotent scenario)
    public boolean processPayment(Long orderId) {
        return lockUtils.tryLock("payment:" + orderId, 60, TimeUnit.SECONDS);
    }

    // Read-write lock: high-concurrency reads + low-frequency writes
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

## Selection Guide

| Scenario | Method |
|------|------|
| Must execute, no concurrency allowed | `executeWithLock` |
| Idempotent operation, skip if already locked | `tryLock` |
| Wait for a period before giving up | `tryLockAndExecute` |
| High-concurrency reads + low-frequency writes | `executeWithReadLock` / `executeWithWriteLock` |

> For simple caching scenarios, use JetCache `cache.tryLockAndRun()`; for complex business locks, use `DistributedLockUtils`.