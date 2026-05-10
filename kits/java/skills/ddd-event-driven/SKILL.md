---
name: ddd-event-driven
description: "Domain-driven event architecture for Spring Boot: domain event design, event sourcing, CQRS, aggregate root event publishing, outbox pattern, snapshooting, projections, and anti-patterns. Use when designing event-driven architecture, evaluating event sourcing vs simple events, or implementing CQRS."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# DDD Event-Driven Architecture

Domain-driven event architecture guidance — domain event design principles, event sourcing basics, CQRS separation, aggregate root event publishing, outbox pattern integration, snapshooting, projections, and common anti-patterns.

## When to use this skill

| Concept | Description | Complexity |
|---|---|---|
| **Domain Events** | Immutable facts published by aggregates after state changes | Low |
| **Event Sourcing** | Aggregate state is derived by replaying its event history | Medium |
| **CQRS** | Separate models for writes (commands) and reads (queries) | High |
| **Outbox Pattern** | Persist events in same transaction as aggregate, poll to publish | Low-Medium |
| **Snapshooting** | Periodic aggregate state snapshot to avoid full replay | Medium |
| **Projection** | Build read models from event stream for query optimization | Medium |

## Instructions

### 1. Design domain events — what makes a good event

Domain events represent **facts that have happened** in the past. Follow these design rules:

```java
/**
 * Base domain event — all domain events extend this.
 * <p>Every event has a unique ID, timestamp, and correlation ID for tracing.</p>
 */
public abstract class DomainEvent {
    private final UUID eventId;
    private final Instant occurredAt;
    private final UUID correlationId;

    protected DomainEvent(UUID correlationId) {
        this.eventId = UUID.randomUUID();
        this.occurredAt = Instant.now();
        this.correlationId = correlationId;
    }
}

/**
 * Domain event — past tense naming, essential data only, immutable.
 */
public record OrderPlacedEvent(
    UUID orderId,
    UUID customerId,
    BigDecimal totalAmount,
    List<OrderItemSummary> items,
    Instant occurredAt
) implements DomainEvent {}

/** Summary of order items — NOT the full item entities */
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

    /** Place order — both changes state AND registers the event */
    public void place(List<OrderItem> items) {
        // Business rule: validate before state change
        if (status != OrderStatus.DRAFT) {
            throw new ConflictException("Order cannot be placed in status: " + status);
        }

        // State change
        this.status = OrderStatus.PLACED;
        this.total = calculateTotal(items);

        // Register the corresponding event — state and event are always consistent
        registerEvent(new OrderPlacedEvent(this.id, this.customerId, this.total, summarizeItems(items), Instant.now()));
    }

    /** Cancel order — different event for different business fact */
    public void cancel(String reason) {
        if (status == OrderStatus.COMPLETED) {
            throw new ConflictException("Completed order cannot be cancelled");
        }
        this.status = OrderStatus.CANCELLED;
        registerEvent(new OrderCancelledEvent(this.id, reason, Instant.now()));
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

    @Transactional(rollbackFor = Exception.class)
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
        pendingEvents.add(new MoneyDepositedEvent(id, amount, Instant.now()));
        apply(new MoneyDepositedEvent(id, amount, Instant.now())); // update local state
    }

    public void withdraw(BigDecimal amount) {
        if (balance.compareTo(amount) < 0) {
            throw new ConflictException("Insufficient funds");
        }
        pendingEvents.add(new MoneyWithdrawnEvent(id, amount, Instant.now()));
        apply(new MoneyWithdrawnEvent(id, amount, Instant.now()));
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
        events.forEach(account::apply);
        return account;
    }

    /** Get pending events for persistence, then clear */
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

    @Transactional(rollbackFor = Exception.class)
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

### 6. Snapshooting for long event streams

When an aggregate has many events, replaying from the beginning becomes expensive. Snapshooting stores periodic state summaries to reduce replay time:

```java
/**
 * Snapshot — periodic aggregate state summary to avoid full replay.
 * <p>Load the latest snapshot, then replay only events after the snapshot timestamp.</p>
 */
@Data
@TableName("account_snapshots")
public class AccountSnapshot {
    private UUID accountId;
    private BigDecimal balance;
    private Instant snapshotTimestamp;
    private long eventVersion;   // Version of the last event included in snapshot
}

// Reconstitute with snapshot — only replay events after the snapshot
public Account reconstituteWithSnapshot(AccountSnapshot snapshot, List<DomainEvent> postSnapshotEvents) {
    Account account = new Account();
    account.id = snapshot.getAccountId();
    account.balance = snapshot.getBalance();
    // Only replay events after the snapshot timestamp
    postSnapshotEvents.forEach(account::apply);
    return account;
}
```

**Snapshooting guidelines:**
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

## References

- Domain-Driven Design by Eric Evans
- Martin Fowler on Event Sourcing: https://martinfowler.com/eaaDev/EventSourcing.html
- CQRS: https://martinfowler.com/bliki/CQRS.html
- `spring-boot-transaction-management/references/distributed-transaction-patterns.md` — Outbox pattern, Saga choreography/orchestration
- `spring-boot-event-driven-patterns/references/outbox-pattern.md` — Outbox implementation details

## Related Skills

- `spring-boot-event-driven-patterns` — Spring Boot implementation (ApplicationEventPublisher, @TransactionalEventListener, Kafka)
- `spring-boot-transaction-management` — transactional boundaries for event publishing, Outbox pattern, distributed transaction patterns
- `ddd-cola` — COLA architecture with domain events in the domain layer
- `spring-cloud-openfeign` — inter-service calls in saga choreography
- `spring-kafka` — Kafka event publishing for distributed event delivery
- `spring-boot-async-processing` — async event processing patterns
- `spring-boot-scheduled-tasks` — Outbox Poller uses @Scheduled for event relay

## Keywords

event-driven architecture, domain events, event sourcing, CQRS, outbox pattern, snapshooting, projection, aggregate root, domain event design, event versioning, eventual consistency, idempotent consumers, correlation ID, anemic events, event coupling, synchronous chains, message broker, Kafka