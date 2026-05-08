# Rollback Rules and Exceptions

Spring `@Transactional` rollback behavior, configuration, and common pitfalls.

## Default Behavior: Only Unchecked Exceptions Trigger Rollback

By default, Spring transactions **only roll back on unchecked exceptions** — `RuntimeException` and its subclasses, as well as `Error`. Checked exceptions (e.g., `IOException`, `SQLException`) **do not trigger rollback**; the transaction commits normally.

This is a common source of bugs: developers assume any exception will rollback the transaction, but checked exceptions silently commit partial changes.

```java
/**
 * ❌ 默认行为：checked exception 不触发回滚
 * <p>IOException 是 checked exception，抛出后事务仍然提交</p>
 */
@Override
@Transactional  // 默认：仅 RuntimeException 和 Error 触发回滚
public void importData(String filePath) throws IOException {
    List<DataDO> data = parseCsv(filePath);  // IOException — checked exception
    saveBatch(data);
    // 如果 parseCsv() 抛出 IOException，已插入的数据不会回滚！
}
```

## rollbackFor = Exception.class — Make Checked Exceptions Also Trigger Rollback

The recommended practice is to always specify `rollbackFor = Exception.class`, which makes all exceptions (both checked and unchecked) trigger rollback.

```java
/**
 * ✅ 正确做法：rollbackFor = Exception.class 确保所有异常触发回滚
 * <p>IOException 等 checked exception 也会导致事务回滚</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)
public void importData(String filePath) throws IOException {
    List<DataDO> data = parseCsv(filePath);  // IOException — 触发回滚
    saveBatch(data);
    // 如果 parseCsv() 抛出 IOException，所有插入的数据都会回滚
}
```

## noRollbackFor — Exclude Specific Exceptions from Rollback

Use `noRollbackFor` to exclude specific exception types from triggering rollback. This is useful when certain business exceptions should not cause the transaction to rollback (e.g., a "data already exists" warning that should still commit other changes).

**Caution**: use `noRollbackFor` sparingly — most cases should just rollback on all exceptions.

```java
/**
 * 排除特定异常不触发回滚
 * <p>DuplicateDataException 是业务上可接受的异常，事务仍然提交</p>
 */
@Override
@Transactional(rollbackFor = Exception.class, noRollbackFor = DuplicateDataException.class)
public void processBatch(List<BatchItemDTO> items) {
    for (BatchItemDTO item : items) {
        try {
            processItem(item);
        } catch (DuplicateDataException e) {
            // 重复数据是可接受的，不影响整体批次的提交
            log.info("跳过重复数据: {}", item.getId());
        }
    }
}
```

## Common Mistake: Catching Exception Inside @Transactional Method Prevents Rollback

The most critical rollback pitfall: **catching and swallowing exceptions inside a `@Transactional` method prevents rollback**. Spring's transaction proxy only sees the method's return value — if the method catches an exception and returns normally, the proxy sees success and commits the transaction.

```java
/**
 * ❌ 错误：内部 catch 异常导致事务不回滚
 * <p>Spring 代理只看方法返回值，catch 后正常返回 = 事务提交</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)
public void transferMoney(Long fromId, Long toId, BigDecimal amount) {
    AccountDO from = accountMapper.selectById(fromId);
    from.setBalance(from.getBalance().subtract(amount));
    accountMapper.updateById(from);

    AccountDO to = accountMapper.selectById(toId);
    try {
        to.setBalance(to.getBalance().add(amount));
        accountMapper.updateById(to);
    } catch (Exception e) {
        // ❌ 吞掉异常：from 账户扣款已提交，to 账户加款失败但事务仍然提交！
        log.error("转账失败", e);
    }
}

/**
 * ✅ 正确做法：让异常传播到代理层触发回滚
 * <p>不要在 @Transactional 方法内 catch 并吞掉异常</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)
public void transferMoney(Long fromId, Long toId, BigDecimal amount) {
    AccountDO from = accountMapper.selectById(fromId);
    from.setBalance(from.getBalance().subtract(amount));
    accountMapper.updateById(from);

    AccountDO to = accountMapper.selectById(toId);
    to.setBalance(to.getBalance().add(amount));
    accountMapper.updateById(to);
    // 异常自然传播到代理层 → 事务回滚，两个账户都不变更
}

/**
 * ✅ 如果必须 catch：手动标记回滚
 * <p>使用 TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)
public void transferMoney(Long fromId, Long toId, BigDecimal amount) {
    try {
        AccountDO from = accountMapper.selectById(fromId);
        from.setBalance(from.getBalance().subtract(amount));
        accountMapper.updateById(from);

        AccountDO to = accountMapper.selectById(toId);
        to.setBalance(to.getBalance().add(amount));
        accountMapper.updateById(to);
    } catch (Exception e) {
        log.error("转账失败", e);
        // ✅ 手动标记回滚，即使异常被 catch
        TransactionAspectSupport.currentTransactionStatus().setRollbackOnly();
    }
}
```

## Rollback vs Commit Flow Diagram

```
@Transactional Method Execution Flow:

    ┌─────────────────────────┐
    │   Proxy intercepts call │
    │   → Begin transaction   │
    └────────────────┬────────┘
                     │
                     ▼
    ┌─────────────────────────┐
    │  Execute method body    │
    └────────────────┬────────┘
                     │
           ┌─────────┴─────────┐
           │                   │
     Normal return         Exception thrown
           │                   │
           ▼                   ▼
    ┌─────────────┐  ┌──────────────────────────────┐
    │   COMMIT    │  │ Check rollback rules:        │
    │             │  │                              │
    │             │  │ RuntimeException/Error?      │
    │             │  │   → ROLLBACK (always)        │
    │             │  │                              │
    │             │  │ Checked exception (IOException)? │
    │             │  │   rollbackFor=Exception?     │
    │             │  │     YES → ROLLBACK            │
    │             │  │     NO  → COMMIT (danger!)   │
    │             │  │                              │
    │             │  │ noRollbackFor match?         │
    │             │  │   YES → COMMIT               │
    │             │  │   NO  → proceed to rollback  │
    │             │  │                              │
    │             │  │ Exception caught & swallowed? │
    │             │  │   → COMMIT (proxy sees normal return) │
    └─────────────┘  └──────────────────────────────┘

Key Rules:
1. Unchecked (RuntimeException, Error) → always rollback (default)
2. Checked exceptions → NO rollback by default; use rollbackFor = Exception.class
3. noRollbackFor → overrides rollbackFor for specific types
4. Caught & swallowed → COMMIT (proxy cannot see the exception)
5. setRollbackOnly() → force rollback even if exception is caught
```

## Rollback Rule Configuration Examples

### Standard: rollback all exceptions

```java
@Transactional(rollbackFor = Exception.class)
```

### Specific: rollback only on custom business exceptions

```java
@Transactional(rollbackFor = {BusinessException.class, IOException.class})
```

### Exclude: rollback all except specific types

```java
@Transactional(rollbackFor = Exception.class, noRollbackFor = DuplicateDataException.class)
```

### Read-only with full rollback coverage

```java
@Transactional(readOnly = true, rollbackFor = Exception.class)
```

### Timeout + rollback (prevent stuck transactions)

```java
@Transactional(rollbackFor = Exception.class, timeout = 30)
```

## Quick Reference: Exception Rollback Matrix

| Exception Type | Default Behavior | With `rollbackFor=Exception.class` | With `noRollbackFor=X.class` |
|---|---|---|---|
| RuntimeException | ROLLBACK | ROLLBACK | ROLLBACK (unless X matches) |
| Error | ROLLBACK | ROLLBACK | ROLLBACK (unless X matches) |
| IOException (checked) | COMMIT (!) | ROLLBACK | ROLLBACK (unless X matches) |
| SQLException (checked) | COMMIT (!) | ROLLBACK | ROLLBACK (unless X matches) |
| BusinessException (custom, extends RuntimeException) | ROLLBACK | ROLLBACK | ROLLBACK (unless X matches) |
| Exception caught inside method | COMMIT (!) | COMMIT (!) | COMMIT (!) |

**Always use `rollbackFor = Exception.class`** — the default of skipping checked exceptions is a design mistake in most business applications.