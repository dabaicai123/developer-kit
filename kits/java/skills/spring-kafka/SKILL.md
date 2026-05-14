---
name: spring-kafka
description: "Spring Kafka: producer/consumer config, serialization, ErrorHandlingDeserializer, non-blocking retry (@RetryableTopic), DLQ, and manual ack. Use when configuring Kafka clients or handling Kafka errors."
version: "1.2.0"
---

# Spring Kafka

## When to use

- Configuring Kafka producer/consumer properties and serialization
- Handling deserialization errors and non-blocking retries with DLQ
- Setting up manual acknowledgment for critical workflows

> For event-driven architecture patterns (domain events, @TransactionalEventListener, outbox), use `spring-boot-event-driven-patterns`. This skill covers Kafka infrastructure only.

## Dependencies

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

## Configuration

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_SERVERS:localhost:9092}
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.ErrorHandlingDeserializer
      auto-offset-reset: earliest
      group-id: ${spring.application.name}
      properties:
        spring.deserializer.value.delegate.class: org.springframework.kafka.support.serializer.JsonDeserializer
        spring.json.trusted.packages: "com.example.events"
        spring.json.type.mapping: "orderEvent:com.example.events.OrderEvent"
    listener:
      auth-exception-retry-interval: 10s
```

NOT `spring.json.trusted.packages: "*""` — this disables type filtering and allows arbitrary class instantiation (security risk). Trust only your own packages.

NOT `auto-offset-reset: earliest` in production without intent — it reprocesses all historical messages on consumer restart. Use `latest` unless you deliberately need reprocessing.

## Producer

```java
@Service
@RequiredArgsConstructor
public class OrderEventProducer {
    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;

    public void publishOrderCreated(OrderEvent event) {
        kafkaTemplate.send("order-events", event.getOrderId(), event)
            .whenComplete((result, ex) -> {
                if (ex != null) {
                    log.error("Failed to publish order event: {}", event.getOrderId(), ex);
                }
            });
    }
}
```

NOT omit the message key — keys determine partition routing. Without keys, partition ordering is lost.

## Error Handling

### ErrorHandlingDeserializer

NOT use `JsonDeserializer` directly as the consumer value-deserializer — a deserialization failure crashes the consumer loop with no recovery path. Wrap it with `ErrorHandlingDeserializer`:

```yaml
spring.kafka.consumer.value-deserializer: org.springframework.kafka.support.serializer.ErrorHandlingDeserializer
spring.kafka.consumer.properties.spring.deserializer.value.delegate.class: org.springframework.kafka.support.serializer.JsonDeserializer
```

Failed deserialization produces a `DeserializationException` handled by `DefaultErrorHandler`, not a consumer restart.

### Non-Blocking Retry with @RetryableTopic

NOT implement retry by catching exceptions and re-sending — this blocks the consumer thread and duplicates logic. Use `@RetryableTopic` for automatic retry topic creation, delayed redelivery, and DLQ routing:

```java
@Component
@Slf4j
public class OrderEventConsumer {

    @RetryableTopic(attempts = 3, backoff = @Backoff(delay = 1000, multiplier = 2),
            dltStrategy = DltStrategy.FAIL_ON_DLT)
    @KafkaListener(topics = "order-events", groupId = "inventory-service")
    public void handleOrderCreated(OrderEvent event) {
        log.info("Processing order event: {}", event.getOrderId());
    }

    @DltHandler
    public void handleDlt(OrderEvent event) {
        log.error("Event exhausted retries: {}", event.getOrderId());
    }
}
```

`@RetryableTopic` creates retry topics (`order-events-retry-0`, `-retry-1`, ...) and a DLT topic (`order-events-dlt`) automatically.

### DefaultErrorHandler for Blocking Retry

When non-blocking retry is not needed, `DefaultErrorHandler` provides configurable blocking retry with `DeadLetterPublishingRecoverer`:

```java
@Bean
ConcurrentKafkaListenerContainerFactory<String, Object> kafkaListenerContainerFactory(
        ConsumerFactory<String, Object> consumerFactory,
        KafkaTemplate<String, Object> kafkaTemplate) {
    var factory = new ConcurrentKafkaListenerContainerFactory<>();
    factory.setConsumerFactory(consumerFactory);
    var recoverer = new DeadLetterPublishingRecoverer(kafkaTemplate);
    factory.setCommonErrorHandler(new DefaultErrorHandler(recoverer, new FixedBackOff(1000, 3)));
    return factory;
}
```

NOT configure `DefaultErrorHandler` without a recoverer — retries that exhaust without a DLT sink silently discard the message.

## Manual Acknowledgment

```java
@KafkaListener(topics = "order-events", groupId = "inventory-service",
        ackMode = AckMode.MANUAL_IMMEDIATE)
public void handleOrderCreated(OrderEvent event, Acknowledgment ack) {
    try {
        // business logic
        ack.acknowledge();
    } catch (Exception ex) {
        log.error("Failed to process event: {}", event.getOrderId(), ex);
        // NOT ack on failure — Kafka redelivers the message
    }
}
```

NOT ack before business logic completes — the message is permanently committed and never redelivered on failure.

## Anti-Patterns

- NOT use `spring.json.trusted.packages: "*"` — trust only known packages
- NOT skip `ErrorHandlingDeserializer` — deserialization failures kill consumers
- NOT omit message keys — partition ordering is lost
- NOT ack before processing completes — message is permanently committed
- NOT implement retry by re-sending — blocks consumer, duplicates logic
- NOT use `@DltHandler` without `@RetryableTopic` — DLT handler is bound to retry topic chain
- NOT configure `DefaultErrorHandler` without a recoverer — exhausted retries silently discard messages

## Spring Boot 3.5 Properties

- `spring.kafka.consumer.max-poll-interval` — max delay between poll() calls (default: 5m)
- `spring.kafka.listener.auth-exception-retry-interval` — retry interval after auth failures (default: 10s)

## Related Skills

`spring-boot-event-driven-patterns`, `ddd-event-driven`, `spring-boot-actuator`