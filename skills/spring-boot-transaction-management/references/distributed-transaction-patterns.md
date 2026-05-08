# Distributed Transaction Patterns

When you need cross-service data consistency, and when you do not.

## When You Actually Need Distributed Transactions

Distributed transactions are only needed when **multiple services must atomically modify their own databases** and partial success is unacceptable. Examples:

- **Order service creates order** + **Payment service charges payment** — both must succeed or both must fail
- **Inventory service deducts stock** + **Order service confirms order** — partial failure leaves inconsistent state

In single-service scenarios (one database), local transactions are sufficient. Never introduce distributed transaction frameworks for single-database operations.

## Saga vs Two-Phase Commit (2PC)

| Feature | Saga Pattern | Two-Phase Commit (2PC/Seata AT) |
|---------|-------------|-------------------------------|
| Locking | No distributed locks | Requires global locks during commit |
| Performance | Better performance — no lock contention | Performance bottleneck — global locks block concurrent writes |
| Scalability | Highly scalable across services | Limited scalability — lock contention increases with participants |
| Complexity | Business logic complexity (compensation design) | Protocol complexity (undo_log, Seata Server, global lock) |
| Failure Handling | Compensating transactions (business-level rollback) | Automatic rollback via undo_log (but risk of partial commit if TC crashes) |
| Isolation | Lower isolation — intermediate states visible | Full isolation during global transaction |
| NoSQL Support | Yes — each service chooses its own storage | No — requires relational undo_log table |
| Microservices Fit | Excellent — each service owns its data | Poor — tight coupling across service boundaries |

**Key insight**: Saga trades strong isolation for scalability and simplicity. 2PC trades scalability for strong isolation. Most microservice scenarios benefit from Saga.

## ACID vs BASE

**ACID** (Local Transactions — what `@Transactional` provides):
- **Atomicity**: All or nothing within a single service
- **Consistency**: Valid state transitions within one database
- **Isolation**: Concurrent transactions don't interfere
- **Durability**: Committed data persists

**BASE** (Saga Pattern — what distributed transactions achieve):
- **Basically Available**: System is available most of the time
- **Soft state**: State may change over time as compensations execute
- **Eventual consistency**: System reaches a consistent state eventually, not immediately

## Seata AT Mode Overview

Seata AT (Automatic Transaction) mode provides 2-phase commit with automatic undo:

```
Phase 1 (Branch Registration + Local Commit):
  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
  │   Order Service   │     │   Seata Server   │     │  Payment Service │
  │                   │     │   (TC - Coordinator)│   │                  │
  │ 1. Register branch│────▶│                  │     │                  │
  │ 2. Execute SQL    │     │                  │◀────│ 1. Register branch│
  │ 3. Generate undo  │     │                  │     │ 2. Execute SQL    │
  │ 4. Local commit   │     │                  │     │ 3. Generate undo  │
  │ 5. Report commit  │────▶│                  │◀────│ 4. Local commit   │
  └──────────────────┘     │                  │     │ 5. Report commit  │
                            └──────────────────┘     └──────────────────┘

Phase 2 (Global Commit or Rollback):
  - If all branches succeed → TC sends commit → each branch deletes undo_log
  - If any branch fails → TC sends rollback → each branch reads undo_log and reverses SQL
```

### Seata Setup Requirements

- **undo_log table**: each participating service database must have a `undo_log` table for storing before/after snapshots
- **Global lock**: Seata acquires global locks during Phase 1 to prevent dirty reads across services
- **Configuration**: requires Seata Server (TC), client SDK integration, and `@GlobalTransactional` annotation

```sql
-- Each service database must create undo_log table
CREATE TABLE undo_log (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    branch_id     BIGINT       NOT NULL,
    xid           VARCHAR(100) NOT NULL,
    context       VARCHAR(128) NOT NULL,
    rollback_info LONGBLOB     NOT NULL,
    log_status    INT          NOT NULL,
    log_created   DATETIME     NOT NULL,
    log_modified  DATETIME     NOT NULL,
    UNIQUE KEY ux_undo_log (xid, branch_id)
);
```

### Seata Caution

- **Performance impact**: global locks reduce throughput; Phase 1 local commit + global lock means other services cannot modify the same rows until Phase 2 completes
- **Complexity**: requires Seata Server deployment, undo_log table management, and careful configuration
- **Risk of partial commit**: if Seata Server crashes during Phase 2, some branches may have committed locally while others need rollback — manual intervention required
- **Business invasion**: `@GlobalTransactional` couples your code to Seata, making it harder to change or remove later

**Recommendation**: only use Seata when you have a genuine cross-service atomic consistency requirement that cannot be solved with eventual consistency.

## Saga Pattern: Choreography vs Orchestration

### Choreography (Event-Driven)

Each service produces and listens to events. No central coordinator manages the flow.

```
Service A → Event → Service B → Event → Service C
    ↓                   ↓                   ↓
Compensation       Compensation        Compensation
```

**When to use**:
- Few participants (< 5 services per saga)
- Loose coupling is critical
- Team experienced with event-driven architecture
- System can handle eventual consistency

**Advantages**: simple, no single point of failure, independently deployable
**Disadvantages**: hard to track workflow state, difficult to troubleshoot, complexity grows with service count

```java
/**
 * 编排式 Saga：订单服务监听支付结果
 * <p>每个服务自主决定下一步动作，无中央协调器</p>
 */
@Service
@RequiredArgsConstructor
public class OrderEventHandler {

    private final OrderService orderService;
    private final KafkaTemplate<String, Object> kafka;

    /**
     * 监听支付完成事件 → 触发库存预留
     */
    @KafkaListener(topics = "payment.processed", groupId = "order-service")
    public void onPaymentProcessed(PaymentProcessedEvent event) {
        try {
            InventoryReservedEvent result = orderService.reserveInventory(event.toInventoryRequest());
            kafka.send("inventory.reserved", result);
        } catch (InsufficientInventoryException e) {
            // 库存不足 → 发布补偿事件
            kafka.send("inventory.insufficient",
                new InsufficientInventoryEvent(event.getOrderId(), event.getPaymentId()));
        }
    }
}
```

### Orchestration (Centralized Coordinator)

A saga orchestrator manages the entire workflow, sending commands to participants and handling responses.

```
┌────────────────────────────┐
│     Saga Orchestrator      │
│  (OrderSagaOrchestrator)   │
│                            │
│  START → Order → Payment → │
│  Inventory → Shipment      │
│                            │
│  On failure:               │
│  Cancel → Refund → Release │
└────────────────────────────┘
```

**When to use**:
- Complex workflows with many participants
- Need centralized monitoring and state tracking
- Brownfield systems with existing service boundaries
- Business process requires clear audit trail

**Advantages**: clear workflow visibility, easier monitoring, centralized state management
**Disadvantages**: orchestrator can become a single point of failure, additional infrastructure dependency

| Approach | Use Case | Recommended Stack |
|----------|----------|-------------------|
| Choreography | < 5 participants, greenfield, loose coupling | Spring Cloud Stream + Kafka/RocketMQ |
| Orchestration | Complex workflows, brownfield, monitoring needs | Axon Framework, Camunda, custom orchestrator |

```java
/**
 * 协调式 Saga：中央编排器管理订单流程
 * <p>所有步骤由编排器控制，失败时触发补偿链</p>
 */
@Service
@RequiredArgsConstructor
public class OrderSagaOrchestrator {

    private final KafkaTemplate<String, Object> kafka;
    private final SagaStateRepository sagaStateRepo;

    /**
     * 启动订单 Saga
     */
    public void startSaga(OrderRequest request) {
        String sagaId = UUID.randomUUID().toString();
        sagaStateRepo.save(new SagaState(sagaId, SagaStatus.STARTED, LocalDateTime.now()));
        kafka.send("saga.order.start", new StartOrderSagaCommand(sagaId, request));
    }

    /**
     * 处理支付失败 → 触发补偿链
     */
    @KafkaListener(topics = "payment.failed")
    public void handlePaymentFailed(PaymentFailedEvent event) {
        kafka.send("order.compensate", new CompensateOrderCommand(event.getSagaId()));
        kafka.send("inventory.compensate", new ReleaseInventoryCommand(event.getSagaId()));
        sagaStateRepo.updateStatus(event.getSagaId(), SagaStatus.FAILED);
    }
}
```

## Orchestration with Axon Framework

For complex orchestrations with many participants, Axon Framework provides event sourcing, CQRS, and saga management out of the box:

```java
/**
 * Axon Framework Saga：订单流程编排
 * <p>Axon 自动管理 Saga 生命周期和状态持久化</p>
 */
@Saga
public class OrderManagementSaga {

    @Autowired
    private transient CommandGateway commandGateway;

    @StartSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void handle(OrderCreatedEvent event) {
        // 步骤1：发起支付命令
        commandGateway.send(new ProcessPaymentCommand(event.getOrderId(), event.getTotalAmount()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(PaymentCompletedEvent event) {
        // 步骤2：支付成功 → 发起库存预留命令
        commandGateway.send(new ReserveInventoryCommand(event.getOrderId()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(InventoryReservedEvent event) {
        // 步骤3：库存预留成功 → 发起发货命令
        commandGateway.send(new PrepareShipmentCommand(event.getOrderId()));
        // 流程完成，结束 Saga
        SagaLifecycle.end();
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(PaymentFailedEvent event) {
        // 补偿：支付失败 → 取消订单
        commandGateway.send(new CancelOrderCommand(event.getOrderId(), event.getReason()));
        SagaLifecycle.end();
    }
}
```

**Axon advantages**: automatic saga lifecycle, event sourcing for full audit trail, dead-letter handling, saga state persistence. Use when you need a production-grade saga engine rather than hand-rolling one with Kafka.

## Compensating Transactions — Idempotency Is Critical

Every forward operation MUST have a corresponding compensating transaction. Compensating transactions MUST be **idempotent** — they must produce the same result regardless of how many times they execute.

```java
/**
 * 支付补偿：退款操作 — 必须幂等
 * <p>使用数据库约束确保重复调用不会重复退款</p>
 */
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    private final OutboxEventPublisher outboxEventPublisher;

    /**
     * 处理支付（正向操作）
     */
    @Transactional(rollbackFor = Exception.class)
    public void processPayment(PaymentRequest request) {
        PaymentDO payment = new PaymentDO();
        payment.setOrderId(request.getOrderId());
        payment.setAmount(request.getAmount());
        payment.setStatus(PaymentStatus.COMPLETED);
        baseMapper.insert(payment);

        outboxEventPublisher.publish("PaymentProcessedEvent", payment.getId(),
            new PaymentProcessedEvent(payment.getId(), request.getOrderId()));
    }

    /**
     * 退款补偿 — 幂等实现
     * <p>使用状态检查确保已退款的支付不会重复退款</p>
     */
    @Transactional(rollbackFor = Exception.class)
    public void refundPayment(String paymentId) {
        baseMapper.selectById(paymentId).ifPresent(payment -> {
            // 幂等检查：如果已经退款，跳过（不抛异常）
            if (payment.getStatus() == PaymentStatus.REFUNDED) {
                return;
            }
            payment.setStatus(PaymentStatus.REFUNDED);
            baseMapper.updateById(payment);

            outboxEventPublisher.publish("PaymentRefundedEvent", paymentId,
                new PaymentRefundedEvent(paymentId));
        });
    }
}
```

### Idempotency Strategies

| Strategy | Implementation | When to Use |
|----------|---------------|-------------|
| Status guard | Check data object state before action (as above) | Most common — simple and reliable |
| Deduplication table | Insert (requestId, action) with UNIQUE constraint | When no suitable data object state field |
| Version check | Optimistic locking with @Version field | When concurrent compensation possible |

## Local Transaction + Outbox Pattern (Recommended for Microservices)

The Outbox pattern guarantees that **business data and event records are persisted in the same local transaction**, then a separate process publishes events to the message broker:

```
┌───────────────────────────────────────────────────────────────┐
│  Service A (Order)                                            │
│                                                               │
│  @Transactional:                                              │
│  1. INSERT order → order table                                │
│  2. INSERT event → outbox_event table (same transaction)      │
│  3. COMMIT local transaction                                  │
│                                                               │
│  ┌─────────────────┐                                          │
│  │  Outbox Poller  │  ← separate thread/scheduled task        │
│  │  (or CDC with   │                                          │
│  │   Debezium)     │                                          │
│  └────────┬────────┘                                          │
│           │ reads pending events                              │
│           │ publishes to Kafka/RocketMQ                       │
│           │ marks events as PUBLISHED                         │
└───────────┼───────────────────────────────────────────────────┘
            │
            ▼ message broker
            │
┌───────────┼───────────────────────────────────────────────────┐
│  Service B (Payment)                                          │
│                                                               │
│  @EventListener / @KafkaListener:                             │
│  1. Receive OrderCreatedEvent                                 │
│  2. Process payment (local transaction)                       │
│  3. INSERT payment + outbox event (same transaction)          │
│  4. COMMIT                                                    │
│                                                               │
│  If payment fails → publish PaymentFailedEvent                │
│  → Service A compensates (cancel order)                       │
└───────────────────────────────────────────────────────────────┘
```

### Outbox Event Table Schema

```sql
CREATE TABLE outbox_event (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    event_type    VARCHAR(200) NOT NULL,
    aggregate_id  VARCHAR(200) NOT NULL,
    payload       TEXT         NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',  -- PENDING, PUBLISHED, FAILED
    created_at    DATETIME     NOT NULL,
    published_at  DATETIME     NULL,
    INDEX idx_outbox_status (status, created_at)
);
```

### Outbox Event Publisher Implementation

```java
/**
 * Outbox 事件发布器
 * <p>将域事件写入 Outbox 表，与业务数据在同一事务中</p>
 */
@Component
@RequiredArgsConstructor
public class OutboxEventPublisher {

    private final OutboxEventMapper outboxEventMapper;

    public void publish(String eventType, Long aggregateId, Object payload) {
        OutboxEventDO event = new OutboxEventDO();
        event.setEventType(eventType);
        event.setAggregateId(aggregateId);
        event.setPayload(JsonUtils.toJson(payload));
        event.setStatus(OutboxStatus.PENDING);
        event.setCreatedAt(LocalDateTime.now());
        outboxEventMapper.insert(event);
    }
}
```

### Outbox Poller (Event Relay to Message Broker)

```java
/**
 * Outbox 事件轮询器
 * <p>定时扫描 PENDING 状态的事件，发送到 Kafka/RocketMQ</p>
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class OutboxEventPoller {

    private final OutboxEventMapper outboxEventMapper;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Scheduled(fixedDelay = 1000)  // 每 1 秒扫描一次
    @Transactional(rollbackFor = Exception.class)
    public void pollAndPublish() {
        LambdaQueryWrapper<OutboxEventDO> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(OutboxEventDO::getStatus, OutboxStatus.PENDING)
               .orderByAsc(OutboxEventDO::getCreatedAt)
               .last("LIMIT 100");  // 每次最多处理 100 条

        List<OutboxEventDO> events = outboxEventMapper.selectList(wrapper);
        for (OutboxEventDO event : events) {
            try {
                kafkaTemplate.send(event.getEventType(), event.getPayload()).get();
                event.setStatus(OutboxStatus.PUBLISHED);
                event.setPublishedAt(LocalDateTime.now());
                outboxEventMapper.updateById(event);
            } catch (Exception e) {
                log.error("发布事件失败: eventType={}, eventId={}", event.getEventType(), event.getId(), e);
                // 失败事件保留 PENDING 状态，下次重试
            }
        }
    }
}
```

## Saga State Management

Track saga execution status to enable monitoring, recovery, and troubleshooting:

```java
/**
 * Saga 状态实体
 * <p>持久化 Saga 流程状态，用于监控和故障恢复</p>
 */
@Data
@TableName("saga_state")
public class SagaStateDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
    private String sagaId;
    private String sagaType;          // e.g., "OrderCreateSaga"
    private SagaStatus status;        // STARTED, COMPLETED, COMPENSATING, FAILED
    private Integer currentStep;      // 当前执行步骤编号
    private String lastError;         // 最近一次失败的错误信息
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
```

| Status | Meaning | Action |
|--------|---------|--------|
| STARTED | Saga initiated, forward steps executing | Monitor progress |
| COMPLETED | All forward steps succeeded | No action needed |
| COMPENSATING | A forward step failed, compensations executing | Monitor compensation completion |
| FAILED | Compensation failed or saga stuck | Manual intervention required |

**Alert rule**: if a saga stays in STARTED or COMPENSATING for longer than the expected SLA duration, trigger an alert.

## Kafka Configuration for Saga Events

Configure Kafka with idempotent producers and exactly-once consumer semantics:

```java
@Configuration
@EnableKafka
public class KafkaSagaConfig {

    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);  // 幂等生产者
        props.put(ProducerConfig.TRANSACTIONAL_ID_CONFIG, "saga-producer");  // 事务性生产者
        return new DefaultKafkaProducerFactory<>(props);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, Object> kafkaListenerContainerFactory(
            ConsumerFactory<String, Object> consumerFactory) {
        ConcurrentKafkaListenerContainerFactory<String, Object> factory =
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory);
        factory.setCommonErrorHandler(new DefaultErrorHandler(
            new FixedBackOff(1000L, 3L)));  // 重试 3 次，间隔 1 秒
        return factory;
    }
}
```

## Event Classes (Immutable with Java Records)

```java
// 使用 Java record 确保事件不可变
public record OrderCreatedEvent(String orderId, BigDecimal totalAmount, List<String> items) {}
public record PaymentProcessedEvent(String paymentId, String orderId) {}
public record PaymentFailedEvent(String orderId, String reason) {}
public record InventoryReservedEvent(String reservationId, String orderId) {}
public record InsufficientInventoryEvent(String orderId, String paymentId) {}
```

## Monitoring and Observability

Track saga execution metrics:

```java
@Configuration
public class SagaMetricsConfig {
    @Bean
    public MeterRegistry meterRegistry() {
        return new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
    }
}
```

Metrics to track:
- **Saga execution duration** — alert when exceeding SLA
- **Compensation count** — rising count indicates service instability
- **Failure rate** — percentage of sagas ending in FAILED status
- **Stuck sagas** — sagas in STARTED or COMPENSATING for longer than threshold

## When NOT to Use Distributed Transactions

- **Single service, single database**: local `@Transactional` is sufficient — no distributed framework needed
- **Cross-service reads only**: if one service only reads from another service's API, there is no consistency requirement for atomic writes
- **Acceptable eventual consistency**: if business requirements tolerate a few seconds of inconsistency (e.g., "order shows pending for a moment until payment confirms"), use events instead of distributed transactions
- **High throughput scenarios**: global locks in Seata significantly reduce throughput; event-driven patterns with eventual consistency perform much better
- **Prototype/MVP**: do not introduce Seata or Saga complexity early; start with local transactions and events, add distributed coordination only when proven necessary

## Decision Guide: Local vs Saga vs 2PC

| Scenario | Recommendation |
|---|---|
| Single service, single DB | `@Transactional` (local) — always start here |
| Multiple services, eventual consistency OK | Local transaction + Outbox + Saga (choreography) |
| Complex multi-service workflows, monitoring needed | Local transaction + Outbox + Saga (orchestration / Axon) |
| Multiple services, atomic consistency required | Seata AT (with caution — only when eventual consistency truly unacceptable) |
| Multiple services, high throughput | Local transaction + Outbox + Saga (avoid global locks) |
| Cross-service reads only | No transaction needed — just API calls |

**Default choice**: always start with local transaction + Outbox + Saga. Only introduce Seata when you can prove that eventual consistency is unacceptable for the specific business scenario.