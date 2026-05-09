# Transaction Propagation Scenarios

All 7 Spring transaction propagation types with explanation and usage guidance.

## REQUIRED (default)

**Join existing transaction or create a new one if none exists.** This is the default propagation and the most common choice. If the caller already has a transaction, the callee participates in it; otherwise, a new transaction is started.

**Use when**: most write operations — any method that modifies data and should either join an existing transactional context or start its own.

```java
/**
 * Create user — REQUIRED is the default propagation behavior
 * <p>If the caller already has a transaction, join it; otherwise, start a new transaction</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)  // propagation = Propagation.REQUIRED is the default
public void create(UserCreateDTO dto) {
    UserDO dataObject = UserConverter.toDO(dto);
    baseMapper.insert(dataObject);
}
```

## SUPPORTS

**Join an existing transaction if one exists; execute non-transactionally if none exists.** The method adapts to the caller's transactional context without enforcing one.

**Use when**: query methods that can run with or without a transaction. Often paired with `readOnly = true`.

```java
/**
 * Count users by status — SUPPORTS propagation behavior
 * <p>Join existing transaction (readOnly optimization applies), or execute non-transactionally if no transaction</p>
 */
@Override
@Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
public long countByStatus(UserStatus status) {
    return lambdaQuery().eq(UserDO::getStatus, status).count();
}
```

## MANDATORY

**Must join an existing transaction; throw `IllegalTransactionStateException` if none exists.** This enforces that the method is always called within a transactional context.

**Use when**: methods that must never execute outside a transaction — internal helper methods that depend on the caller's transactional boundary for correctness.

```java
/**
 * Batch update user status — MANDATORY propagation behavior
 * <p>Requires the caller to already have a transaction; otherwise throws IllegalTransactionStateException</p>
 */
@Override
@Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
public void batchUpdateStatus(List<Long> ids, UserStatus status) {
    ids.forEach(id -> {
        UserDO dataObject = baseMapper.selectById(id);
        dataObject.setStatus(status);
        baseMapper.updateById(dataObject);
    });
}
```

## REQUIRES_NEW

**Always start a new independent transaction, suspending any existing transaction.** The new transaction commits or rolls back independently of the outer transaction. The outer transaction resumes after the inner one completes.

**Use when**: independent sub-transactions that must commit or rollback independently — audit logging, notification records, or any side-effect that should persist even if the main business operation fails.

**Caution**: REQUIRES_NEW acquires a second database connection from the pool, increasing connection pressure. Use sparingly.

```java
/**
 * Log operation audit record — REQUIRES_NEW independent transaction
 * <p>Audit log commits independently, regardless of whether the main transaction rolls back</p>
 */
@Override
@Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
public void logOperation(String action, String target, String detail) {
    AuditLogDO logDO = new AuditLogDO();
    logDO.setAction(action);
    logDO.setTarget(target);
    logDO.setDetail(detail);
    logDO.setCreatedAt(LocalDateTime.now());
    baseMapper.insert(logDO);
}
```

## NOT_SUPPORTED

**Always execute non-transactionally, suspending any existing transaction.** The method runs without a transaction regardless of the caller's context. The caller's transaction is suspended and resumes after this method completes.

**Use when**: operations that should never be transactional — sending email notifications, calling external APIs, or performing long-running computations that should not hold a database connection.

```java
/**
 * Send email notification — NOT_SUPPORTED non-transactional execution
 * <p>Suspends caller transaction, preventing email send failure from causing transaction rollback</p>
 */
@Override
@Transactional(propagation = Propagation.NOT_SUPPORTED)
public void sendNotification(String email, String subject, String content) {
    // Non-transactional operation: email sending should not affect database transaction
    mailSender.send(new SimpleMailMessage(email, subject, content));
}
```

## NEVER

**Must execute non-transactionally; throw `IllegalTransactionStateException` if a transaction exists.** This enforces that the method is never called within a transactional context.

**Use when**: operations that must absolutely never run inside a transaction — typically to prevent accidental transaction participation that could cause issues (e.g., long-running batch processing that should not hold connections).

```java
/**
 * Full data export — NEVER propagation behavior
 * <p>Enforces non-transactional execution; throws exception if caller has a transaction</p>
 */
@Override
@Transactional(propagation = Propagation.NEVER)
public List<UserExportVO> exportAll() {
    // Large batch export should not hold a transaction connection
    return baseMapper.selectList(null)
        .stream()
        .map(UserConverter::toExportVO)
        .toList();
}
```

## NESTED

**Execute within a nested transaction (savepoint) if an existing transaction exists; start a new transaction if none exists.** The nested transaction can rollback independently via savepoint, while the outer transaction can choose to commit or rollback the entire operation.

**Use when**: sub-operations that should be able to fail without rolling back the entire parent transaction — partial batch processing where individual items can fail but the overall batch should continue.

**Constraint**: NESTED requires a single DataSource; it is not available with JTA-managed transactions. It relies on JDBC 3.0 savepoints internally.

```java
/**
 * Batch import users — NESTED propagation behavior
 * <p>Each record's import can independently rollback to a savepoint, without affecting the overall batch</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)
public void batchImport(List<UserImportDTO> dtoList) {
    for (UserImportDTO dto : dtoList) {
        try {
            // NESTED transaction: single import failure only rolls back to savepoint, overall batch continues
            importSingleUser(dto);
        } catch (Exception e) {
            log.warn("Import failed, skipping: username={}", dto.getUsername(), e);
        }
    }
}

@Override
@Transactional(propagation = Propagation.NESTED, rollbackFor = Exception.class)
public void importSingleUser(UserImportDTO dto) {
    UserDO dataObject = UserConverter.toDO(dto);
    baseMapper.insert(dataObject);
}
```

## Propagation Selection Summary

| Propagation | Existing Transaction | No Transaction | Use Case |
|---|---|---|---|
| REQUIRED | Join | New | Most write operations (default) |
| SUPPORTS | Join | None | Read-only queries (flexible) |
| MANDATORY | Join | **Throw exception** | Enforce transactional context |
| REQUIRES_NEW | **Suspend, new** | New | Independent audit/log side-effects |
| NOT_SUPPORTED | **Suspend, none** | None | External calls, notifications |
| NEVER | **Throw exception** | None | Enforce non-transactional context |
| NESTED | Savepoint | New | Partial rollback within batch |