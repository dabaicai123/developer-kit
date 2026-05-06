# Transaction Propagation Scenarios

All 7 Spring transaction propagation types with usage guidance.

## REQUIRED (default)

**Join existing transaction or create a new one if none exists.** This is the default propagation and the most common choice.

**Use when**: most write operations — any method that modifies data and should either join an existing transactional context or start its own.

```java
/** REQUIRED is the default — join existing or start new */
@Override
@Transactional(rollbackFor = Exception.class)  // propagation = Propagation.REQUIRED is the default
public void create(UserCreateDTO dto) {
    UserDO dataObject = UserConverter.toDO(dto);
    baseMapper.insert(dataObject);
}
```

## SUPPORTS

**Join an existing transaction if one exists; execute non-transactionally if none exists.** The method adapts to the caller's transactional context without enforcing one.

**Use when**: methods that must participate in an existing transaction when called within one, but should also work standalone — NOT for simple single-query methods with MyBatis-Plus (those skip `@Transactional` entirely, auto-commit is sufficient).

```java
/** SUPPORTS — reusable method that works inside or outside a transaction */
@Override
@Transactional(propagation = Propagation.SUPPORTS, rollbackFor = Exception.class)
public BigDecimal calculateTotal(Long orderId) {
    // When called inside a write transaction → joins it (consistent snapshot)
    // When called standalone → runs on auto-commit
    List<OrderItemDO> items = orderItemMapper.selectList(
        new LambdaQueryWrapper<OrderItemDO>().eq(OrderItemDO::getOrderId, orderId));
    return items.stream().map(OrderItemDO::getPrice).reduce(BigDecimal.ZERO, BigDecimal::add);
}

/** NOT add @Transactional on simple queries — auto-commit is sufficient */
@Override
public long countByStatus(UserStatus status) {
    return lambdaQuery().eq(UserDO::getStatus, status).count();
}
```

## MANDATORY

**Must join an existing transaction; throw `IllegalTransactionStateException` if none exists.** Enforces that the method is always called within a transactional context.

**Use when**: methods that must never execute outside a transaction — internal helper methods that depend on the caller's transactional boundary for correctness.

```java
/** MANDATORY — must be called within an existing transaction, throws exception if none */
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

**Always start a new independent transaction, suspending any existing transaction.** The new transaction commits or rolls back independently of the outer transaction.

**Use when**: independent sub-transactions that must commit or rollback independently — audit logging, notification records.

**Caution**: REQUIRES_NEW acquires a second database connection from the pool, increasing connection pressure. Use sparingly.

```java
/** REQUIRES_NEW — independent transaction, commits regardless of main transaction outcome */
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

**Always execute non-transactionally, suspending any existing transaction.** The caller's transaction is suspended and resumes after this method completes.

**Use when**: operations that should never be transactional — sending email notifications, calling external APIs, or long-running computations that should NOT hold a database connection.

```java
/** NOT_SUPPORTED — suspends caller transaction, prevents non-DB failures from causing rollback */
@Override
@Transactional(propagation = Propagation.NOT_SUPPORTED)
public void sendNotification(String email, String subject, String content) {
    SimpleMailMessage msg = new SimpleMailMessage();
    msg.setTo(email);
    msg.setSubject(subject);
    msg.setText(content);
    mailSender.send(msg);
}
```

## NEVER

**Must execute non-transactionally; throw `IllegalTransactionStateException` if a transaction exists.** Enforces that the method is never called within a transactional context.

**Use when**: operations that must absolutely never run inside a transaction — typically to prevent accidental transaction participation that could cause issues (e.g., long-running batch processing that should NOT hold connections).

```java
/** NEVER — enforces non-transactional execution; throws exception if caller has a transaction */
@Override
@Transactional(propagation = Propagation.NEVER)
public List<UserExportVO> exportAll() {
    return baseMapper.selectList(null)
        .stream()
        .map(UserConverter::toExportVO)
        .toList();
}
```

## NESTED

**Execute within a nested transaction (savepoint) if an existing transaction exists; start a new transaction if none exists.** The nested transaction can rollback independently via savepoint, while the outer transaction can choose to commit or rollback the entire operation.

**Use when**: sub-operations that should be able to fail without rolling back the entire parent transaction — partial batch processing where individual items can fail but the overall batch should continue.

**Constraint**: NESTED requires a single DataSource; NOT available with JTA-managed transactions. It relies on JDBC 3.0 savepoints internally.

```java
/** Outer transaction — individual items use NESTED savepoints */
@Override
@Transactional(rollbackFor = Exception.class)
public void batchImport(List<UserImportDTO> dtoList) {
    for (UserImportDTO dto : dtoList) {
        try {
            importSingleUser(dto);  // NESTED — savepoint rollback on failure
        } catch (Exception e) {
            log.warn("Import failed, skipping: username={}", dto.getUsername(), e);
        }
    }
}

/** NESTED savepoint — failure rolls back to savepoint without affecting outer transaction */
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
| SUPPORTS | Join | None | Reusable methods (flexible) |
| MANDATORY | Join | **Throw exception** | Enforce transactional context |
| REQUIRES_NEW | **Suspend, new** | New | Independent audit/log side-effects |
| NOT_SUPPORTED | **Suspend, none** | None | External calls, notifications |
| NEVER | **Throw exception** | None | Enforce non-transactional context |
| NESTED | Savepoint | New | Partial rollback within batch |