# Distributed Transaction Patterns

When you need cross-service data consistency, and when you do not.

## When You Actually Need Distributed Transactions

Distributed transactions are only needed when **multiple services must atomically modify their own databases** and partial success is unacceptable. In single-service scenarios (one database), local transactions are sufficient.

**NOT introduce distributed transaction frameworks for single-database operations.**

## Saga vs Two-Phase Commit (2PC)

| Feature | Saga Pattern | 2PC (Seata AT) |
|---------|-------------|----------------|
| Locking | No distributed locks | Global locks during commit |
| Performance | Better — no lock contention | Bottleneck — global locks block concurrent writes |
| Complexity | Business logic (compensation design) | Protocol complexity (undo_log, Seata Server, global lock) |
| Failure Handling | Compensating transactions (business rollback) | Auto rollback via undo_log (risk of partial commit if TC crashes) |
| Isolation | Lower — intermediate states visible | Full isolation during global transaction |
| Microservices Fit | Excellent — each service owns its data | Poor — tight coupling across boundaries |

**Key insight**: Saga trades strong isolation for scalability. 2PC trades scalability for strong isolation. Most microservice scenarios benefit from Saga.

## Seata AT Mode Overview

Seata AT provides 2-phase commit with automatic undo:

```
Phase 1 (Branch Registration + Local Commit):
  Order Service ──register branch──▶ Seata Server (TC) ──register branch──◀ Payment Service
  Order: execute SQL, generate undo, local commit        Payment: execute SQL, generate undo, local commit

Phase 2 (Global Commit or Rollback):
  - All branches succeed → TC sends commit → each branch deletes undo_log
  - Any branch fails → TC sends rollback → each branch reads undo_log and reverses SQL
```

### Seata Setup Requirements

- **undo_log table**: each participating service database must have one
- **Global lock**: Seata acquires global locks during Phase 1 to prevent dirty reads
- **Configuration**: requires Seata Server (TC), client SDK, and `@GlobalTransactional`

```sql
-- undo_log table (MySQL; use TEXT for PostgreSQL on rollback_info column)
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

### NOT use Seata unless truly necessary

- **Performance impact**: global locks reduce throughput; other services cannot modify the same rows until Phase 2 completes
- **Complexity**: requires Seata Server deployment, undo_log table management, careful configuration
- **Risk of partial commit**: if Seata Server crashes during Phase 2, some branches may have committed locally while others need rollback — manual intervention required
- **Business invasion**: `@GlobalTransactional` couples your code to Seata, making it harder to change or remove later

**Recommendation**: only use Seata when you have a genuine cross-service atomic consistency requirement that CANNOT be solved with eventual consistency.

## Saga Pattern: Choreography vs Orchestration

### Choreography (Event-Driven)

Each service produces and listens to events. No central coordinator manages the flow.

**When to use**: < 5 participants per saga, loose coupling is critical, system can handle eventual consistency.

**Advantages**: simple, no single point of failure, independently deployable.
**Disadvantages**: hard to track workflow state, complexity grows with service count.

```java
/** Choreography Saga: Order service reacts to payment events */
@Service
@RequiredArgsConstructor
public class OrderEventHandler {

    private final OrderService orderService;
    private final KafkaTemplate<String, Object> kafka;

    @KafkaListener(topics = "payment.processed", groupId = "order-service")
    public void onPaymentProcessed(PaymentProcessedEvent event) {
        try {
            InventoryReservedEvent result = orderService.reserveInventory(event.toInventoryRequest());
            kafka.send("inventory.reserved", result);
        } catch (InsufficientInventoryException e) {
            kafka.send("inventory.insufficient",
                new InsufficientInventoryEvent(event.getOrderId(), event.getPaymentId()));
        }
    }
}
```

### Orchestration (Centralized Coordinator)

A saga orchestrator manages the entire workflow, sending commands to participants and handling responses.

**When to use**: complex workflows, need centralized monitoring and state tracking, clear audit trail required.

**Advantages**: clear workflow visibility, easier monitoring.
**Disadvantages**: orchestrator can become a single point of failure.

| Approach | Use Case | Recommended Stack |
|----------|----------|-------------------|
| Choreography | < 5 participants, loose coupling | Spring Cloud Stream + Kafka/RocketMQ |
| Orchestration | Complex workflows, monitoring needs | Axon Framework, Camunda, custom orchestrator |

```java
/** Orchestration Saga: Central orchestrator manages the order flow */
@Service
@RequiredArgsConstructor
public class OrderSagaOrchestrator {

    private final KafkaTemplate<String, Object> kafka;
    private final SagaStateRepository sagaStateRepo;

    public void startSaga(OrderRequest request) {
        String sagaId = UUID.randomUUID().toString();
        sagaStateRepo.save(new SagaState(sagaId, SagaStatus.STARTED, LocalDateTime.now()));
        kafka.send("saga.order.start", new StartOrderSagaCommand(sagaId, request));
    }

    /** Payment failure → trigger compensation chain */
    @KafkaListener(topics = "payment.failed")
    public void handlePaymentFailed(PaymentFailedEvent event) {
        kafka.send("order.compensate", new CompensateOrderCommand(event.getSagaId()));
        kafka.send("inventory.compensate", new ReleaseInventoryCommand(event.getSagaId()));
        sagaStateRepo.updateStatus(event.getSagaId(), SagaStatus.FAILED);
    }
}
```

## Orchestration with Axon Framework

For complex orchestrations, Axon Framework (4.10+ compatible with Spring Boot 3.5) provides event sourcing, CQRS, and saga management:

```java
/** Axon Saga: Order flow orchestration — Axon manages lifecycle and state persistence */
@Saga
public class OrderManagementSaga {

    private transient CommandGateway commandGateway;

    @StartSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void handle(OrderCreatedEvent event) {
        commandGateway.send(new ProcessPaymentCommand(event.getOrderId(), event.getTotalAmount()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(PaymentCompletedEvent event) {
        commandGateway.send(new ReserveInventoryCommand(event.getOrderId()));
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(InventoryReservedEvent event) {
        commandGateway.send(new PrepareShipmentCommand(event.getOrderId()));
        SagaLifecycle.end();
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(PaymentFailedEvent event) {
        commandGateway.send(new CancelOrderCommand(event.getOrderId(), event.getReason()));
        SagaLifecycle.end();
    }
}
```

**Axon advantages**: automatic saga lifecycle, event sourcing for full audit trail, dead-letter handling, saga state persistence. Use when you need a production-grade saga engine rather than hand-rolling one with Kafka.

## Compensating Transactions — Idempotency Is Critical

Every forward operation MUST have a corresponding compensating transaction. Compensating transactions MUST be **idempotent** — produce the same result regardless of how many times they execute.

```java
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl extends ServiceImpl<PaymentMapper, PaymentDO> implements PaymentService {

    private final OutboxEventPublisher outboxEventPublisher;

    /** Forward operation: process payment */
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

    /** Compensation: refund — idempotent via status guard */
    @Transactional(rollbackFor = Exception.class)
    public void refundPayment(Long paymentId) {
        PaymentDO payment = baseMapper.selectById(paymentId);
        if (payment == null || payment.getStatus() == PaymentStatus.REFUNDED) {
            return;  // Not found or already refunded — idempotency check
        }
        payment.setStatus(PaymentStatus.REFUNDED);
        baseMapper.updateById(payment);

        outboxEventPublisher.publish("PaymentRefundedEvent", paymentId,
            new PaymentRefundedEvent(paymentId));
    }
}
```

### Idempotency Strategies

| Strategy | Implementation | When to Use |
|----------|---------------|-------------|
| Status guard | Check data object state before action | Most common — simple and reliable |
| Deduplication table | Insert (requestId, action) with UNIQUE constraint | No suitable data object state field |
| Version check | Optimistic locking with @Version field | Concurrent compensation possible |

## Local Transaction + Outbox Pattern (Recommended for Microservices)

The Outbox pattern guarantees that **business data and event records are persisted in the same local transaction**, then a separate process publishes events to the message broker.

```
Service A (Order):
  @Transactional:
  1. INSERT order → order table
  2. INSERT event → outbox_event table (same transaction)
  3. COMMIT

  Outbox Poller (separate thread):
  → reads PENDING events
  → publishes to Kafka/RocketMQ
  → marks events as PUBLISHED
                │
                ▼ message broker
Service B (Payment):
  @EventListener / @KafkaListener:
  1. Receive OrderCreatedEvent
  2. Process payment (local transaction)
  3. INSERT payment + outbox event (same transaction)
  4. COMMIT

  If payment fails → PaymentFailedEvent → Service A compensates
```

### Outbox Event Table Schema

```sql
CREATE TABLE outbox_event (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    event_type    VARCHAR(200) NOT NULL,
    aggregate_id  BIGINT       NOT NULL,
    payload       TEXT         NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    created_at    DATETIME     NOT NULL,
    published_at  DATETIME     NULL,
    INDEX idx_outbox_status (status, created_at)
);
```

### Outbox Event Publisher Implementation

```java
/** Outbox Event Publisher — writes events to Outbox table within the same transaction */
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
/** Outbox Event Poller — periodically scans PENDING events and publishes to Kafka */
@Component
@RequiredArgsConstructor
@Slf4j
public class OutboxEventPoller {

    private final OutboxEventMapper outboxEventMapper;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Scheduled(fixedDelay = 1000)
    @Transactional(rollbackFor = Exception.class)
    public void pollAndPublish() {
        LambdaQueryWrapper<OutboxEventDO> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(OutboxEventDO::getStatus, OutboxStatus.PENDING)
               .orderByAsc(OutboxEventDO::getCreatedAt)
               .last("LIMIT 100");

        List<OutboxEventDO> events = outboxEventMapper.selectList(wrapper);
        for (OutboxEventDO event : events) {
            try {
                kafkaTemplate.send(event.getEventType(), event.getPayload()).get();
                event.setStatus(OutboxStatus.PUBLISHED);
                event.setPublishedAt(LocalDateTime.now());
                outboxEventMapper.updateById(event);
            } catch (Exception e) {
                log.error("Event publish failed: eventType={}, eventId={}", event.getEventType(), event.getId(), e);
            }
        }
    }
}
```

## Saga State Management

Track saga execution status for monitoring, recovery, and troubleshooting:

```java
@Data
@TableName("saga_state")
public class SagaStateDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
    private String sagaId;
    private String sagaType;
    private SagaStatus status;        // STARTED, COMPLETED, COMPENSATING, FAILED
    private Integer currentStep;
    private String lastError;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
```

| Status | Meaning | Action |
|--------|---------|--------|
| STARTED | Forward steps executing | Monitor progress |
| COMPLETED | All forward steps succeeded | No action |
| COMPENSATING | Compensations executing | Monitor completion |
| FAILED | Compensation failed or stuck | Manual intervention |

**Alert rule**: if a saga stays in STARTED or COMPENSATING for longer than the expected SLA, trigger an alert.

## Kafka Configuration for Saga Events

Spring Boot 3.5 auto-configures Kafka producers and consumers. Only customize when you need specific settings:

```yaml
spring:
  kafka:
    producer:
      properties:
        enable.idempotence: true               # Idempotent producer (Kafka client 3.0+ default true)
        transactional.id: ${spring.application.name}-${HOSTNAME:local}  # Unique per instance
    consumer:
      auto-offset-reset: earliest
    listener:
      ack-mode: manual_immediate
```

For custom error handling, configure `DefaultErrorHandler` via Spring Boot properties or a `@Bean`:

```java
@Configuration
public class KafkaSagaConfig {

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, Object> kafkaListenerContainerFactory(
            ConsumerFactory<String, Object> consumerFactory) {
        ConcurrentKafkaListenerContainerFactory<String, Object> factory =
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory);
        factory.setCommonErrorHandler(new DefaultErrorHandler(
            new FixedBackOff(1000L, 3L)));  // Retry 3 times, 1-second interval
        return factory;
    }
}
```

## Event Classes (Immutable with Java Records)

```java
public record OrderCreatedEvent(String orderId, BigDecimal totalAmount, List<String> items) {}
public record PaymentProcessedEvent(String paymentId, String orderId) {}
public record PaymentFailedEvent(String orderId, String reason) {}
public record InventoryReservedEvent(String reservationId, String orderId) {}
```

## Monitoring and Observability

Spring Boot 3.5 auto-configures Micrometer with Prometheus when the dependency is present. Track these saga metrics:

- **Saga execution duration** — alert when exceeding SLA
- **Compensation count** — rising count indicates service instability
- **Failure rate** — percentage of sagas ending in FAILED status
- **Stuck sagas** — sagas in STARTED or COMPENSATING past threshold

## NOT Use Distributed Transactions When

- **Single service, single database**: local `@Transactional` is sufficient
- **Cross-service reads only**: no consistency requirement for atomic writes
- **Acceptable eventual consistency**: use events instead of distributed transactions
- **High throughput**: global locks in Seata reduce throughput significantly
- **Prototype/MVP**: start with local transactions and events, add distributed coordination only when proven necessary

## Decision Guide: Local vs Saga vs 2PC

| Scenario | Recommendation |
|---|---|
| Single service, single DB | `@Transactional` (local) — always start here |
| Multiple services, eventual consistency OK | Local transaction + Outbox + Saga (choreography) |
| Complex multi-service workflows | Local transaction + Outbox + Saga (orchestration / Axon) |
| Multiple services, atomic consistency required | Seata AT (caution — only when eventual consistency unacceptable) |
| Multiple services, high throughput | Local transaction + Outbox + Saga (avoid global locks) |
| Cross-service reads only | No transaction needed — just API calls |

**Default choice**: always start with local transaction + Outbox + Saga. Only introduce Seata when you can prove that eventual consistency is unacceptable for the specific business scenario.