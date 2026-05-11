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

3. **NOT add `@Transactional` on pure query methods** — MyBatis-Plus has no persistence context (unlike JPA/Hibernate), so `readOnly = true` provides no flush/dirty-check optimization. Single and multi-step queries run fine on auto-commit. Only add `@Transactional` when you need a consistent snapshot across multi-step queries; on PostgreSQL (READ_COMMITTED default) add `isolation = Isolation.REPEATABLE_READ` explicitly, on MySQL (REPEATABLE_READ default) the default isolation already provides consistent snapshots.


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

> **saveBatch joins outer transaction**: When called from within your own `@Transactional` method, `saveBatch` joins the existing transaction (REQUIRED propagation) — not a separate scope.

> **saveBatch is NOT multi-row INSERT**: `saveBatch` loops through individual `INSERT` statements, not a single `INSERT INTO ... VALUES (...),(...)`. For truly efficient bulk inserts, use a custom SQL injector method.

### Programmatic TransactionTemplate approach

When declarative `@Transactional` does not fit (e.g., conditional transaction boundaries, varying propagation within a single method), use `TransactionTemplate` (auto-configured by Spring Boot):

```java
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    private final TransactionTemplate transactionTemplate;

    public void processOrder(OrderCommand cmd) {
        if (cmd.isDryRun()) {
            validateOnly(cmd);
        } else {
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
| `SUPPORTS` | Reusable methods that must participate in an existing transaction but also work standalone — NOT for simple single-query methods (those skip `@Transactional` entirely) |
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
/** Order service — multi-step write requires single transaction */
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void create(CreateOrderCmd dto) {
        OrderDO order = OrderConverter.toDO(dto);
        baseMapper.insert(order);
        orderItemService.saveBatch(OrderConverter.toItemDOs(dto.getItems(), order.getId()));
    }
}
```

### Example 2: @Transactional for consistent snapshot (rare — only when business requires)

```java
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {

    /** Single SQL — NOT add @Transactional, auto-commit is sufficient */
    @Override
    public UserDO findByEmail(String email) {
        return lambdaQuery().eq(UserDO::getEmail, email).one();
    }

    /** Paginated query — auto-commit sufficient for most queries */
    @Override
    public PageResult<UserVO> page(int pageNum, int pageSize, UserQry query) {
        LambdaQueryWrapper<UserDO> wrapper = lambdaQuery()
            .like(StringUtils.hasText(query.getUsername()), UserDO::getUsername, query.getUsername())
            .eq(query.getStatus() != null, UserDO::getStatus, query.getStatus())
            .orderByDesc(UserDO::getCreatedAt);
        Page<UserDO> mpPage = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return PageResult.of(mpPage).map(UserConverter::toVO);
    }

    /** Multi-step revenue report — needs consistent snapshot across queries */
    @Override
    @Transactional(isolation = Isolation.REPEATABLE_READ, rollbackFor = Exception.class)
    public RevenueReportVO getYearlyRevenueReport(int year) {
        BigDecimal q1Revenue = calculateQuarterRevenue(year, 1);
        BigDecimal q2Revenue = calculateQuarterRevenue(year, 2);
        return new RevenueReportVO(q1Revenue, q2Revenue);
    }
}
```

> **MyBatis-Plus vs JPA**: MyBatis has no persistence context — no auto-flush, no dirty-checking. 1) Pure queries don't need `@Transactional`. 2) `readOnly = true` provides no optimization for MyBatis — no flush cycles to skip. 3) Consistent snapshot requires proper isolation: PostgreSQL (READ_COMMITTED default) needs `Isolation.REPEATABLE_READ`; MySQL (REPEATABLE_READ default) already provides snapshot consistency.

### Example 3: Propagation.REQUIRES_NEW for independent sub-transactions (audit logging)

```java
/** Audit log — REQUIRES_NEW ensures logs commit independently of main transaction */
@Service
@RequiredArgsConstructor
public class AuditLogServiceImpl extends ServiceImpl<AuditLogMapper, AuditLogDO> implements AuditLogService {

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

/** Main business service — audit log persists even if main transaction rolls back */
@Service
@RequiredArgsConstructor
public class OrderServiceImpl extends ServiceImpl<OrderMapper, OrderDO> implements OrderService {

    private final AuditLogService auditLogService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long orderId) {
        OrderDO order = baseMapper.selectById(orderId);
        order.setStatus(OrderStatus.CANCELLED);
        baseMapper.updateById(order);
        auditLogService.log("CANCEL_ORDER", "Order:" + orderId, "Order cancelled");
    }
}
```

### Example 4: Rollback rules — rollbackFor checked exceptions

```java
/** File import — IOException is checked, must specify rollbackFor to trigger rollback */
@Service
@RequiredArgsConstructor
public class DataImportServiceImpl extends ServiceImpl<DataImportMapper, DataImportDO> implements DataImportService {

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void importFromCsv(String filePath) throws IOException {
        List<DataImportDO> dataObjects = parseCsv(filePath);  // may throw IOException
        saveBatch(dataObjects);
    }

    /** noRollbackFor — exclude specific exceptions (use sparingly) */
    @Override
    @Transactional(rollbackFor = Exception.class, noRollbackFor = BusinessException.class)
    public void processWithAcceptableError(Long id) {
        DataImportDO dataObject = baseMapper.selectById(id);
        validateAndProcess(dataObject);
    }
}
```

### Example 5: Propagation.NESTED for batch import tolerance

```java
/** Batch import — outer transaction, individual items use NESTED savepoints */
@Service
@RequiredArgsConstructor
public class DataImportServiceImpl extends ServiceImpl<DataImportMapper, DataImportDO> implements DataImportService {

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
        baseMapper.insert(UserConverter.toDO(dto));
    }
}
```

> **Constraint**: NESTED requires a single DataSource and JDBC 3.0 savepoint support. NOT available with JTA-managed transactions.

### Example 6: TransactionTemplate for batch tolerance (alternative to NESTED)

When NESTED is unavailable (JTA, multiple DataSource), use `TransactionTemplate` for independent item-level transactions:

```java
@Service
@RequiredArgsConstructor
public class DataImportServiceImpl extends ServiceImpl<DataImportMapper, DataImportDO> implements DataImportService {

    private final TransactionTemplate transactionTemplate;

    /** Batch import with tolerance — each item in independent transaction */
    public void batchImportWithTolerance(List<UserImportDTO> dtoList) {
        for (UserImportDTO dto : dtoList) {
            try {
                transactionTemplate.execute(status -> {
                    importSingleItem(dto);
                    return null;
                });
            } catch (Exception e) {
                log.warn("Item import failed, continuing: id={}", dto.getId(), e);
            }
        }
    }
}
```

### Example 7: Force rollback with setRollbackOnly() inside catch block

```java
/** Catch exception inside @Transactional but still force rollback */
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
            TransactionAspectSupport.currentTransactionStatus().setRollbackOnly();
        }
    }
}
```

> **Prefer re-throwing** over `setRollbackOnly()` — cleaner and lets callers handle the exception. Use `setRollbackOnly()` only when you need to log the error and mark rollback without propagating the exception.

### Connection Pool Considerations (HikariCP)

Transactions hold one HikariCP connection for their entire duration. Key configuration for MyBatis-Plus:

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      idle-timeout: 300000
      max-lifetime: 1800000
      connection-timeout: 30000
      leak-detection-threshold: 60000
```

**Critical impacts**:
- `Propagation.REQUIRES_NEW` acquires a **second** connection while suspending the first — both held simultaneously. With `maximum-pool-size=20` and 10 concurrent REQUIRES_NEW calls, you can exhaust all 20 connections.
- NOT place external API calls, file I/O, or long computations inside `@Transactional` — they exhaust the pool.
- Always set `@Transactional(timeout = 30)` on batch methods to prevent indefinite connection holding.

### Transaction Ownership: MVC vs DDD/COLA

**MVC pattern** — transaction on ServiceImpl:

```java
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
/** Domain gateway interface — NO transaction annotations */
public interface OrderGateway {
    void save(Order order);     // INSERT only
    void update(Order order);   // UPDATE only — eliminates save/re-save ambiguity
    Optional<Order> findById(String id);
}

/** Application CmdExe — transaction boundary HERE */
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

/** Infrastructure gateway impl — NO transaction annotations (thin persistence adapter) */
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

**DDD Gateway pattern advantages**: 1) Explicit transaction ownership — CmdExe declares where the transaction starts/ends. 2) Gateway provides separate `save()` for INSERT and `update()` for UPDATE — no ambiguity. 3) GatewayImpl stays thin — pure persistence adapter with no transaction annotations or business logic.

### Example 8: NOT self-invocation — @Transactional is silently ignored on internal calls

```java
/** Anti-pattern: self-invocation bypasses Spring AOP proxy */
@Service
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    public void handlePayment(PaymentDTO dto) {
        PaymentDO payment = PaymentConverter.toDO(dto);
        baseMapper.insert(payment);
        // Anti-pattern: this.processRefund() bypasses the Spring AOP proxy —
        // @Transactional on processRefund() is silently ignored
        this.processRefund(payment.getId(), dto.getRefundAmount());
    }

    /** @Transactional here NOT intercepted — self-invocation bypasses proxy */
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void processRefund(Long paymentId, BigDecimal amount) {
        // Refund logic — but transaction annotation is ineffective
    }
}

/** Fix: extract independent transaction logic to a separate Service bean */
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    private final RefundService refundService;

    public void handlePayment(PaymentDTO dto) {
        PaymentDO payment = PaymentConverter.toDO(dto);
        baseMapper.insert(payment);
        // Call through Spring proxy — @Transactional takes effect
        refundService.processRefund(payment.getId(), dto.getRefundAmount());
    }
}

@Service
@RequiredArgsConstructor
public class RefundServiceImpl extends ServiceImpl<RefundMapper, RefundDO> implements RefundService {

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

- **NOT self-invocation**: `@Transactional` on same-class method calls is silently ignored. Spring AOP proxies intercept external calls only; `this.internalMethod()` bypasses the proxy entirely. Fix: extract to a separate Service bean or use `AopContext.currentProxy()` (requires `@EnableAspectJAutoProxy(exposeProxy = true)`).
- **NESTED propagation**: requires a single DataSource and JDBC 3.0 savepoint support. NOT available with JTA-managed transactions.
- **NOT use Seata unless truly necessary**: Seata adds significant complexity (undo_log table, global lock, performance overhead) and risk of partial commit. Prefer local transaction + Outbox + Saga for microservices. See `references/distributed-transaction-patterns.md`.
- **NOT omit timeout on long transactions**: set `@Transactional(timeout = 30)` to prevent connection pool exhaustion from stuck transactions.
- **NOT catch and swallow exceptions inside `@Transactional`**: this prevents rollback — the proxy only sees a normal method return. Either re-throw the exception or use `TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()`.
- **NOT call save() twice on the same entity**: MyBatis-Plus has no auto-flush/dirty-checking. After `save(record)` then `record.setXxx()`, call `updateById(record)`. `save()` = INSERT — calling it twice causes primary key conflict.
- **REQUIRES_NEW connection pressure**: acquires a second connection while suspending the first. Use only for independent audit/logging. With HikariCP `maximum-pool-size=20`, 10 concurrent REQUIRES_NEW calls can exhaust all connections.
- **NOT publish MQ inside @Transactional**: RabbitMQ/Kafka are not Spring transaction resources — the message may be sent before DB commit (consumer can't find data) or before DB rollback (ghost message). Use `TransactionSynchronizationManager.registerSynchronization` with `afterCommit` callback, Outbox pattern, or RabbitMQ `channelTransacted=true`.
- **IService internal transactions**: `saveBatch/saveOrUpdateBatch` have internal `@Transactional`; single methods (`save/updateById/removeById`) do NOT — add `@Transactional(rollbackFor=Exception.class)` on your method for multi-step writes.
- **NOT add `@Transactional(readOnly = true)` on pure query methods** — unnecessary proxy overhead, no optimization benefit for MyBatis.
- **NOT place external API calls, file I/O, or long computations inside @Transactional** — wrap only DB operations.
- **Place `@Transactional` on ServiceImpl methods (MVC) or CmdExe methods (DDD/COLA)**, NOT on interfaces or GatewayImpl.
- **Configure HikariCP leak-detection** — `leak-detection-threshold: 60000` catches connections held longer than expected.

### Example 9: NOT call save() twice on the same entity within one transaction

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

        // NOT call save() again — MVC: save()=INSERT → PK conflict. DDD: use update().
        record.setRetryCount(record.getRetryCount() + 1);
        record.setNextRetryTime(LocalDateTime.now().plusMinutes(5));
        record.setStatus(PushStatus.RETRYING);
        recordGateway.update(record);
    }
}
```

> **Why**: MyBatis-Plus has no auto-flush/dirty-checking. Every state change requires an explicit call. MVC: `save()`=INSERT, `updateById()`=UPDATE. DDD: `save()`=INSERT, `update()`=UPDATE.

### Example 10: NOT publish MQ inside @Transactional — use afterCommit

RabbitMQ/Kafka are NOT Spring transaction resources — they don't participate in DB transaction commit/rollback:

| Problem | Description |
|---|---|
| **Ghost message** | DB rolls back but MQ message was already sent — downstream receives event for data that doesn't exist |
| **Premature delivery** | MQ message arrives at consumer before DB transaction commits — consumer can't find the record |

```java
/** Anti-pattern: MQ publish inside @Transactional — no coordination with DB transaction */
@Transactional(rollbackFor = Exception.class)
public void collectTrack(ChannelCode channelCode, Long trackingId, String sourceData) {
    callbackRecordGateway.saveCollectRecord(record);
    passbackProducerService.sendPassbackMessage(record.getId());  // NOT send MQ inside @Transactional
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

    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override
        public void afterCommit() {
            passbackProducerService.sendPassbackMessage(record.getId());
        }
    });
}
```

Behavior: DB rollback → `afterCommit` not triggered → MQ not sent. DB commit → `afterCommit` triggered → MQ sent. MQ transient failure → MQ internal retry handles it.

> **For mission-critical events**: use Outbox pattern (`spring-boot-event-driven-patterns`) which guarantees eventual delivery via atomic event storage + scheduled publisher.
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