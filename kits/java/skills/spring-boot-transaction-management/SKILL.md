---
name: spring-boot-transaction-management
description: "Spring Boot transaction management with MyBatis-Plus: declarative @Transactional, propagation, rollback rules, self-invocation pitfalls, and distributed transaction patterns (Saga, Outbox, Seata). Use when implementing transaction management in Spring Boot with MyBatis-Plus."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Transaction Management

Transaction management patterns with MyBatis-Plus — declarative `@Transactional`, propagation, rollback, self-invocation, and distributed patterns.

## When to use this skill

- Adding `@Transactional` to ServiceImpl methods for write operations
- Choosing the correct propagation behavior for nested or independent sub-transactions
- Configuring rollback rules (rollbackFor, noRollbackFor) for checked vs unchecked exceptions
- Debugging self-invocation issues where `@Transactional` is silently ignored on internal calls
- Deciding between declarative `@Transactional` and programmatic `TransactionTemplate`
- Understanding how MyBatis-Plus IService methods interact with `@Transactional` (saveBatch has internal transaction, save/updateById do not)
- Evaluating whether distributed transactions (Seata) are truly necessary for a given scenario
- Choosing between Saga choreography vs orchestration for cross-service consistency
- Implementing Outbox pattern for reliable event publishing in microservices
- Choosing between MVC (ServiceImpl-level) and DDD (CmdExe-level) transaction ownership patterns
- Ensuring MQ messages (RabbitMQ/Kafka) are only sent after DB transaction commits — avoiding ghost messages and premature delivery

## Instructions

### Declarative @Transactional approach

1. **Place `@Transactional` on ServiceImpl methods, not on the Service interface** — Spring AOP proxies intercept calls on the concrete class; interface-level annotations may be ignored depending on proxy mode.

2. **Always specify `rollbackFor = Exception.class`** — by default, only unchecked exceptions (`RuntimeException` and subclasses) trigger rollback. Checked exceptions (e.g., `IOException`) will commit the transaction unless explicitly configured.

3. **Do not add `@Transactional` on pure query methods** — MyBatis-Plus has no persistence context (unlike JPA/Hibernate), so `readOnly = true` provides no flush/dirty-check optimization. Both single and multi-step queries run fine on auto-commit. Only add `@Transactional` when you need a consistent snapshot across multi-step queries; on PostgreSQL (READ_COMMITTED default) add `isolation = Isolation.REPEATABLE_READ` explicitly, on MySQL (REPEATABLE_READ default) the default isolation already provides consistent snapshots.


### MyBatis-Plus IService Built-in Transaction Behavior

Understanding which IService methods have internal transactions is critical for avoiding duplicate or missing `@Transactional`:

| IService Method | Built-in `@Transactional`? | Implication |
|-----------------|---------------------------|-------------|
| `save(T)` | **No** | Single INSERT — auto-commit. For multi-step writes, add `@Transactional` on YOUR method |
| `updateById(T)` | **No** | Single UPDATE — auto-commit |
| `removeById(Serializable)` | **No** | Single DELETE/soft-delete — auto-commit |
| `getById(Serializable)` | **No** | Single SELECT — auto-commit |
| `saveBatch(Collection, int)` | **Yes** — `@Transactional(rollbackFor=Exception.class)` | Entire batch in one transaction |
| `saveOrUpdateBatch(Collection, int)` | **Yes** — `@Transactional(rollbackFor=Exception.class)` | Entire batch in one transaction |

**Common mistake**: Calling `save(entityA)` then `save(entityB)` without `@Transactional` on your method — each INSERT auto-commits independently, so entityB failure does NOT roll back entityA. Always add `@Transactional(rollbackFor=Exception.class)` on your method when multiple DB operations must share one transaction.

> **saveBatch joins outer transaction**: When called from within your own `@Transactional` method, `saveBatch` joins the existing transaction (REQUIRED propagation) — not a separate scope. This means both your writes and the batch share the same transaction boundary.

> **saveBatch is NOT multi-row INSERT**: `saveBatch` loops through individual `INSERT` statements, not a single `INSERT INTO ... VALUES (...),(...),(...)`. For truly efficient bulk inserts, use a custom SQL injector method.

### Programmatic TransactionTemplate approach

When declarative `@Transactional` does not fit (e.g., conditional transaction boundaries, varying propagation within a single method), use `TransactionTemplate`:

```java
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    private final TransactionTemplate transactionTemplate;

    public void processOrder(OrderCommand cmd) {
        if (cmd.isDryRun()) {
            // pre-check logic that doesn't need a transaction
            validateOnly(cmd);
        } else {
            // use TransactionTemplate only for the parts that need a transaction
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
| `SUPPORTS` | Query methods — can run inside or outside an existing transaction. Pattern: `@Transactional(propagation = SUPPORTS)` |
| `MANDATORY` | Methods that must only be called within an existing transaction (enforced constraint) |
| `REQUIRES_NEW` | Independent sub-transactions that must commit/rollback independently (audit logging) |
| `NOT_SUPPORTED` | Non-transactional operations that should suspend any existing transaction |
| `NEVER` | Methods that must never run in a transactional context |
| `NESTED` | Sub-operations that can rollback independently while the outer transaction continues — useful for batch import tolerance (individual item failure doesn't roll back entire batch) |

See `references/transaction-propagation-scenarios.md` for detailed scenarios and code snippets for each propagation type.

### Rollback rule configuration

- **Default**: only `RuntimeException` and its subclasses trigger rollback
- **`rollbackFor = Exception.class`**: makes all exceptions (including checked) trigger rollback — this is the recommended default
- **`noRollbackFor`**: exclude specific exception types from triggering rollback (use sparingly)

See `references/rollback-rules-and-exceptions.md` for detailed flow diagrams and code examples.

## Examples

### Example 1: Basic @Transactional on service method

```java
/**
 * Order service implementation
 * <p>Extends ServiceImpl for CRUD base methods, accesses data layer via baseMapper</p>
 */
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    /**
     * Create order
     * <p>Includes order main body and order item writes, must complete in the same transaction</p>
     *
     * @param dto create order request
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void create(CreateOrderCmd dto) {
        OrderDO order = OrderConverter.toDO(dto);
        baseMapper.insert(order);
        // order items also inserted, within the same transaction as the order main body
        orderItemService.saveBatch(OrderConverter.toItemDOs(dto.getItems(), order.getId()));
    }
}
```

### Example 2: @Transactional for consistent snapshot (rare — only when business requires)

```java
/**
 * User service implementation
 * <p>Extends ServiceImpl for CRUD base methods</p>
 */
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {

    /**
     * Find user by email — single SQL, no @Transactional needed
     * <p>Auto-commit is sufficient for single-statement queries</p>
     *
     * @param email user email
     * @return corresponding user entity, returns null if not found
     */
    @Override
    public UserDO findByEmail(String email) {
        return lambdaQuery().eq(UserDO::getEmail, email).one();
    }

    /**
     * Paginated user list query — auto-commit is sufficient for most queries
     * <p>Only add @Transactional when you need a consistent snapshot across multi-step reads</p>
     *
     * @param pageNum  page number
     * @param pageSize items per page
     * @param query    query conditions
     * @return paginated result
     */
    @Override
    public PageResult<UserVO> page(int pageNum, int pageSize, UserQry query) {
        LambdaQueryWrapper<UserDO> wrapper = lambdaQuery()
            .like(StringUtils.isNotBlank(query.getUsername()), UserDO::getUsername, query.getUsername())
            .eq(query.getStatus() != null, UserDO::getStatus, query.getStatus())
            .orderByDesc(UserDO::getCreatedAt);
        Page<UserDO> mpPage = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return PageResult.of(mpPage).map(UserConverter::toVO);
    }

    /**
     * Report: revenue comparison across months — needs consistent snapshot
     * <p>Multiple queries must see the same data state; on PostgreSQL add REPEATABLE_READ</p>
     *
     * @param year report year
     * @return monthly revenue comparison
     */
    @Override
    @Transactional(isolation = Isolation.REPEATABLE_READ)  // PostgreSQL: ensure snapshot consistency
    public RevenueReportVO getYearlyRevenueReport(int year) {
        BigDecimal q1Revenue = calculateQuarterRevenue(year, 1);
        BigDecimal q2Revenue = calculateQuarterRevenue(year, 2);
        // All queries see the same snapshot — no phantom reads between steps
        return new RevenueReportVO(q1Revenue, q2Revenue);
    }
}
```

> **MyBatis-Plus transaction nuance**: Unlike JPA/Hibernate, MyBatis has no persistence context — no auto-flush, no dirty-checking.
> 1. **Pure queries don't need `@Transactional`** — auto-commit handles single and multi-step queries efficiently
> 2. **`readOnly = true` provides no optimization for MyBatis** — no flush cycles to skip (they don't exist). Its only effect is preventing writes on PostgreSQL connections, which is a weak reason to add proxy overhead
> 3. **Consistent snapshot requires proper isolation** — on PostgreSQL (READ_COMMITTED default), use `isolation = Isolation.REPEATABLE_READ`; on MySQL (REPEATABLE_READ default), plain `@Transactional` already provides snapshot consistency

### Example 3: Propagation.REQUIRES_NEW for independent sub-transactions (audit logging)

```java
/**
 * Operation audit log service
 * <p>Uses REQUIRES_NEW to ensure audit logs commit independently, unaffected by main business transaction rollback</p>
 */
@Service
@RequiredArgsConstructor
public class AuditLogServiceImpl extends ServiceImpl<AuditLogMapper, AuditLogDO> implements AuditLogService {

    /**
     * Record operation audit log
     * <p>Even if the main business transaction rolls back, audit logs are still retained</p>
     *
     * @param action operation type
     * @param target operation target
     * @param detail operation details
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

// Main business service calls audit log — even if main transaction rolls back, audit log has already committed independently
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    private final AuditLogService auditLogService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long orderId) {
        // Main business: cancel order
        OrderDO order = baseMapper.selectById(orderId);
        order.setStatus(OrderStatus.CANCELLED);
        baseMapper.updateById(order);

        // Audit log: independent transaction, unaffected by main transaction rollback
        auditLogService.log("CANCEL_ORDER", "Order:" + orderId, "Order cancelled");

        // If an exception thrown here causes main transaction rollback, audit log is still retained
    }
}
```

### Example 4: Rollback rules — rollbackFor checked exceptions

```java
/**
 * File import service
 * <p>Involves file reading (may throw IOException) and database writes, must ensure IOException also triggers rollback</p>
 */
@Service
@RequiredArgsConstructor
public class DataImportServiceImpl extends ServiceImpl<DataImportMapper, DataImportDO> implements DataImportService {

    /**
     * Import data from CSV file
     * <p>By default only RuntimeException triggers rollback; IOException is a checked exception that
     * does not trigger rollback, must explicitly specify rollbackFor = Exception.class</p>
     *
     * @param filePath CSV file path
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void importFromCsv(String filePath) throws IOException {
        List<DataImportDO> dataObjects = parseCsv(filePath);  // may throw IOException
        saveBatch(entities);
    }

    /**
     * Specific exceptions do not trigger rollback — business allows certain acceptable exceptions to commit normally
     * <p>Uses noRollbackFor to exclude specific exceptions (use sparingly)</p>
     */
    @Override
    @Transactional(rollbackFor = Exception.class, noRollbackFor = BusinessException.class)
    public void processWithAcceptableError(Long id) {
        DataImportDO dataObject = baseMapper.selectById(id);
        // If BusinessException is thrown, the transaction still commits
        validateAndProcess(dataObject);
    }
}
```

### Example 5: Propagation.NESTED for batch import tolerance

```java
/**
 * Batch import service — NESTED propagation allows individual item failure without rolling back entire batch
 * <p>Each item runs in a nested transaction (savepoint). If one item fails, only that savepoint rolls back;
 * the outer transaction and other items continue.</p>
 */
@Service
@RequiredArgsConstructor
public class DataImportServiceImpl extends ServiceImpl<DataImportMapper, DataImportDO> implements DataImportService {

    /**
     * Batch import — outer transaction, individual items use NESTED savepoints
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchImport(List<UserImportDTO> dtoList) {
        for (UserImportDTO dto : dtoList) {
            try {
                importSingleUser(dto);  // NESTED — savepoint rollback on failure
            } catch (Exception e) {
                log.warn("Import failed, skipping: username={}", dto.getUsername(), e);
                // Only this item's savepoint rolls back; batch continues
            }
        }
    }

    /**
     * Import single user — NESTED savepoint
     * <p>Failure rolls back to savepoint without affecting outer transaction</p>
     */
    @Override
    @Transactional(propagation = Propagation.NESTED, rollbackFor = Exception.class)
    public void importSingleUser(UserImportDTO dto) {
        baseMapper.insert(UserConverter.toDO(dto));
    }
}
```

> **Constraint**: NESTED requires a single DataSource and JDBC 3.0 savepoint support. Not available with JTA-managed transactions.

### Example 6: TransactionTemplate for batch tolerance (alternative to NESTED)

When NESTED is unavailable (JTA, multiple DataSource), use `TransactionTemplate` for independent item-level transactions:

```java
@Service
@RequiredArgsConstructor
public class DataImportServiceImpl extends ServiceImpl<DataImportMapper, DataImportDO> implements DataImportService {

    private final TransactionTemplate transactionTemplate;

    /**
     * Batch import with tolerance — each item in independent transaction
     * <p>Individual item failure rolls back only that item; batch continues</p>
     */
    public void batchImportWithTolerance(List<UserImportDTO> dtoList) {
        for (UserImportDTO dto : dtoList) {
            try {
                transactionTemplate.execute(status -> {
                    importSingleItem(dto);
                    return null;
                });
            } catch (Exception e) {
                log.warn("Item import failed, continuing: id={}", dto.getId(), e);
                // Individual item transaction rolled back, but loop continues
            }
        }
    }
}
```

### Example 7: Force rollback with setRollbackOnly() inside catch block

```java
/**
 * When you must catch exceptions inside @Transactional but still want rollback
 * <p>Catching and swallowing prevents rollback because the proxy only sees normal return.
 * Use setRollbackOnly() to force rollback without re-throwing.</p>
 */
@Service
@RequiredArgsConstructor
public class TransferServiceImpl extends ServiceImpl<TransferMapper, TransferDO> implements TransferService {

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void transferMoney(Long fromId, Long toId, BigDecimal amount) {
        try {
            // ... DB operations ...
        } catch (Exception e) {
            log.error("Transfer failed", e);
            // Force rollback without re-throwing — proxy sees normal return but transaction is marked rollback-only
            TransactionAspectSupport.currentTransactionStatus().setRollbackOnly();
        }
    }
}
```

> **Prefer re-throwing** over `setRollbackOnly()` when possible — it's cleaner and lets callers handle the exception. Use `setRollbackOnly()` only when you need to log the error and mark rollback without propagating the exception upstream.

### Connection Pool Considerations (HikariCP)

Transactions hold one HikariCP connection for their entire duration. Key configuration for MyBatis-Plus:

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20            # adjust based on concurrent transaction count
      minimum-idle: 5
      idle-timeout: 300000             # 5 minutes
      max-lifetime: 1800000            # 30 minutes
      connection-timeout: 30000        # 30 seconds — fail fast if pool exhausted
      leak-detection-threshold: 60000  # log connections held > 60 seconds
```

**Critical impacts**:
- `Propagation.REQUIRES_NEW` acquires a **second** connection while suspending the first — both connections are held simultaneously. With `maximum-pool-size=20` and 10 concurrent REQUIRES_NEW calls, you can exhaust all 20 connections.
- External API calls, file I/O, or long computations inside `@Transactional` exhaust the pool.
- Always set `@Transactional(timeout = 30)` on batch methods to prevent indefinite connection holding.

### Transaction Ownership: MVC vs DDD/COLA

**MVC pattern** — transaction on ServiceImpl:

```java
// @Transactional on ServiceImpl method (MVC pattern)
@Service
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void create(CreateOrderCmd dto) {
        baseMapper.insert(order);
        orderItemService.saveBatch(items);
    }
}
```

**DDD/COLA pattern** — transaction on Application-layer CmdExe, NOT on GatewayImpl:

```java
// Domain gateway interface — NO transaction annotations
public interface OrderGateway {
    void save(Order order);     // INSERT only
    void update(Order order);   // UPDATE only — eliminates save/re-save ambiguity
    Optional<Order> findById(String id);
}

// Application CmdExe — transaction boundary HERE
@Component
@RequiredArgsConstructor
public class CreateOrderCmdExe {
    private final OrderGateway orderGateway;

    @Transactional(rollbackFor = Exception.class)
    public OrderDTO execute(CreateOrderCmd cmd) {
        Order order = Order.create(cmd.getItems(), cmd.getCustomerId());
        orderGateway.save(order);
        return OrderDTO.from(order);
    }
}

// Infrastructure gateway impl — NO transaction annotations (thin persistence adapter)
@Repository
@RequiredArgsConstructor
public class OrderGatewayImpl implements OrderGateway {
    private final OrderMapper orderMapper;

    @Override
    public void save(Order order) {
        orderMapper.insert(OrderDO.fromDomain(order));
    }

    @Override
    public void update(Order order) {
        orderMapper.updateById(OrderDO.fromDomain(order));
    }
}
```

**Why DDD Gateway pattern is superior for transaction management**:
1. **Explicit transaction ownership** — CmdExe clearly declares where the transaction starts/ends
2. **Gateway `save()` covers both insert and update** — determines by checking ID (null = insert, non-null = update). No separate `save()` + `update()` methods
3. **GatewayImpl stays thin** — pure persistence adapter with no transaction annotations, no business logic

### Example 8: Self-invocation pitfall — why @Transactional doesn't work on internal calls

```java
/**
 * ❌ Wrong example: self-invocation causes @Transactional to be ineffective
 * <p>Spring AOP is proxy-based; same-class internal method calls bypass the proxy, @Transactional annotation is silently ignored</p>
 */
@Service
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    /**
     * Payment flow — internal call to processRefund(), the latter's transaction annotation is ineffective
     */
    public void handlePayment(PaymentDTO dto) {
        PaymentDO payment = PaymentConverter.toDO(dto);
        baseMapper.insert(payment);

        // ❌ this.processRefund() bypasses Spring AOP proxy
        // Even though processRefund() has @Transactional, it will not take effect
        this.processRefund(payment.getId(), dto.getRefundAmount());
    }

    /** ❌ @Transactional here will not be intercepted by the proxy (self-invocation) */
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void processRefund(Long paymentId, BigDecimal amount) {
        // Refund logic — but transaction annotation is ineffective!
    }
}

/**
 * ✅ Correct approach: extract independent transaction logic to a separate Service bean
 * <p>By injecting other Services for invocation, ensures calls go through Spring AOP proxy</p>
 */
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    private final RefundService refundService;  // ✅ Inject independent service

    public void handlePayment(PaymentDTO dto) {
        PaymentDO payment = PaymentConverter.toDO(dto);
        baseMapper.insert(payment);

        // ✅ Invoke refundService through Spring proxy, @Transactional takes effect
        refundService.processRefund(payment.getId(), dto.getRefundAmount());
    }
}

@Service
@RequiredArgsConstructor
public class RefundServiceImpl extends ServiceImpl<RefundMapper, RefundDO> implements RefundService {

    /** ✅ @Transactional on independent bean will be properly intercepted by proxy */
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

## Constraints and Warnings

- **Self-invocation**: `@Transactional` on same-class method calls is silently ignored. Spring AOP proxies intercept external calls only; `this.internalMethod()` bypasses the proxy entirely. Fix: extract to a separate Service bean or use `AopContext.currentProxy()` (requires `@EnableAspectJAutoProxy(exposeProxy = true)`).
- **Nested transactions**: `Propagation.NESTED` requires a single DataSource and is not available with JTA-managed transactions. It uses database savepoints internally.
- **Seata for distributed transactions**: CAUTION — only use when truly distributed across multiple services that must be atomically consistent. Seata adds significant complexity (undo_log table, global lock, performance overhead) and risk of partial commit. Prefer local transaction + Outbox + Saga for microservices. See `references/distributed-transaction-patterns.md` for full comparison of Saga vs 2PC and choreography vs orchestration patterns.
- **Transaction timeout**: always set a timeout for long-running transactions (`@Transactional(timeout = 30)`) to prevent connection pool exhaustion from stuck or slow transactions.
- **Never catch exceptions inside `@Transactional` methods and swallow them** — this prevents rollback because the proxy only sees a normal method return. Either re-throw the exception or use `TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()` to force rollback.
- **Re-save after in-transaction modification**: modifying a persisted entity's fields within the same `@Transactional` method does NOT auto-persist the changes. MyBatis-Plus has no auto-flush/dirty-checking. After `save(record)` then `record.setXxx()`, call `updateById(record)` to persist changes. Do NOT call `save()` again — `save()` = INSERT and will cause primary key conflict on an already-inserted record.
- **Connection pool pressure from REQUIRES_NEW**: `Propagation.REQUIRES_NEW` acquires a second connection while suspending the first. Use only for independent audit/logging. With HikariCP `maximum-pool-size=20`, 10 concurrent REQUIRES_NEW calls can exhaust all connections.
- **MQ publish inside @Transactional**: Never send MQ messages directly inside a `@Transactional` method. RabbitMQ/Kafka are not Spring transaction resources — the message may be sent before DB commit (consumer can't find data) or before DB rollback (ghost message). Use `TransactionSynchronizationManager.registerSynchronization` with `afterCommit` callback. For stronger guarantees, use Outbox pattern or RabbitMQ `channelTransacted=true` (see `spring-boot-event-driven-patterns` and `spring-boot-amqp`).
- **IService internal transactions**: `saveBatch/saveOrUpdateBatch` have internal `@Transactional`; single methods (`save/updateById/removeById`) do NOT — add `@Transactional(rollbackFor=Exception.class)` on your method for multi-step writes
- **Do not add `@Transactional(readOnly = true)` on pure query methods** — unnecessary proxy overhead, no optimization benefit for MyBatis
- Keep transaction scope minimal — wrap only DB operations. Exclude external API calls, file I/O, and long computations from transactional boundaries.
- **Use `TransactionTemplate` for fine-grained programmatic control** — when conditional transaction boundaries or partial success is needed
- **Place `@Transactional` on ServiceImpl methods (MVC) or CmdExe methods (DDD/COLA)**, not on interfaces or GatewayImpl
- **Configure HikariCP leak-detection** — `leak-detection-threshold: 60000` catches connections held longer than expected

### Example 9: Re-saving modified entity within same transaction

```java
@Service
@RequiredArgsConstructor
public class PushCmdExe {

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
> In DDD Gateway pattern, `save()` covers both insert and update — determined by checking ID (null = insert, non-null = update).

### Example 10: Publishing MQ after transaction commit

RabbitMQ/Kafka are NOT Spring transaction resources — they don't participate in DB transaction commit/rollback. Publishing MQ directly inside `@Transactional` causes two problems:

| Problem | Description |
|---|---|
| **Ghost message** | DB rolls back but MQ message was already sent — downstream receives event for data that doesn't exist |
| **Premature delivery** | MQ message arrives at consumer before DB transaction commits — consumer can't find the record |

```java
// ❌ Anti-pattern: MQ publish inside @Transactional — no coordination with DB transaction
@Transactional(rollbackFor = Exception.class)
public void collectTrack(ChannelCode channelCode, Long trackingId, String sourceData) {
    callbackRecordGateway.saveCollectRecord(record);
    passbackProducerService.sendPassbackMessage(record.getId());  // ❌ may send before DB commit or rollback
}
```

**Fix**: Use `TransactionSynchronizationManager.registerSynchronization` with `afterCommit` — MQ only sends after DB commit succeeds:

```java
@Transactional(rollbackFor = Exception.class)
public void collectTrack(ChannelCode channelCode, Long trackingId, String sourceData) {
    Tracking tracking = trackingGateway.findById(trackingId)
            .orElseThrow(() -> new NotFoundException(ErrorCodes.TRACKING_NOT_FOUND, trackingId));

    CollectRecord record = CollectRecord.builder()
            .trackingId(trackingId).type(TrackingType.TRACK)
            .channelCode(channelCode).sourceData(sourceData).status("PENDING").build();

    callbackRecordGateway.saveCollectRecord(record);

    // ✅ afterCommit — MQ only sends after DB commit succeeds
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override
        public void afterCommit() {
            passbackProducerService.sendPassbackMessage(record.getId());
        }
    });
}
```

Behavior:
- DB rollback → `afterCommit` not triggered → MQ not sent
- DB commit → `afterCommit` triggered → MQ sent
- MQ transient failure → MQ internal retry handles it

> **For mission-critical events** where MQ publish failure must never lose a message, use the Outbox pattern (`spring-boot-event-driven-patterns` → `references/outbox-pattern.md`) which guarantees eventual delivery via atomic event storage + scheduled publisher.
>
> **Alternative**: RabbitMQ `channelTransacted=true` makes the MQ channel participate in Spring transaction coordination — DB and MQ commit/rollback atomically. Simpler than Outbox, but slower throughput and ties DB success to MQ broker availability. See `spring-boot-amqp`.

## References

- `references/transaction-propagation-scenarios.md`
- `references/rollback-rules-and-exceptions.md`
- `references/distributed-transaction-patterns.md`

## Related Skills

- `spring-boot-async-processing` — async + transaction boundary: @Async methods run outside the caller's transaction
- `spring-boot-event-driven-patterns` — @TransactionalEventListener for event publishing after commit
- `ddd-event-driven` — domain events as alternative to distributed transactions for cross-service consistency

## Keywords

transaction, propagation, isolation, rollback, @Transactional, TransactionTemplate, Seata, self-invocation, nested, readOnly, rollbackFor, noRollbackFor, savepoint, distributed transaction, saga, outbox, choreography, orchestration, compensating transaction, idempotency, Axon, 2PC, HikariCP, connection pool, REQUIRES_NEW, NESTED, SUPPORTS, setRollbackOnly, IService, saveBatch, afterCommit, MQ publish timing, ghost message, TransactionSynchronizationManager