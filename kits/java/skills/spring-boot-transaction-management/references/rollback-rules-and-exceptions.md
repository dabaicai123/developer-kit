# Rollback Rules and Exceptions

Spring `@Transactional` rollback behavior, configuration, and common pitfalls.

## Default Behavior: Only Unchecked Exceptions Trigger Rollback

By default, Spring transactions **only roll back on unchecked exceptions** — `RuntimeException` and its subclasses, as well as `Error`. Checked exceptions (e.g., `IOException`, `SQLException`) **do not trigger rollback**; the transaction commits normally.

This is a common source of bugs: developers assume any exception will rollback the transaction, but checked exceptions silently commit partial changes.

```java
/**
 * Default behavior: checked exceptions do NOT trigger rollback
 * <p>IOException is a checked exception; after it is thrown, the transaction still commits</p>
 */
@Override
@Transactional  // Default: only RuntimeException and Error trigger rollback
public void importData(String filePath) throws IOException {
    List<DataDO> data = parseCsv(filePath);  // IOException — checked exception
    saveBatch(data);
    // If parseCsv() throws IOException, already-inserted data will NOT be rolled back!
}
```

## rollbackFor = Exception.class — Make Checked Exceptions Also Trigger Rollback

The recommended practice is to always specify `rollbackFor = Exception.class`, which makes all exceptions (both checked and unchecked) trigger rollback.

```java
/**
 * Correct approach: rollbackFor = Exception.class ensures all exceptions trigger rollback
 * <p>IOException and other checked exceptions will also cause transaction rollback</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)
public void importData(String filePath) throws IOException {
    List<DataDO> data = parseCsv(filePath);  // IOException — triggers rollback
    saveBatch(data);
    // If parseCsv() throws IOException, all inserted data will be rolled back
}
```

## noRollbackFor — Exclude Specific Exceptions from Rollback

Use `noRollbackFor` to exclude specific exception types from triggering rollback. This is useful when certain business exceptions should not cause the transaction to rollback (e.g., a "data already exists" warning that should still commit other changes).

**Caution**: use `noRollbackFor` sparingly — most cases should just rollback on all exceptions.

```java
/**
 * Exclude specific exceptions from triggering rollback
 * <p>DuplicateDataException is a business-acceptable exception; the transaction still commits</p>
 */
@Override
@Transactional(rollbackFor = Exception.class, noRollbackFor = DuplicateDataException.class)
public void processBatch(List<BatchItemDTO> items) {
    for (BatchItemDTO item : items) {
        try {
            processItem(item);
        } catch (DuplicateDataException e) {
            // Duplicate data is acceptable; does not prevent the overall batch from committing
            log.info("Skipping duplicate data: {}", item.getId());
        }
    }
}
```

## Common Mistake: Catching Exception Inside @Transactional Method Prevents Rollback

The most critical rollback pitfall: **catching and swallowing exceptions inside a `@Transactional` method prevents rollback**. Spring's transaction proxy only sees the method's return value — if the method catches an exception and returns normally, the proxy sees success and commits the transaction.

```java
/**
 * Wrong: catching exception internally prevents transaction rollback
 * <p>Spring proxy only checks method return value; catch + normal return = transaction commits</p>
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
        // Swallowing exception: from-account deduction is committed, to-account credit failed but transaction still commits!
        log.error("Transfer failed", e);
    }
}

/**
 * Correct approach: let the exception propagate to the proxy layer to trigger rollback
 * <p>Do not catch and swallow exceptions inside @Transactional methods</p>
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
    // Exception naturally propagates to proxy layer → transaction rolls back, neither account is modified
}

/**
 * If you must catch: manually mark for rollback
 * <p>Use TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()</p>
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
        log.error("Transfer failed", e);
        // Manually mark for rollback, even if the exception was caught
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