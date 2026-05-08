# Transaction Propagation Scenarios

All 7 Spring transaction propagation types with explanation and usage guidance.

## REQUIRED (default)

**Join existing transaction or create a new one if none exists.** This is the default propagation and the most common choice. If the caller already has a transaction, the callee participates in it; otherwise, a new transaction is started.

**Use when**: most write operations — any method that modifies data and should either join an existing transactional context or start its own.

```java
/**
 * 创建用户 — REQUIRED 是默认传播行为
 * <p>如果调用方已有事务则加入，否则新建事务</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)  // propagation = Propagation.REQUIRED 是默认值
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
 * 查询用户数量 — SUPPORTS 传播行为
 * <p>有事务则加入（readOnly 优化生效），无事务则非事务执行</p>
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
 * 批量更新用户状态 — MANDATORY 传播行为
 * <p>强制要求调用方已有事务，否则抛出 IllegalTransactionStateException</p>
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
 * 记录操作审计日志 — REQUIRES_NEW 独立事务
 * <p>无论主事务是否回滚，审计日志独立提交</p>
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
 * 发送邮件通知 — NOT_SUPPORTED 非事务执行
 * <p>挂起调用方事务，避免邮件发送失败导致事务回滚</p>
 */
@Override
@Transactional(propagation = Propagation.NOT_SUPPORTED)
public void sendNotification(String email, String subject, String content) {
    // 非事务操作：邮件发送不应影响数据库事务
    mailSender.send(new SimpleMailMessage(email, subject, content));
}
```

## NEVER

**Must execute non-transactionally; throw `IllegalTransactionStateException` if a transaction exists.** This enforces that the method is never called within a transactional context.

**Use when**: operations that must absolutely never run inside a transaction — typically to prevent accidental transaction participation that could cause issues (e.g., long-running batch processing that should not hold connections).

```java
/**
 * 全量数据导出 — NEVER 传播行为
 * <p>强制非事务执行，如果调用方有事务则抛出异常</p>
 */
@Override
@Transactional(propagation = Propagation.NEVER)
public List<UserExportVO> exportAll() {
    // 大批量导出不应占用事务连接
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
 * 批量导入用户 — NESTED 传播行为
 * <p>每条记录的导入可以在 savepoint 上独立回滚，不影响整体批次</p>
 */
@Override
@Transactional(rollbackFor = Exception.class)
public void batchImport(List<UserImportDTO> dtoList) {
    for (UserImportDTO dto : dtoList) {
        try {
            // NESTED 事务：单条导入失败只回滚到 savepoint，整体批次继续
            importSingleUser(dto);
        } catch (Exception e) {
            log.warn("导入失败，跳过: username={}", dto.getUsername(), e);
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