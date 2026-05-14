---
name: ddd-event-driven
description: "Domain-driven event architecture for Spring Boot: domain event design, event sourcing, CQRS, aggregate root event publishing, outbox pattern, snapshooting, projections. Use when designing event-driven architecture WITHIN a DDD domain, implementing event sourcing, or building CQRS read models. Do NOT use for simple request-response or when only inter-service messaging is needed (use spring-kafka instead)."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
parameters:
  - name: event_complexity
    description: "Which event model to use — determines how events are designed and published"
    type: enum
    values: ["simple_events", "aggregate_events", "event_sourcing"]
    required: true
  - name: use_projections
    description: "Whether to build separate read models from event streams (CQRS with projections)"
    type: boolean
    required: false
    default: false
  - name: use_outbox
    description: "Whether to use the outbox pattern for reliable event delivery"
    type: boolean
    required: false
    default: true
  - name: integration_with_cola
    description: "Whether this is used within a COLA DDD project (adjusts entity style and module layout)"
    type: boolean
    required: false
    default: true
---

# DDD Event-Driven Architecture

Domain-driven event architecture guidance — domain event design principles, event sourcing basics, CQRS separation, aggregate root event publishing, outbox pattern integration, snapshotting, projections, and common anti-patterns.

## When to use this skill

Use when designing event-driven architecture within a DDD domain — specifically when your domain entities need to publish events, you're evaluating event sourcing, or building CQRS read models with projections.

**Do NOT use when:**
- Only need inter-service messaging (Kafka/RocketMQ) without domain events → use `spring-kafka`
- Simple request-response pattern without domain complexity → use `spring-boot-rest-api-standards`
- Only need application-level events (not domain events) → use `spring-boot-event-driven-patterns`

**Decision tree — which event complexity level?**

```
Do you need to rebuild aggregate state from events? ──── YES → event_sourcing
        │
        NO
        │
Do aggregates publish multiple events per operation? ──── YES → aggregate_events
        │
        NO
        │
Do you just need to notify other services after a write? ──── YES → simple_events
```

| Level | Complexity | When to use |
|-------|-----------|-------------|
| **simple_events** | Low | Publish events after state change; no event replay needed; just notify other services |
| **aggregate_events** | Medium | Aggregate publishes 1+ events per operation; need consistent event collection; no replay |
| **event_sourcing** | High | Aggregate state derived from event replay; audit trail required; temporal queries needed |

## Instructions

### 1. Design domain events — what makes a good event

Domain events represent **facts that have happened** in the past. Follow these design rules:

```java
/**
 * Base domain event contract — every event carries an ID, timestamp, and correlation ID.
 */
public interface DomainEvent {
    UUID eventId();
    Instant occurredAt();
    UUID correlationId();
}

/**
 * Domain event — past tense naming, essential data only, immutable.
 */
public record OrderPlacedEvent(
    UUID eventId,
    Instant occurredAt,
    UUID correlationId,
    UUID orderId,
    UUID customerId,
    BigDecimal totalAmount,
    List<OrderItemSummary> items
) implements DomainEvent {
    public static OrderPlacedEvent of(UUID orderId, UUID customerId, BigDecimal totalAmount,
                                      List<OrderItemSummary> items, UUID correlationId) {
        return new OrderPlacedEvent(UUID.randomUUID(), Instant.now(), correlationId,
                                    orderId, customerId, totalAmount, items);
    }
}

public record OrderItemSummary(
    UUID productId,
    int quantity,
    BigDecimal unitPrice
) {}
```

**What makes a good domain event:**

| Characteristic | Good Event | Bad Event |
|---|---|---|
| Naming | Past tense: `OrderPlaced` | Imperative: `PlaceOrder` |
| Payload | Essential attributes only: `orderId`, `totalAmount` | Full entity: entire `Order` object |
| Immutability | All fields final, record class | Mutable POJO with setters |
| Sensitivity | No passwords, tokens, PII | Contains user email, SSN |
| Size | Lightweight (< 10 KB typical) | Large (embedded images, full documents) |
| Coupling | Generic, reusable by multiple consumers | Consumer-specific fields |

### 2. Publish events from aggregate roots

Aggregates collect domain events during business operations and release them for publication:

```java
/**
 * Aggregate root base class — collects domain events during operations,
 * releases them for external publication after the operation completes.
 */
public abstract class AggregateRoot {
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    /** Register an event during a business operation */
    protected void registerEvent(DomainEvent event) {
        this.domainEvents.add(event);
    }

    /** Get all collected events for publication */
    public List<DomainEvent> getDomainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    /** Clear events after they have been published */
    public void clearDomainEvents() {
        domainEvents.clear();
    }
}

/**
 * Order aggregate — publishes domain events as part of business operations.
 * <p>Events are registered INSIDE the business method, ensuring consistency
 * between state change and event generation.</p>
 */
public class Order extends AggregateRoot {
    private UUID id;
    private UUID customerId;
    private OrderStatus status;
    private BigDecimal total;
    private UUID correlationId;

    public void place(List<OrderItem> items) {
        if (status != OrderStatus.DRAFT) {
            throw new ConflictException("Order cannot be placed in status: " + status);
        }
        this.status = OrderStatus.PLACED;
        this.total = calculateTotal(items);
        registerEvent(OrderPlacedEvent.of(this.id, this.customerId, this.total,
                                          summarizeItems(items), this.correlationId));
    }

    public void cancel(String reason) {
        if (status == OrderStatus.COMPLETED) {
            throw new ConflictException("Completed order cannot be cancelled");
        }
        this.status = OrderStatus.CANCELLED;
        registerEvent(OrderCancelledEvent.of(this.id, reason, this.correlationId));
    }
}
```

In the application service, publish events after the aggregate is saved:

```java
@Service
@RequiredArgsConstructor
public class OrderApplicationService {
    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public void placeOrder(UUID orderId, List<OrderItem> items) {
        Order order = orderRepository.findById(orderId);
        order.place(items);
        orderRepository.save(order);

        // Publish all events collected by the aggregate
        order.getDomainEvents().forEach(eventPublisher::publishEvent);
        order.clearDomainEvents();
    }
}
```

### 3. Understand event sourcing basics

In event sourcing, aggregate state is **derived by replaying its event history** rather than stored directly:

```java
/**
 * Event-sourced aggregate — state is rebuilt from events.
 * <p>No mutable state fields are persisted; the event log IS the source of truth.</p>
 */
public class Account {
    private UUID id;
    private BigDecimal balance = BigDecimal.ZERO;
    private final List<DomainEvent> pendingEvents = new ArrayList<>();

    // --- Command handlers (produce events) ---
    public void deposit(BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ValidationException("Deposit amount must be positive");
        }
        MoneyDepositedEvent event = MoneyDepositedEvent.of(id, amount);
        apply(event);
        pendingEvents.add(event);
    }

    public void withdraw(BigDecimal amount) {
        if (balance.compareTo(amount) < 0) {
            throw new ConflictException("Insufficient funds");
        }
        MoneyWithdrawnEvent event = MoneyWithdrawnEvent.of(id, amount);
        apply(event);
        pendingEvents.add(event);
    }

    // --- Event appliers (rebuild state from events) ---
    public void apply(MoneyDepositedEvent event) {
        this.balance = this.balance.add(event.amount());
    }

    public void apply(MoneyWithdrawnEvent event) {
        this.balance = this.balance.subtract(event.amount());
    }

    // --- Reconstitute from event history ---
    public static Account reconstitute(UUID id, List<DomainEvent> events) {
        Account account = new Account();
        account.id = id;
        events.forEach(e -> {
            if (e instanceof MoneyDepositedEvent d) account.apply(d);
            else if (e instanceof MoneyWithdrawnEvent w) account.apply(w);
        });
        return account;
    }

    public static Account reconstituteFromSnapshot(AccountSnapshot snapshot,
                                                   List<DomainEvent> postSnapshotEvents) {
        Account account = new Account();
        account.id = snapshot.getAccountId();
        account.balance = snapshot.getBalance();
        postSnapshotEvents.forEach(e -> {
            if (e instanceof MoneyDepositedEvent d) account.apply(d);
            else if (e instanceof MoneyWithdrawnEvent w) account.apply(w);
        });
        return account;
    }

    public List<DomainEvent> getPendingEvents() {
        return List.copyOf(pendingEvents);
    }

    public void clearPendingEvents() {
        pendingEvents.clear();
    }
}
```

**When to choose event sourcing:**
- You need a complete audit trail of every state change
- You need temporal queries ("what was the account balance on Jan 15?")
- You need to rebuild state from events (bug fixes, retroactive corrections)
- You accept the added complexity (event storage, replay, migration)

**When NOT to choose event sourcing:**
- Simple CRUD operations where current state is sufficient
- Teams unfamiliar with the pattern (learning curve is steep)
- Read-heavy workloads without CQRS (replaying events for every read is expensive)

### 4. CQRS separation

CQRS separates the write model (commands, aggregates) from the read model (projections, queries):

```
Write Side:                              Read Side:
Command → Command Handler                Query → Query Handler
         → Aggregate                      → Read Model (Projection)
         → Events (persisted)
         → Event Published ────────────→  → Projection Handler
                                            → Updates Read Model
                                            → Optimized for queries

Benefits:
- Write model: focused on business rules, no query optimization burden
- Read model: optimized for specific queries, denormalized, fast
- Independent scaling: write and read can use different databases
- Independent evolution: add new projections without changing write model
```

```java
// Write side — command handler
@Service
@RequiredArgsConstructor
public class OrderCommandService {
    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public UUID placeOrder(PlaceOrderCommand cmd) {
        Order order = Order.create(cmd.customerId(), cmd.items());
        orderRepository.save(order);
        order.getDomainEvents().forEach(eventPublisher::publishEvent);
        order.clearDomainEvents();
        return order.getId();
    }
}

// Read side — query handler uses projection, not the aggregate
@Service
@RequiredArgsConstructor
public class OrderQueryService {
    private final OrderReadRepository readRepository;  // Separate read model

    public OrderSummary getOrderSummary(UUID orderId) {
        return readRepository.findSummaryById(orderId);  // Denormalized, query-optimized
    }

    public PageResult<OrderListEntry> searchOrders(OrderSearchCriteria criteria) {
        return readRepository.search(criteria);  // Optimized for list queries
    }
}
```

### 5. Outbox pattern integration for reliable delivery

The Outbox pattern guarantees that business data and events are always consistent by persisting events to an outbox table in the same local transaction as the aggregate. A separate poller then reads pending events and publishes them to the message broker. This eliminates the risk of event loss if the broker is unavailable at publish time.

**Key principle:** Never publish events directly to a message broker within a business transaction. Instead, write events to a local outbox table alongside the aggregate, then relay them asynchronously via a poller or CDC stream.

For detailed Outbox/Saga patterns, see `spring-boot-transaction-management` references/distributed-transaction-patterns.md.

### 6. Snapshotting for long event streams

When an aggregate has many events, replaying from the beginning becomes expensive. Snapshotting stores periodic state summaries to reduce replay time:

```java
// Domain-level snapshot value object (lives in domain module)
import lombok.Data;

@Data
public class AccountSnapshot {
    private UUID accountId;
    private BigDecimal balance;
    private Instant snapshotTimestamp;
    private long eventVersion;
}
```

Reconstitution from a snapshot is shown in `Account.reconstituteFromSnapshot(...)` above — load the latest snapshot, then replay only the events after `eventVersion`.

The corresponding persistence object (with `@TableName`) lives in the infrastructure module and is converted to/from the domain `AccountSnapshot` by the repository.

**Snapshotting guidelines:**
- Take a snapshot every N events (e.g., every 100 events) or on schedule
- Store snapshots in a separate table (not mixed with events)
- Always include the event version in the snapshot for correct replay boundary
- Snapshots are ephemeral — they can be rebuilt from the full event stream if corrupted

```java
// Snapshot creation service
@Service
@RequiredArgsConstructor
public class AccountSnapshotService {
    private final AccountRepository accountRepository;
    private final AccountSnapshotRepository snapshotRepository;

    public void createSnapshot(UUID accountId) {
        Account account = accountRepository.reconstitute(accountId);
        AccountSnapshot snapshot = new AccountSnapshot();
        snapshot.setAccountId(accountId);
        snapshot.setBalance(account.getBalance());
        snapshot.setEventVersion(accountRepository.getLatestVersion(accountId));
        snapshot.setSnapshotTimestamp(Instant.now());
        snapshotRepository.save(snapshot);
    }
}
```

### 7. Projections for read model optimization

Projections build query-optimized read models from the event stream:

```java
/**
 * Projection handler — updates the read model whenever a relevant event arrives.
 * <p>Each projection is independent and can be rebuilt from the event stream.</p>
 */
@Component
@RequiredArgsConstructor
public class OrderSummaryProjection {

    private final OrderSummaryRepository summaryRepository;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderPlaced(OrderPlacedEvent event) {
        OrderSummary summary = new OrderSummary();
        summary.setOrderId(event.orderId());
        summary.setCustomerId(event.customerId());
        summary.setTotalAmount(event.totalAmount());
        summary.setStatus("PLACED");
        summary.setPlacedAt(event.occurredAt());
        summaryRepository.save(summary);
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderCancelled(OrderCancelledEvent event) {
        summaryRepository.updateStatus(event.orderId(), "CANCELLED");
    }
}
```

**Projection design:**
- In-process projections (same DB as the write model) can use `@TransactionalEventListener(AFTER_COMMIT)`
- Cross-service projections must consume from the message broker fed by the Outbox — do not publish broker messages from inside the write transaction
- Projections are denormalized — optimized for specific query patterns, not normalized
- Each projection can use its own table or even its own database
- Projections can be rebuilt from the event stream at any time (no permanent data loss)
- Projection handlers must be idempotent — events may be replayed during rebuilds

## Best Practices

- **Start with simple domain events before adopting event sourcing**: the complexity trade-off must be justified by audit trail or temporal query requirements
- **Guarantee reliable event delivery**: Use outbox table + polling for at-least-once delivery; design consumers to be idempotent (deduplicate by event ID)
- **Use correlation IDs**: trace events across service boundaries for debugging and observability

## Constraints and Warnings

**Anti-patterns**:

- **Event coupling** — consumers that depend on event payload fields from other services. When the source service changes its event structure, all consumers break. Design events to be self-contained and stable; use additive changes only.
- **Synchronous event chains** — processing events synchronously in the same thread creates blocking chains. Any failure in the chain blocks the original operation. Use async processing with message brokers.
- **Snapshot as source of truth** — treating snapshots as the definitive state instead of the event stream. Snapshots are ephemeral and can be rebuilt; the event stream is the authoritative source. Never delete events.
- **Projection with business logic** — projection handlers that contain business rules or validation. Projections should be simple event-to-read-model translations; business rules belong in the write side.

**Technical constraints**:

- **Event versioning is critical**: never remove or rename fields from existing events. Additive changes (new fields with defaults) are safe. Breaking changes require new event types or topics.
- **CQRS requires eventual consistency**: the read model may lag behind the write model. Clients must handle stale reads (e.g., "your order has been placed but may not appear in search immediately").
- **@TransactionalEventListener(phase = AFTER_COMMIT) is essential**: events must only be published after the transaction commits. `@EventListener` fires during the transaction — if the transaction later rolls back, the event is already published, creating inconsistency.

## COLA Integration

When `integration_with_cola` is true, this skill works within the COLA multi-module architecture defined by `ddd-cola`. The following adjustments apply:

| Aspect | COLA Convention |
|--------|----------------|
| Event DTO location | `client/dto/event/` (shared with other services) |
| DomainEvent base class | In `client/common/` package (so all modules can access) |
| AggregateRoot base class | In `domain/` package (domain module only) |
| Event publisher | CmdExe (write path) |
| Outbox table | `infrastructure/` |
| Projection handler | `app/` or `infrastructure/` |

**simple_events with COLA**: No `AggregateRoot` base class needed. CmdExe publishes event after domain operation:
```java
// app/executor/CustomerAddCmdExe.java
@Component
@RequiredArgsConstructor
public class CustomerAddCmdExe {
    private final CustomerGateway customerGateway;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public Result<Void> execute(CustomerAddCmd cmd) {
        CustomerType type = CustomerType.valueOf(cmd.getCustomerType());
        Customer customer = Customer.create(cmd.getCompanyName(), type);
        customerGateway.save(customer);
        eventPublisher.publishEvent(new CustomerCreatedEvent(customer.getCustomerId(), Instant.now()));
        return Result.success();
    }
}
```

**aggregate_events / event_sourcing with COLA**: Domain entity extends `AggregateRoot` instead of plain `@Data`. All other COLA conventions (Gateway, CmdExe/QryExe, module structure) remain unchanged. See `ddd-cola` skill's **Event Integration** section for the full comparison table.

## Spring Cloud Integration

For inter-service event delivery in Spring Cloud environments:

| Transport | When to use | Config |
|-----------|-------------|--------|
| **Spring Cloud Stream + RocketMQ** | Alibaba Cloud ecosystem | `spring-cloud-starter-stream-rocketmq` → see `spring-cloud-alibaba` |
| **Spring Cloud Stream + Kafka** | Generic microservices | `spring-cloud-starter-stream-kafka` → see `spring-kafka` |
| **Outbox + Polling** | No message broker available | `@Scheduled` poller reads outbox table → see `spring-boot-scheduled-tasks` |

> Always combine with outbox pattern for reliable delivery — never publish directly to a message broker within a business transaction.

## References

- Domain-Driven Design by Eric Evans
- Martin Fowler on Event Sourcing: https://martinfowler.com/eaaDev/EventSourcing.html
- CQRS: https://martinfowler.com/bliki/CQRS.html
- `spring-boot-transaction-management/references/distributed-transaction-patterns.md` — Outbox pattern, Saga choreography/orchestration
- `spring-boot-event-driven-patterns/references/outbox-pattern.md` — Outbox implementation details

## Related Skills

- `ddd-cola` — COLA architecture: module structure, Gateway pattern, CmdExe/QryExe. **Load together when `integration_with_cola=true`**
- `spring-boot-event-driven-patterns` — Spring Boot implementation (ApplicationEventPublisher, @TransactionalEventListener, Kafka)
- `spring-boot-transaction-management` — transactional boundaries for event publishing, Outbox pattern, distributed transaction patterns
- `spring-cloud-openfeign` — inter-service calls in saga choreography
- `spring-kafka` — Kafka event publishing for distributed event delivery
- `spring-boot-async-processing` — async event processing patterns
- `spring-boot-scheduled-tasks` — Outbox Poller uses @Scheduled for event relay
- `spring-cloud-alibaba` — RocketMQ integration for Spring Cloud Alibaba

## Keywords

event-driven architecture, domain events, event sourcing, CQRS, outbox pattern, snapshotting, projection, aggregate root, domain event design, event versioning, eventual consistency, idempotent consumers, correlation ID, anemic events, event coupling, synchronous chains, message broker, Kafka, COLA events, AggregateRoot, simple events, aggregate events
