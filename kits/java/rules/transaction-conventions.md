---
paths:
  - "**/*Service.java"
  - "**/*ServiceImpl.java"
---

# Rule: Transaction Conventions

Enforce consistent transaction management in the Spring Boot + MyBatis-Plus service layer.

## Guidelines

1. **Place `@Transactional` on ServiceImpl methods, not on the Service interface** — Spring AOP proxies intercept calls on the concrete class; interface-level annotations may be ignored depending on proxy mode.

2. **Always specify `rollbackFor = Exception.class`** — default rollback only covers `RuntimeException` and `Error`. Checked exceptions (e.g., `IOException`) silently commit the transaction.

3. **Do not add `@Transactional` on pure query methods** — MyBatis-Plus has no persistence context (unlike JPA), so `readOnly = true` provides no flush/dirty-check optimization. Both single and multi-step queries run fine on auto-commit. Only add `@Transactional` when you need a consistent snapshot across multi-step queries; on PostgreSQL (READ_COMMITTED default) add `isolation = Isolation.REPEATABLE_READ` explicitly, on MySQL (REPEATABLE_READ default) the default isolation already provides this.

4. **Avoid self-invocation** — `this.internalMethod()` bypasses the proxy; `@Transactional` on same-class method calls is silently ignored. Extract internal transactional logic to a separate bean.

5. **Keep transaction scope focused** — only wrap DB operations. External API calls, file I/O, and long computations should not be inside `@Transactional` — they hold connections unnecessarily and risk pool exhaustion.

6. **Set explicit timeout on batch/long-running methods** — transactions without timeout can hold connections indefinitely. Use `@Transactional(timeout = 30)` for batch operations.

7. **Use `TransactionTemplate` for programmatic control** — when transaction boundaries are conditional or need fine-grained control within a single method. Also useful for batch tolerance patterns where each item should have its own independent transaction.

8. **Re-save after modification within same transaction** — MyBatis-Plus does not auto-flush. After `save(record)` then `record.setXxx()`, call `updateById(record)` to persist changes. Do NOT call `save()` again — it will INSERT and cause primary key conflict.

9. **IService built-in transaction behavior** — `saveBatch/saveOrUpdateBatch` have internal `@Transactional(rollbackFor=Exception.class)`; single methods (`save`, `updateById`, `removeById`) do NOT. When calling multiple single-statement methods, add `@Transactional(rollbackFor=Exception.class)` on YOUR method. When `saveBatch` is called from within your `@Transactional` method, it joins your existing transaction (REQUIRED propagation).

10. **Use `Propagation.NESTED` for batch import tolerance** — individual item failure rolls back to savepoint without affecting entire batch. Requires single DataSource with JDBC 3.0 savepoint support.

11. **`Propagation.REQUIRES_NEW` acquires a second connection** — while suspending the first, it doubles connection pool pressure. Configure HikariCP `leak-detection-threshold: 60000` to catch connection leaks.

## Anti-Patterns

- `@Transactional` on Service interface
- Missing `rollbackFor = Exception.class`
- Adding `@Transactional(readOnly = true)` on any pure query method — unnecessary proxy overhead, no optimization benefit for MyBatis
- Self-invocation with `@Transactional`
- Wrapping external API calls or file I/O inside `@Transactional`
- Catching and swallowing exceptions inside `@Transactional`
- Casual use of `Propagation.REQUIRES_NEW`
- No timeout on batch operations
- Modifying a saved entity without updating — changes silently lost (use `updateById()`, not `save()` again)
- Assuming `save()` has built-in transaction (it doesn't — only `saveBatch` does)
- For-loop individual DB calls (insert/select/update/delete) instead of batch methods — use `saveBatch`, `listByIds`, `removeByIds`, `updateBatchById`, or `lambdaQuery().in()`

For detailed examples and explanations, use the `spring-boot-transaction-management` skill.