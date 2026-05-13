---
name: spring-boot-transaction-management
description: "Spring Boot transaction management with MyBatis-Plus: @Transactional placement, rollbackFor, propagation, self-invocation, afterCommit messaging, and distributed consistency. Use when implementing write operations or reviewing transaction boundaries."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Transaction Management

## Load Policy

Use this quick guide for normal write methods. Load `references/full-guide.md` only for detailed propagation examples, programmatic `TransactionTemplate`, connection pool analysis, distributed transactions, or MQ after-commit code.

Additional references:

- `references/transaction-propagation-scenarios.md`
- `references/rollback-rules-and-exceptions.md`
- `references/distributed-transaction-patterns.md`

## Placement Rules

- MVC: put `@Transactional(rollbackFor = Exception.class)` on concrete `ServiceImpl` write methods.
- COLA/DDD: put transaction boundaries on application-layer `CmdExe.execute(...)`, not GatewayImpl.
- Do not put transaction annotations on interfaces as the primary rule.
- Do not add `@Transactional(readOnly = true)` to pure MyBatis queries. MyBatis has no persistence context or dirty checking.
- Add a transaction only when multiple DB operations must commit or roll back together, or when a consistent multi-query snapshot is a real requirement.

## Rollback Rules

- Always specify `rollbackFor = Exception.class` on business write transactions.
- Do not catch and swallow exceptions inside a transaction. Re-throw or explicitly mark rollback only.
- Checked exceptions do not trigger rollback unless `rollbackFor` includes them.
- Use `noRollbackFor` only for explicitly acceptable business outcomes.

## MyBatis-Plus Behavior

- `save`, `updateById`, `removeById`, and `getById` do not create a transaction.
- `saveBatch` and `saveOrUpdateBatch` have internal transactions and join an outer transaction.
- Calling `save(entity)` twice is two INSERT attempts. For later state changes, call `updateById` or Gateway `update()`.

## Propagation Rules

- Default `REQUIRED` fits most write operations.
- `REQUIRES_NEW` is for independent audit/log writes; it holds an extra connection and can exhaust HikariCP under concurrency.
- `NESTED` requires JDBC savepoints and a single DataSource.
- Self-invocation bypasses Spring AOP. Move independent transactional work to another Spring bean.

## External Side Effects

- Do not hold transactions around external HTTP calls, file I/O, long computation, or slow MQ calls.
- Do not publish Kafka/RabbitMQ/RocketMQ messages directly inside a DB transaction.
- Use `TransactionSynchronizationManager.afterCommit`, `@TransactionalEventListener(phase = AFTER_COMMIT)`, or Outbox for reliable event publishing.
- Prefer local transaction + Outbox/Saga over Seata unless a concrete distributed transaction requirement justifies the complexity.

## Review Checklist

- Is this a write path with more than one DB operation?
- Is `rollbackFor = Exception.class` present?
- Are exceptions allowed to reach the proxy?
- Is any external side effect inside the transaction?
- Is there self-invocation of transactional methods?
- Are pure queries free of unnecessary `readOnly` transactions?

