---
name: spring-boot-transaction-management
description: "Spring Boot transaction management with MyBatis-Plus: declarative @Transactional, propagation, rollback rules, self-invocation pitfalls, and distributed transaction patterns (Saga, Outbox, Seata). Use when implementing transaction management in Spring Boot with MyBatis-Plus."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Transaction Management

Spring Boot 3.5.x transaction management patterns with MyBatis-Plus — declarative `@Transactional`, propagation behavior, rollback rules, self-invocation pitfalls, and distributed transaction patterns (Saga, Outbox, Seata).

## When to use this skill

- Adding `@Transactional` to ServiceImpl methods for write operations
- Choosing the correct propagation behavior for nested or independent sub-transactions
- Configuring rollback rules (rollbackFor, noRollbackFor) for checked vs unchecked exceptions
- Debugging self-invocation issues where `@Transactional` is silently ignored on internal calls
- Deciding between declarative `@Transactional` and programmatic `TransactionTemplate`
- Evaluating whether distributed transactions (Seata) are truly necessary for a given scenario
- Choosing between Saga choreography vs orchestration for cross-service consistency
- Implementing Outbox pattern for reliable event publishing in microservices

## Instructions

### Declarative @Transactional approach

1. **Place `@Transactional` on ServiceImpl methods, not on the Service interface** — Spring AOP proxies intercept calls on the concrete class; interface-level annotations may be ignored depending on proxy mode.

2. **Always specify `rollbackFor = Exception.class`** — by default, only unchecked exceptions (`RuntimeException` and subclasses) trigger rollback. Checked exceptions (e.g., `IOException`) will commit the transaction unless explicitly configured.

3. **Use `@Transactional(readOnly = true)` on multi-step query methods only** — MyBatis-Plus has no persistence context (unlike JPA/Hibernate), so `readOnly = true` provides no flush/dirty-check optimization. For single-statement queries (getById, findByEmail), auto-commit is sufficient and adding `@Transactional` only adds proxy overhead. Use `readOnly = true` when a method executes multiple SQL statements to ensure a consistent snapshot, or as a defensive measure to prevent accidental writes in complex query logic.

4. **Keep transaction scope minimal** — only wrap database operations. Do not include long computations, external API calls, or file I/O inside a transactional method; this holds database connections unnecessarily.

### Programmatic TransactionTemplate approach

When declarative `@Transactional` does not fit (e.g., conditional transaction boundaries, varying propagation within a single method), use `TransactionTemplate`:

```java
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    private final TransactionTemplate transactionTemplate;

    public void processOrder(OrderCommand cmd) {
        if (cmd.isDryRun()) {
            // 不需要事务的预检查逻辑
            validateOnly(cmd);
        } else {
            // 仅对需要事务的部分使用 TransactionTemplate
            transactionTemplate.execute(status -> {
                doCreateOrder(cmd);
                return null;
            });
        }
    }
}
```

### Propagation behavior selection

Choose propagation based on the relationship between caller and callee transactions:

| Propagation | Use when |
|---|---|
| `REQUIRED` (default) | Most write operations — join existing or start new |
| `SUPPORTS` | Query methods that can run inside or outside a transaction |
| `MANDATORY` | Methods that must only be called within an existing transaction (enforced constraint) |
| `REQUIRES_NEW` | Independent sub-transactions that must commit/rollback independently (audit logging) |
| `NOT_SUPPORTED` | Non-transactional operations that should suspend any existing transaction |
| `NEVER` | Methods that must never run in a transactional context |
| `NESTED` | Sub-operations that can rollback independently while the outer transaction continues |

See `references/transaction-propagation-scenarios.md` for detailed scenarios and code snippets for each propagation type.

### Rollback rule configuration

- **Default**: only `RuntimeException` and its subclasses trigger rollback
- **`rollbackFor = Exception.class`**: makes all exceptions (including checked) trigger rollback — this is the recommended default
- **`noRollbackFor`**: exclude specific exception types from triggering rollback (use sparingly)
- **Critical mistake**: catching and swallowing exceptions inside `@Transactional` methods prevents rollback — the proxy only sees a normal return

See `references/rollback-rules-and-exceptions.md` for detailed flow diagrams and code examples.

## Examples

### Example 1: Basic @Transactional on service method

```java
/**
 * 订单服务实现类
 * <p>继承 ServiceImpl 获得 CRUD 基础方法，通过 baseMapper 访问数据层</p>
 */
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    /**
     * 创建订单
     * <p>包含订单主体和订单明细的写入，需要在同一事务中完成</p>
     *
     * @param dto 创建订单请求
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void create(OrderCreateDTO dto) {
        OrderDO order = OrderConverter.toDO(dto);
        baseMapper.insert(order);
        // 订单明细也插入，与订单主体在同一事务中
        orderItemService.saveBatch(OrderConverter.toItemDOs(dto.getItems(), order.getId()));
    }
}
```

### Example 2: @Transactional(readOnly = true) for multi-step query methods

```java
/**
 * 用户服务实现类
 * <p>继承 ServiceImpl 获得 CRUD 基础方法</p>
 */
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {

    /**
     * 根据邮箱查询用户 — single SQL, no @Transactional needed
     * <p>Auto-commit is sufficient for single-statement queries</p>
     *
     * @param email 用户邮箱
     * @return 对应的用户实体，不存在则返回 null
     */
    @Override
    public UserDO findByEmail(String email) {
        return lambdaQuery().eq(UserDO::getEmail, email).one();
    }

    /**
     * 分页查询用户列表 — multi-step (query + count + transform), readOnly = true needed
     * <p>Multiple SQL statements need consistent snapshot; readOnly prevents accidental writes</p>
     *
     * @param pageNum  页码
     * @param pageSize 每页条数
     * @param query    查询条件
     * @return 分页结果
     */
    @Override
    @Transactional(readOnly = true)
    public PageResult<UserVO> page(int pageNum, int pageSize, UserQueryBO query) {
        LambdaQueryWrapper<UserDO> wrapper = lambdaQuery()
            .like(StringUtils.isNotBlank(query.getUsername()), UserDO::getUsername, query.getUsername())
            .eq(query.getStatus() != null, UserDO::getStatus, query.getStatus())
            .orderByDesc(UserDO::getCreatedAt);
        Page<UserDO> mpPage = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return PageResult.of(mpPage).map(UserConverter::toVO);
    }
}
```

> **MyBatis-Plus readOnly nuance**: Unlike JPA/Hibernate, MyBatis has no persistence context — no auto-flush, no dirty-checking.
> `readOnly = true` does NOT skip flush cycles (they don't exist in MyBatis). Its value is:
> 1. **Consistent snapshot** — multiple SQL statements in one method see the same data state
> 2. **Defensive** — PostgreSQL rejects writes on a readOnly connection, preventing accidental INSERT/UPDATE
> 3. **Not needed** for single-statement queries — auto-commit handles these efficiently without proxy overhead
```

### Example 3: Propagation.REQUIRES_NEW for independent sub-transactions (audit logging)

```java
/**
 * 操作审计日志服务
 * <p>使用 REQUIRES_NEW 确保审计日志独立提交，不受主业务事务回滚影响</p>
 */
@Service
@RequiredArgsConstructor
public class AuditLogServiceImpl extends ServiceImpl<AuditLogMapper, AuditLogDO> implements AuditLogService {

    /**
     * 记录操作审计日志
     * <p>即使主业务事务回滚，审计日志仍然保留</p>
     *
     * @param action 操作类型
     * @param target 操作目标
     * @param detail 操作详情
     */
    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void log(String action, String target, String detail) {
        AuditLogDO logDO = new AuditLogDO();
        logDO.setAction(action);
        logDO.setTarget(target);
        logDO.setDetail(detail);
        logDO.setCreatedAt(LocalDateTime.now());
        baseMapper.insert(logDO);
    }
}

// 主业务服务调用审计日志 — 即使主事务回滚，审计日志已独立提交
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    private final AuditLogService auditLogService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long orderId) {
        // 主业务：取消订单
        OrderDO order = baseMapper.selectById(orderId);
        order.setStatus(OrderStatus.CANCELLED);
        baseMapper.updateById(order);

        // 审计日志：独立事务，不受主事务回滚影响
        auditLogService.log("CANCEL_ORDER", "Order:" + orderId, "订单取消");

        // 如果此处抛出异常导致主事务回滚，审计日志仍然保留
    }
}
```

### Example 4: Rollback rules — rollbackFor checked exceptions

```java
/**
 * 文件导入服务
 * <p>涉及文件读取（可能抛出 IOException）和数据库写入，需要确保 IOException 也触发回滚</p>
 */
@Service
@RequiredArgsConstructor
public class DataImportServiceImpl extends ServiceImpl<DataImportMapper, DataImportDO> implements DataImportService {

    /**
     * 从 CSV 文件导入数据
     * <p>默认只回滚 RuntimeException，IOException 是 checked exception 不会触发回滚，
     * 必须显式指定 rollbackFor = Exception.class</p>
     *
     * @param filePath CSV 文件路径
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void importFromCsv(String filePath) throws IOException {
        List<DataImportDO> dataObjects = parseCsv(filePath);  // 可能抛出 IOException
        saveBatch(entities);
    }

    /**
     * 特定异常不回滚 — 业务上允许某些可接受的异常正常提交
     * <p>使用 noRollbackFor 排除特定异常（慎用）</p>
     */
    @Override
    @Transactional(rollbackFor = Exception.class, noRollbackFor = BusinessException.class)
    public void processWithAcceptableError(Long id) {
        DataImportDO dataObject = baseMapper.selectById(id);
        // 如果抛出 BusinessException，事务仍然提交
        validateAndProcess(dataObject);
    }
}
```

### Example 5: Self-invocation pitfall — why @Transactional doesn't work on internal calls and how to fix

```java
/**
 * ❌ 错误示例：自调用导致 @Transactional 失效
 * <p>Spring AOP 基于代理，同类内部方法调用绕过代理，@Transactional 注解被静默忽略</p>
 */
@Service
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    /**
     * 支付流程 — 内部调用 processRefund()，后者的事务注解无效
     */
    public void handlePayment(PaymentDTO dto) {
        PaymentDO payment = PaymentConverter.toDO(dto);
        baseMapper.insert(payment);

        // ❌ this.processRefund() 绕过了 Spring AOP 代理
        // 即使 processRefund() 上有 @Transactional，也不会生效
        this.processRefund(payment.getId(), dto.getRefundAmount());
    }

    /** ❌ 此处的 @Transactional 不会被代理拦截（自调用） */
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void processRefund(Long paymentId, BigDecimal amount) {
        // 退款逻辑 — 但事务注解无效！
    }
}

/**
 * ✅ 正确做法：将独立事务逻辑提取到单独的 Service bean
 * <p>通过注入其他 Service 调用，确保经过 Spring AOP 代理</p>
 */
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    private final RefundService refundService;  // ✅ 注入独立的服务

    public void handlePayment(PaymentDTO dto) {
        PaymentDO payment = PaymentConverter.toDO(dto);
        baseMapper.insert(payment);

        // ✅ 通过 Spring 代理调用 refundService，@Transactional 生效
        refundService.processRefund(payment.getId(), dto.getRefundAmount());
    }
}

@Service
@RequiredArgsConstructor
public class RefundServiceImpl extends ServiceImpl<RefundMapper, RefundDO> implements RefundService {

    /** ✅ 独立 bean 上的 @Transactional 会被代理正确拦截 */
    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void processRefund(Long paymentId, BigDecimal amount) {
        RefundDO refund = new RefundDO();
        refund.setPaymentId(paymentId);
        refund.setAmount(amount);
        baseMapper.insert(refund);
    }
}
```

## Best Practices

- **Use `@Transactional(readOnly = true)` on multi-step query methods** — MyBatis-Plus has no persistence context (unlike JPA), so `readOnly` provides no flush/dirty-check optimization. Only use when a method runs multiple SQL statements (consistent snapshot, defensive write prevention). Skip for single-statement queries — auto-commit is sufficient.
- **Always specify `rollbackFor = Exception.class`** — default only rolls back unchecked exceptions; checked exceptions will silently commit
- **Avoid self-invocation** — extract internal transactional logic to a separate Service bean; `@Transactional` on same-class method calls is silently ignored by Spring AOP proxy
- **Use `Propagation.REQUIRES_NEW` only for independent audit/logging** — it suspends the existing transaction and opens a new one, adding connection pool pressure; do not use it casually
- **Keep transaction scope minimal** — do not wrap long computations, external API calls, or file I/O inside transactional boundaries; hold DB connections only for DB operations
- **Use `TransactionTemplate` for fine-grained programmatic control** — when conditional transaction boundaries or mixed propagation within a single method is needed
- **Set explicit timeout on batch/long-running methods** — `@Transactional(timeout = 30)` prevents connection leaks from stuck transactions
- **Place `@Transactional` on ServiceImpl methods, not on Service interface** — proxy mode may not honor interface-level annotations

## Constraints and Warnings

- **Self-invocation**: `@Transactional` on same-class method calls is silently ignored. Spring AOP proxies intercept external calls only; `this.internalMethod()` bypasses the proxy entirely. Fix: extract to a separate Service bean or use `AopContext.currentProxy()` (requires `@EnableAspectJAutoProxy(exposeProxy = true)`).
- **Nested transactions**: `Propagation.NESTED` requires a single DataSource and is not available with JTA-managed transactions. It uses database savepoints internally.
- **Seata for distributed transactions**: CAUTION — only use when truly distributed across multiple services that must be atomically consistent. Seata adds significant complexity (undo_log table, global lock, performance overhead) and risk of partial commit. Prefer local transaction + Outbox + Saga for microservices. See `references/distributed-transaction-patterns.md` for full comparison of Saga vs 2PC and choreography vs orchestration patterns.
- **Transaction timeout**: always set a timeout for long-running transactions (`@Transactional(timeout = 30)`) to prevent connection pool exhaustion from stuck or slow transactions.
- **Never catch exceptions inside `@Transactional` methods and swallow them** — this prevents rollback because the proxy only sees a normal method return. Either re-throw the exception or use `TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()` to force rollback.
- **Re-save after in-transaction modification**: modifying a persisted entity's fields within the same `@Transactional` method does NOT auto-persist the changes. MyBatis-Plus has no auto-flush/dirty-checking. After `save(record)` then `record.setXxx()`, call `updateById(record)` to persist changes. Do NOT call `save()` again — `save()` = INSERT and will cause primary key conflict on an already-inserted record.

### Example 6: Re-saving modified entity within same transaction

```java
@Service
@RequiredArgsConstructor
public class PushExecutor {

    private final RecordGateway recordGateway;

    @Transactional(rollbackFor = Exception.class)
    public void execute(PushCmd cmd) {
        PushRecord record = new PushRecord();
        record.setStatus(PushStatus.PENDING);
        recordGateway.save(record);  // First: INSERT

        // ... execute push logic ...

        // Modify after initial insert — use updateById(), NOT save() again!
        // save() = INSERT; calling it twice causes primary key conflict
        record.setRetryCount(record.getRetryCount() + 1);
        record.setNextRetryTime(LocalDateTime.now().plusMinutes(5));
        record.setStatus(PushStatus.RETRYING);
        recordGateway.updateById(record);  // Second: UPDATE — without this, changes are lost
    }
}
```

> **Why**: MyBatis-Plus has no auto-flush/dirty-checking. Unlike JPA's managed entities, every state change
> requires an explicit call — but use the correct method: `save()` for INSERT, `updateById()` for UPDATE.
> Calling `save()` on an already-inserted record throws a primary key conflict.
> In DDD Gateway pattern, define distinct `save()` (insert) and `update()` methods on the gateway interface.

## References

- `references/transaction-propagation-scenarios.md`
- `references/rollback-rules-and-exceptions.md`
- `references/distributed-transaction-patterns.md`

## Related Skills

- `spring-boot-async-processing` — async + transaction boundary: @Async methods run outside the caller's transaction
- `spring-boot-event-driven-patterns` — @TransactionalEventListener for event publishing after commit
- `ddd-event-driven` — domain events as alternative to distributed transactions for cross-service consistency

## Keywords

transaction, propagation, isolation, rollback, @Transactional, TransactionTemplate, Seata, self-invocation, nested, readOnly, rollbackFor, noRollbackFor, savepoint, distributed transaction, saga, outbox, choreography, orchestration, compensating transaction, idempotency, Axon, 2PC