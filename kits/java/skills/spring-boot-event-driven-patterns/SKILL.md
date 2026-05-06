---
name: spring-boot-event-driven-patterns
description: "Event-Driven Architecture for Spring Boot: domain events, ApplicationEvent with @TransactionalEventListener, Kafka producer/consumer, and transactional outbox pattern. Use when implementing event-driven systems in Spring Boot, setting up async messaging with Kafka, or publishing domain events from DDD aggregates."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Event-Driven Patterns

## When to use this skill

- Implementing event-driven microservices with Kafka messaging
- Publishing domain events from aggregate roots in DDD architectures
- Setting up transactional event listeners that fire after database commits
- Adding async messaging with producers and consumers via Spring Kafka
- Ensuring reliable event delivery using the transactional outbox pattern
- Replacing synchronous calls with event-based communication between services

> For architecture-level concepts (event sourcing, CQRS theory), see `ddd-event-driven`. This skill focuses on Spring Boot implementation.

## Examples

### Monolithic to Event-Driven Refactoring

**Before (Anti-Pattern):**
```java
@Transactional
public Order processOrder(CreateOrderCmd request) {
    Order order = orderRepository.save(request);
    inventoryService.reserve(order.getItems()); // Blocking
    paymentService.charge(order.getPayment()); // Blocking
    emailService.sendConfirmation(order); // Blocking
    return order;
}
```

**After (Event-Driven):**
```java
@Transactional
public Order processOrder(CreateOrderCmd request) {
    Order order = Order.create(request);
    orderRepository.save(order);

    // Publish event after transaction commits
    eventPublisher.publishEvent(new OrderCreatedEvent(order.getId(), order.getItems()));

    return order;
}

@Component
public class OrderEventHandler {
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleOrderCreated(OrderCreatedEvent event) {
        // Execute asynchronously after the order is saved
        inventoryService.reserve(event.getItems());
        paymentService.charge(event.getPayment());
    }
}
```

See [examples.md](references/examples.md) for complete working examples.

## Instructions

### 1. Design Domain Events

Create immutable event classes extending a base `DomainEvent` class:

```java
public abstract class DomainEvent {
    private final UUID eventId;
    private final Instant occurredAt;
    private final UUID correlationId;
}

public class ProductCreatedEvent extends DomainEvent {
    private final ProductId productId;
    private final String name;
    private final BigDecimal price;
}
```

See [domain-events-design.md](references/domain-events-design.md) for patterns.

### 2. Publish Events from Aggregates

Add domain events to aggregate roots, publish via `ApplicationEventPublisher`:

```java
@Service
@Transactional
public class ProductService {
    public Product createProduct(CreateProductRequest request) {
        Product product = Product.create(request.getName(), request.getPrice(), request.getStock());
        repository.save(product);

        product.getDomainEvents().forEach(eventPublisher::publishEvent);
        product.clearDomainEvents();

        return product;
    }
}
```

See [aggregate-root-patterns.md](references/aggregate-root-patterns.md) for DDD patterns.

### 3. Handle Events Transactionally

Use `@TransactionalEventListener` for reliable event handling:

```java
@Component
public class ProductEventHandler {
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onProductCreated(ProductCreatedEvent event) {
        notificationService.sendProductCreatedNotification(event.getName());
    }
}
```

See [event-handling.md](references/event-handling.md) for handling patterns.

### 4. Configure Kafka Infrastructure

Configure KafkaTemplate for publishing, `@KafkaListener` for consuming:

```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
```

See [dependency-setup.md](references/dependency-setup.md) and [configuration.md](references/configuration.md).

### 5. Implement Outbox Pattern

The Outbox pattern ensures business data and event records are persisted in the same local transaction. For the full Outbox implementation (table schema, event publisher, poller, Saga choreography/orchestration), see `spring-boot-transaction-management` → `references/distributed-transaction-patterns.md`.

See [outbox-pattern.md](references/outbox-pattern.md) for event publishing patterns.

### 6. Handle Failure Scenarios

Implement retry logic, dead-letter queues, idempotent handlers:

```java
@RetryableTopic(attempts = "3")
@KafkaListener(topics = "product-events")
public void handleProductEvent(ProductCreatedEventDto event) {
    orderService.onProductCreated(event);
}
```

### 7. Observability

For observability (Micrometer tracing, metrics), see `spring-boot-actuator`.

## Best Practices

- **Use past tense naming**: `ProductCreated` (not `CreateProduct`)
- **Include correlation IDs**: For tracing events across services
- **Use AFTER_COMMIT phase**: Ensures events are published after successful database transaction

## References

- **[dependency-setup.md](references/dependency-setup.md)** — Maven/Gradle dependencies
- **[configuration.md](references/configuration.md)** — Kafka and Spring Cloud Stream configuration
- **[domain-events-design.md](references/domain-events-design.md)** — Domain event design patterns
- **[aggregate-root-patterns.md](references/aggregate-root-patterns.md)** — Aggregate root with event publishing
- **[event-publishing.md](references/event-publishing.md)** — Local and distributed event publishing
- **[event-handling.md](references/event-handling.md)** — Event handling and consumption patterns
- **[outbox-pattern.md](references/outbox-pattern.md)** — Transactional outbox pattern for reliability
- **[testing-strategies.md](references/testing-strategies.md)** — Unit and integration testing approaches
- **[examples.md](references/examples.md)** — Complete working examples
- **[event-driven-patterns-reference.md](references/event-driven-patterns-reference.md)** — Detailed reference documentation

## Constraints and Warnings

- Events published with `@TransactionalEventListener` only fire after transaction commit
- Avoid publishing large objects in events (memory pressure, serialization issues)
- Be cautious with async event handlers (separate threads, concurrency issues)
- Kafka consumers must handle duplicate messages (implement idempotent processing)
- Event ordering is not guaranteed in distributed systems (design handlers to be order-independent)
- Never perform blocking operations in event listeners on the main transaction thread
- Monitor for event processing backlogs (indicate system capacity issues)
- Spring Kafka 3.x uses `CompletableFuture` (not `ListenableFuture`) — use `whenComplete()` for async callbacks
- Use `@MockitoBean` (not `@MockBean`, deprecated since Spring Boot 3.4) in tests
- Use `Instant` (not `LocalDateTime`) for event timestamps — timezone-agnostic for distributed systems

## Related Skills

- `ddd-event-driven` — domain event design, aggregate boundaries, event stores
- `spring-boot-transaction-management` — @TransactionalEventListener, event publishing within transaction boundaries
- `spring-boot-async-processing` — @Async event handlers, CompletableFuture chaining
- `spring-boot-security-jwt` — JWT authentication for secure event publishing
