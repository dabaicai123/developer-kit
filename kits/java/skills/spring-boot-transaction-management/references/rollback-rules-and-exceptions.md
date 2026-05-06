# Rollback Rules and Exceptions

Spring `@Transactional` rollback behavior, configuration, and common pitfalls.

## Default Behavior: Only Unchecked Exceptions Trigger Rollback

By default, Spring transactions **only roll back on unchecked exceptions** — `RuntimeException` and its subclasses, as well as `Error`. Checked exceptions (e.g., `IOException`, `SQLException`) **do NOT trigger rollback**; the transaction commits normally.

```java
/** Checked exceptions do NOT trigger rollback by default */
@Override
@Transactional  // Default: only RuntimeException and Error trigger rollback
public void importData(String filePath) throws IOException {
    List<DataDO> data = parseCsv(filePath);  // IOException — checked, transaction still commits!
    saveBatch(data);
}
```

## rollbackFor = Exception.class — Make Checked Exceptions Also Trigger Rollback

Always specify `rollbackFor = Exception.class` — this makes all exceptions (both checked and unchecked) trigger rollback.

```java
/** rollbackFor = Exception.class — all exceptions trigger rollback */
@Override
@Transactional(rollbackFor = Exception.class)
public void importData(String filePath) throws IOException {
    List<DataDO> data = parseCsv(filePath);  // IOException — now triggers rollback
    saveBatch(data);
}
```

## noRollbackFor — Exclude Specific Exceptions from Rollback

Use `noRollbackFor` sparingly — exclude specific exception types from triggering rollback when certain business exceptions should still commit other changes.

```java
/** noRollbackFor — exclude specific exceptions (use sparingly) */
@Override
@Transactional(rollbackFor = Exception.class, noRollbackFor = DuplicateDataException.class)
public void processBatch(List<BatchItemDTO> items) {
    for (BatchItemDTO item : items) {
        try {
            processItem(item);
        } catch (DuplicateDataException e) {
            log.info("Skipping duplicate data: {}", item.getId());
        }
    }
}
```

## NOT catch and swallow exceptions inside @Transactional — prevents rollback

The most critical rollback pitfall: **catching and swallowing exceptions inside a `@Transactional` method prevents rollback**. Spring's transaction proxy only sees the method's return value — if the method catches an exception and returns normally, the proxy sees success and commits the transaction.

```java
/** Anti-pattern: catch + swallow prevents rollback — proxy sees normal return */
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
        // Swallowing: from-account deduction committed, to-account credit failed but transaction still commits!
        log.error("Transfer failed", e);
    }
}

/** Fix: let exception propagate to proxy layer → rollback triggered */
@Override
@Transactional(rollbackFor = Exception.class)
public void transferMoney(Long fromId, Long toId, BigDecimal amount) {
    AccountDO from = accountMapper.selectById(fromId);
    from.setBalance(from.getBalance().subtract(amount));
    accountMapper.updateById(from);

    AccountDO to = accountMapper.selectById(toId);
    to.setBalance(to.getBalance().add(amount));
    accountMapper.updateById(to);
    // Exception propagates to proxy → transaction rolls back, neither account modified
}

/** If you must catch: manually mark for rollback */
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
        TransactionAspectSupport.currentTransactionStatus().setRollbackOnly();
    }
}
```

## Rollback vs Commit Flow Diagram

```
@Transactional Method Execution Flow:

    Proxy intercepts call → Begin transaction
         │
         ▼
    Execute method body
         │
    ┌────┴─────────────┐
    │                  │
  Normal return    Exception thrown
    │                  │
    ▼                  ▼
  COMMIT          Exception caught & swallowed inside method?
                       │
                  ┌────┴────┐
                 YES        NO (propagates to proxy)
                  │          │
                  ▼          ▼
                COMMIT    Check noRollbackFor — exception matches?
                                │
                          ┌─────┴─────┐
                         YES          NO
                          │            │
                          ▼            ▼
                        COMMIT    Check rollback rules:
                                  - RuntimeException / Error → ROLLBACK
                                  - Checked exception:
                                      rollbackFor matches → ROLLBACK
                                      rollbackFor NOT matches → COMMIT (danger)
```

## Rollback Rule Configuration Examples

```java
// Standard: rollback all exceptions
@Transactional(rollbackFor = Exception.class)

// Specific: rollback only on custom business exceptions
@Transactional(rollbackFor = {BusinessException.class, IOException.class})

// Exclude: rollback all except specific types
@Transactional(rollbackFor = Exception.class, noRollbackFor = DuplicateDataException.class)

// Consistent snapshot + rollback coverage
@Transactional(isolation = Isolation.REPEATABLE_READ, rollbackFor = Exception.class)

// Timeout + rollback (prevent stuck transactions)
@Transactional(rollbackFor = Exception.class, timeout = 30)
```

## Exception Rollback Matrix

| Exception Type | Default | With `rollbackFor=Exception.class` | With `noRollbackFor=X.class` |
|---|---|---|---|
| RuntimeException | ROLLBACK | ROLLBACK | ROLLBACK (unless X matches) |
| Error | ROLLBACK | ROLLBACK | ROLLBACK (unless X matches) |
| IOException (checked) | COMMIT (!) | ROLLBACK | ROLLBACK (unless X matches) |
| SQLException (checked) | COMMIT (!) | ROLLBACK | ROLLBACK (unless X matches) |
| BusinessException (extends RuntimeException) | ROLLBACK | ROLLBACK | ROLLBACK (unless X matches) |
| Exception caught inside method | COMMIT (!) | COMMIT (!) | COMMIT (!) |

**Always use `rollbackFor = Exception.class`** — the default of skipping checked exceptions is a design mistake in most business applications.