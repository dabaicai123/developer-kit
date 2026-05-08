---
name: spring-boot-amqp
description: "Spring AMQP / RabbitMQ for Spring Boot 3.x: connection, exchange/queue/binding, Jackson message converter, RabbitTemplate producer, @RabbitListener consumer, manual acknowledgment, dead-letter handling, retry, and idempotency. Use when configuring RabbitMQ clients, setting up queue subscriptions, or handling AMQP-specific errors."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot AMQP

Spring AMQP / RabbitMQ infrastructure for Spring Boot 3.x.

## When to use this skill

- Configuring RabbitMQ connection, exchanges, queues, and bindings
- Setting up Jackson JSON message converter for RabbitTemplate and listeners
- Implementing producers with `RabbitTemplate` and consumers with `@RabbitListener`
- Handling dead-letter exchanges (DLX), retry, and manual acknowledgment
- Designing idempotent message consumers

> For event-driven architecture patterns (domain events, `@TransactionalEventListener`, outbox pattern), use `spring-boot-event-driven-patterns`. This skill focuses on AMQP infrastructure configuration.

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
    virtual-host: ${RABBITMQ_VHOST:/}
    listener:
      simple:
        acknowledge-mode: auto
        prefetch: 10
        retry:
          enabled: true
          max-attempts: 3
          initial-interval: 1000ms
          multiplier: 2
          max-interval: 10000ms
```

## Infrastructure Configuration

Define exchanges, queues, and bindings in a `@Configuration` class — never rely on auto-declare from listeners alone.

```java
@Configuration
public class RabbitConfig {

    @Bean
    MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }

    @Bean
    RabbitTemplate rabbitTemplate(ConnectionFactory cf, MessageConverter converter) {
        var template = new RabbitTemplate(cf);
        template.setMessageConverter(converter);
        return template;
    }

    // --- Order domain ---
    @Bean TopicExchange orderExchange() {
        return ExchangeBuilder.topicExchange("order.exchange").durable(true).build();
    }

    @Bean Queue orderCreatedQueue() {
        return QueueBuilder.durable("order.created.queue")
            .withArgument("x-dead-letter-exchange", "order.dlx")
            .withArgument("x-dead-letter-routing-key", "order.created.dlq")
            .build();
    }

    @Bean Binding orderCreatedBinding(Queue orderCreatedQueue, TopicExchange orderExchange) {
        return BindingBuilder.bind(orderCreatedQueue).to(orderExchange).with("order.created.#");
    }

    // --- Dead-letter ---
    @Bean DirectExchange orderDlx() { return new DirectExchange("order.dlx"); }
    @Bean Queue orderCreatedDlq() { return QueueBuilder.durable("order.created.dlq").build(); }
    @Bean Binding dlqBinding(Queue orderCreatedDlq, DirectExchange orderDlx) {
        return BindingBuilder.bind(orderCreatedDlq).to(orderDlx).with("order.created.dlq");
    }
}
```

Use `@ConfigurationProperties` for custom queue/exchange names — never hardcode them.

```java
@ConfigurationProperties(prefix = "app.rabbitmq")
@Data
public class RabbitProperties {
    private Map<String, String> queues = Map.of();
    private Map<String, String> exchanges = Map.of();
}
```

## Producer

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderEventPublisher {
    private final RabbitTemplate rabbitTemplate;

    public void publishOrderCreated(OrderCreatedEvent event) {
        rabbitTemplate.convertAndSend("order.exchange", "order.created", event);
        log.debug("Published order.created: orderId={}", event.orderId());
    }
}
```

### Event DTOs

Use Java records for immutable message payloads. Include `eventId` and `timestamp` for traceability. Never publish JPA entities directly.

```java
public record OrderCreatedEvent(
    UUID eventId,
    Long orderId,
    String customerEmail,
    BigDecimal totalAmount,
    Instant timestamp
) {
    public OrderCreatedEvent(Long orderId, String customerEmail, BigDecimal totalAmount) {
        this(UUID.randomUUID(), orderId, customerEmail, totalAmount, Instant.now());
    }
}
```

## Consumer

```java
@Service
@Slf4j
@RequiredArgsConstructor
public class OrderNotificationListener {
    private final NotificationService notificationService;

    @RabbitListener(queues = "${app.rabbitmq.queues.order-created}")
    public void handleOrderCreated(OrderCreatedEvent event) {
        log.info("Received order.created: orderId={}", event.orderId());
        notificationService.sendOrderConfirmation(event);
    }
}
```

### Manual Acknowledgment

Use `AcknowledgeMode.MANUAL` for critical messages that must not be lost.

```java
@RabbitListener(queues = "payment.queue", ackMode = "MANUAL")
public void handlePayment(PaymentEvent event, Channel channel,
                          @Header(AmqpHeaders.DELIVERY_TAG) long tag) {
    try {
        paymentService.process(event);
        channel.basicAck(tag, false);
    } catch (TransientException e) {
        channel.basicNack(tag, false, true);   // requeue on transient failure
    } catch (Exception e) {
        channel.basicNack(tag, false, false);  // reject to DLQ on permanent failure
    }
}
```

## Retry Strategy

Configure Spring Retry with exponential backoff in the listener container factory:

```java
@Bean
SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
        ConnectionFactory cf, MessageConverter converter) {
    var factory = new SimpleRabbitListenerContainerFactory();
    factory.setConnectionFactory(cf);
    factory.setMessageConverter(converter);
    factory.setAdviceChain(RetryInterceptorBuilder.stateless()
        .maxAttempts(3)
        .backOffOptions(1000, 2.0, 10000)
        .recoverer(new RejectAndDontRequeueRecoverer())
        .build());
    return factory;
}
```

After max retries, messages route to the DLQ — never retry infinitely.

## Idempotency

Consumers MUST be idempotent — messages can be delivered more than once.

```java
@RabbitListener(queues = "${app.rabbitmq.queues.order-created}")
public void handleOrderCreated(OrderCreatedEvent event) {
    if (processedEventRepository.existsByEventId(event.eventId())) {
        log.debug("Duplicate event ignored: {}", event.eventId());
        return;
    }
    // business logic
    processedEventRepository.save(new ProcessedEvent(event.eventId()));
}
```

Use `eventId` as a deduplication key. Store processed IDs in DB or Redis with TTL.

## Exchange Types

| Exchange | Use When |
|---|---|
| **Direct** | Point-to-point, exact routing key match |
| **Topic** | Pattern-based routing (`order.created.#`, `*.payment.*`) |
| **Fanout** | Broadcast to all bound queues |
| **Headers** | Route based on message headers (rare) |

Prefer **topic exchanges** as default — flexible for future routing changes.

## Naming Conventions

| Artifact | Pattern | Example |
|---|---|---|
| Exchange | `{domain}.exchange` | `order.exchange` |
| Queue | `{domain}.{event}.queue` | `order.created.queue` |
| DLX | `{domain}.dlx` | `order.dlx` |
| DLQ | `{domain}.{event}.dlq` | `order.created.dlq` |
| Routing key | `{domain}.{event}` | `order.created` |

## Transactional Messaging

Never publish inside a `@Transactional` method without the outbox pattern — if the transaction rolls back, the message is already sent.

Use the **Transactional Outbox pattern**: write the event to a DB outbox table in the same transaction, then publish via a scheduled poller. See `spring-boot-event-driven-patterns` for the full implementation.

## Best Practices

- Always configure Jackson JSON converter — never use default Java serialization
- Define exchanges/queues/bindings in `@Configuration` — don't rely on auto-declare
- Use `@ConfigurationProperties` for queue/exchange names — never hardcode
- Use Java records for event DTOs — immutable, concise
- Keep consumers idempotent — RabbitMQ may redeliver
- Configure DLX/DLQ for every queue — unprocessable messages must not disappear
- Set `prefetch` to limit unacknowledged messages per consumer (default 250 is too high)
- Use manual acknowledgment for critical business events
- Set `concurrency` on `@RabbitListener` for throughput (e.g., `concurrency = "3-10"`)
- Never include sensitive data (passwords, tokens) in messages
- Monitor DLQ depth — growing DLQ indicates processing failures

## Related Skills

- `spring-boot-event-driven-patterns` — @TransactionalEventListener, outbox pattern, domain event design
- `ddd-event-driven` — domain event design, aggregate boundaries, event stores
- `spring-kafka` — Kafka producer/consumer for comparison or migration
- `spring-boot-actuator` — RabbitMQ health indicators and metrics