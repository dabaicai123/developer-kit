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

Spring Boot defaults to `SimpleMessageConverter` (Java serialization) when Jackson is NOT on the classpath — insecure and not cross-language. When Jackson IS on the classpath (default in most Spring Boot 3.x projects), Spring Boot auto-configures a `Jackson2JsonMessageConverter`. If you need explicit control or custom ObjectMapper settings, define the bean manually.

```java
@Configuration
public class RabbitConfig {

    @Bean
    MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }
}
```

Once defined, Spring Boot auto-injects the converter into `RabbitTemplate` and `SimpleRabbitListenerContainerFactory` — no extra wiring needed.

## Exchange / Queue Declaration

### Consumer — @RabbitListener bindings (recommended)

Declares and consumes in one annotation — most elegant:

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

Scattered `@Bean` declarations are verbose; use `Declarables` to bundle everything:

```java
@Configuration
public class OrderAmqpConfig {

    @Bean
    Declarables orderInfrastructure() {
        return new Declarables(
            new DirectExchange("order.exchange", true, false),
            new Queue("order.created.queue", true),
            new Binding("order.created.queue", DestinationType.QUEUE,
                "order.exchange", "order.created", null)
        );
    }
}
```

`RabbitAdmin` auto-detects `Declarables` beans and declares them on the broker when a connection is established — no manual invocation needed.

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

- Configure Jackson converter — Spring Boot provides no property to switch converters; define the bean manually, and it auto-injects into `RabbitTemplate` and listener factory
- Consumer: `@RabbitListener(bindings = ...)` for inline declaration; Producer-only: `Declarables` to bundle, avoid scattered `@Bean`
- Never publish inside `@Transactional` without outbox pattern — use `spring-boot-event-driven-patterns`
- Configure DLX/DLQ for every production queue
- Keep consumers idempotent using `eventId` deduplication
