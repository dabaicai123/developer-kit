---
paths:
  - "**/*Service.java"
  - "**/*ServiceImpl.java"
  - "**/*CmdExe.java"
---

# Rule: Transaction Conventions

For full patterns, see `spring-boot-transaction-management` skill. This rule adds MyBatis-Plus-specific behavior.

## MyBatis-Plus Transaction Behavior

- `save`, `updateById`, `removeById`, `getById` do NOT create a transaction
- `saveBatch`/`saveOrUpdateBatch` have internal `@Transactional(rollbackFor=Exception.class)` — they join an outer transaction if one exists
- After `save(record)` then `record.setXxx()`, call `updateById(record)` — MyBatis-Plus does not auto-flush. Do NOT call `save()` again (INSERT → PK conflict)

## Batch Operations

- Set `@Transactional(timeout = 30)` on batch methods — no timeout = indefinite connection hold
- Use `Propagation.NESTED` for batch import tolerance — item failure rolls back to savepoint only
- `Propagation.REQUIRES_NEW` acquires a second connection — doubles pool pressure. Configure `leak-detection-threshold: 60000`
- Use batch methods (`saveBatch`, `listByIds`, `removeByIds`, `updateBatchById`, `lambdaQuery().in()`) — NOT for-loop individual DB calls
