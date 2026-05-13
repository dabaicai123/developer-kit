---
name: spring-boot-amqp
description: "Spring AMQP / RabbitMQ for Spring Boot 3.x: Jackson message converter, RabbitTemplate producer, @RabbitListener consumer, listener container types (simple/direct/stream), manual acknowledgment, dead-letter handling, idempotency, and virtual thread support. Use when configuring RabbitMQ clients, setting up queue subscriptions, or handling AMQP-specific errors."
version: "1.1.0"
type: skill
---

# Spring Boot AMQP

## When to use this skill

- Implementing producers with `RabbitTemplate` and consumers with `@RabbitListener`
- Handling dead-letter exchanges (DLX), retry, and manual acknowledgment
- Designing idempotent message consumers

> For domain events and outbox pattern, use `spring-boot-event-driven-patterns`.

## Dependencies

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

## Configuration

```yaml
spring:
  rabbitmq:
    host: ${RABBITMQ_HOST:localhost}
    port: ${RABBITMQ_PORT:5672}
    username: ${RABBITMQ_USERNAME:guest}
    password: ${RABBITMQ_PASSWORD:guest}
    listener:
      type: simple                  # simple | direct | stream
      simple:
        prefetch: 10
        retry:
          enabled: true
          max-attempts: 3
          initial-interval: 1000ms
          multiplier: 2.0
          max-interval: 10000ms
```

## Jackson Converter (required)

Spring Boot defaults to `SimpleMessageConverter` (Java serialization). Always provide a `Jackson2JsonMessageConverter` bean — Spring Boot auto-associates it with `RabbitTemplate` and listener container factories:

```java
@Configuration
public class RabbitConfig {

    @Bean
    MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }
}
```

## Exchange / Queue Declaration

### Consumer — @RabbitListener bindings (recommended)

Declares and consumes in one annotation — inline declaration:

```java
@RabbitListener(bindings = @QueueBinding(
    value = @Queue(value = "order.created.queue", durable = "true", arguments = {
        @Argument(name = "x-dead-letter-exchange", value = "order.dlx"),
        @Argument(name = "x-dead-letter-routing-key", value = "order.created.dlq")
    }),
    exchange = @Exchange(value = "order.exchange", type = ExchangeTypes.TOPIC, durable = "true"),
    key = "order.created.#"
))
public void handleOrderCreated(OrderCreatedEvent event) {
    notificationService.sendOrderConfirmation(event);
}
```

### Producer-only or shared infrastructure — Declarables

Use `Declarables` to bundle exchanges, queues, and bindings. Exchange type (`Direct`, `Topic`, `Fanout`) depends on routing needs:

```java
@Configuration
public class OrderAmqpConfig {

    @Bean
    Declarables orderInfrastructure() {
        return new Declarables(
            new TopicExchange("order.exchange", true, false),
            new Queue("order.created.queue", true),
            new Binding("order.created.queue", DestinationType.QUEUE,
                "order.exchange", "order.created", null)
        );
    }
}
```

```java
@Service
@RequiredArgsConstructor
public class OrderEventPublisher {
    private final RabbitTemplate rabbitTemplate;

    public void publishOrderCreated(OrderCreatedEvent event) {
        rabbitTemplate.convertAndSend("order.exchange", "order.created", event);
    }
}
```

Use Java records for event DTOs — immutable, include `eventId` for idempotency:

```java
public record OrderCreatedEvent(UUID eventId, Long orderId, Instant timestamp) {
    public OrderCreatedEvent(Long orderId) {
        this(UUID.randomUUID(), orderId, Instant.now());
    }
}
```

## Consumer

### Manual Acknowledgment

Use only for critical messages that must not be lost on failure. Throw `AmqpRejectAndDontRequeueException` for permanent failures; let other exceptions propagate to trigger retry/requeue per container config.

```java
@RabbitListener(queues = "payment.queue", ackMode = "MANUAL")
public void handlePayment(PaymentEvent event, Channel channel,
                          @Header(AmqpHeaders.DELIVERY_TAG) long tag) throws IOException {
    try {
        paymentService.process(event);
        channel.basicAck(tag, false);
    } catch (AmqpRejectAndDontRequeueException e) {
        channel.basicNack(tag, false, false);  // reject to DLQ
    } catch (Exception e) {
        channel.basicNack(tag, false, true);   // requeue for retry
    }
}
```

## Idempotency

Consumers must be idempotent — RabbitMQ may redeliver messages. Wrap check+save in `@Transactional` to prevent race conditions:

```java
@RabbitListener(queues = "order.created.queue")
@Transactional
public void handleOrderCreated(OrderCreatedEvent event) {
    if (processedEventRepository.existsByEventId(event.eventId())) return;
    // business logic
    processedEventRepository.save(new ProcessedEvent(event.eventId()));
}
```

## Naming Conventions

| Artifact | Pattern | Example |
|---|---|---|
| Exchange | `{domain}.exchange` | `order.exchange` |
| Queue | `{domain}.{event}.queue` | `order.created.queue` |
| DLX | `{domain}.dlx` | `order.dlx` |
| DLQ | `{domain}.{event}.dlq` | `order.created.dlq` |

## Listener Container Types

Spring Boot 3.x supports three container types via `spring.rabbitmq.listener.type`:

| Type | Property | Use case |
|------|----------|----------|
| `simple` | `listener.simple.*` | Default. Invoker thread pool, supports retry config and prefetch |
| `direct` | `listener.direct.*` | Lower latency. Invoked on RabbitMQ consumer thread; no retry, uses `consumers-per-queue` |
| `stream` | `listener.stream.*` | RabbitMQ Stream protocol for high-throughput, persistent log |

On Java 21+ with `spring.threads.virtual.enabled=true`, Spring Boot 3.5 auto-configures virtual threads for listener containers.

## Constraints and Warnings

- Never publish inside `@Transactional` without outbox pattern — use `spring-boot-event-driven-patterns`
- Never use `SimpleMessageConverter` (Java serialization) — always configure Jackson
- Add `spring-boot-starter-actuator` for production — AMQP observations (metrics + tracing) are opt-in: set `spring.rabbitmq.listener.simple.observation-enabled=true` (or `direct`/`stream`) and `spring.rabbitmq.template.observation-enabled=true` to enable
