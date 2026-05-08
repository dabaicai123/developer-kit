---
name: spring-boot-amqp
description: "Spring AMQP / RabbitMQ for Spring Boot 3.x: Jackson message converter, RabbitTemplate producer, @RabbitListener consumer, manual acknowledgment, dead-letter handling, and idempotency. Use when configuring RabbitMQ clients, setting up queue subscriptions, or handling AMQP-specific errors."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot AMQP

Spring AMQP / RabbitMQ for Spring Boot 3.x.

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

Always configure Jackson — never use default Java serialization.

```java
@Configuration
public class RabbitConfig {

    @Bean
    MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }
}
```

Spring Boot auto-configures `RabbitTemplate` and `SimpleRabbitListenerContainerFactory` with this converter automatically.

## Producer

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

Prefer `@RabbitListener` with `bindings` to declare exchange, queue, and DLX inline — no separate `@Bean` needed:

```java
@Service
@RequiredArgsConstructor
public class OrderNotificationListener {

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
}
```

Use `@Bean` declarations only for producer-only services (no listener) or when multiple listeners share the same exchange/queue.

### Manual Acknowledgment

Use only for critical messages that must not be lost on failure.

```java
@RabbitListener(queues = "payment.queue", ackMode = "MANUAL")
public void handlePayment(PaymentEvent event, Channel channel,
                          @Header(AmqpHeaders.DELIVERY_TAG) long tag) throws IOException {
    try {
        paymentService.process(event);
        channel.basicAck(tag, false);
    } catch (TransientException e) {
        channel.basicNack(tag, false, true);   // requeue
    } catch (Exception e) {
        channel.basicNack(tag, false, false);  // reject to DLQ
    }
}
```

## Idempotency

Consumers must be idempotent — RabbitMQ may redeliver messages.

```java
@RabbitListener(queues = "order.created.queue")
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

## Key Rules

- Configure Jackson converter — Spring Boot picks it up automatically for `RabbitTemplate` and listeners
- Prefer `@RabbitListener` with `bindings` for inline queue/exchange/DLX declaration — use `@Bean` only for producer-only services or shared resources
- Never publish inside `@Transactional` without outbox pattern — use `spring-boot-event-driven-patterns`
- Configure DLX/DLQ for every production queue
- Keep consumers idempotent using `eventId` deduplication
