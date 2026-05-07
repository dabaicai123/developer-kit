---
name: spring-kafka
description: Spring Kafka integration patterns for Spring Boot 3.5.x covering producers, consumers, error handling, and serialization. Use when integrating Kafka for event streaming or message-driven architecture.
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Kafka

Kafka integration patterns for Spring Boot 3.5.x.

## When to use this skill

- Producing or consuming Kafka messages
- Implementing event-driven microservices with Kafka
- Configuring Kafka error handling and retry strategies
- Setting up Kafka with Spring Cloud Stream

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
      retries: 3
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      auto-offset-reset: earliest
      group-id: ${spring.application.name}
      properties:
        spring.json.trusted.packages: "*"
```

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
                } else {
                    log.debug("Published order event: {}", event.getOrderId());
                }
            });
    }
}
```

## Consumer

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class OrderEventConsumer {

    @KafkaListener(topics = "order-events", groupId = "inventory-service")
    public void handleOrderCreated(OrderEvent event) {
        log.info("Processing order event: {}", event.getOrderId());
        // business logic
    }
}
```

## Error Handling with DLQ

```java
@Component
@Slf4j
public class OrderEventErrorHandler {

    @KafkaListener(topics = "order-events", groupId = "inventory-service",
            containerFactory = "kafkaListenerContainerFactory")
    public void handleOrderCreated(OrderEvent event) {
        // business logic that may throw
    }

    @DltHandler
    public void handleDlt(OrderEvent event, ConsumerRecord<?, ?> record) {
        log.error("Event sent to DLQ: topic={}, offset={}, event={}",
            record.topic(), record.offset(), event);
    }
}
```

```yaml
spring:
  kafka:
    listener:
      ack-mode: manual_immediate
    consumer:
      properties:
        spring.kafka.consumer.properties.[spring.kafka.retry.topic.enabled]: true
```

## Manual Acknowledgment

```java
@KafkaListener(topics = "order-events", groupId = "inventory-service",
        containerFactory = "manualAckContainerFactory")
public void handleOrderCreated(OrderEvent event, Acknowledgment ack) {
    try {
        // business logic
        ack.acknowledge();
    } catch (Exception ex) {
        log.error("Failed to process event: {}", event.getOrderId(), ex);
        // do not ack — Kafka will redeliver
    }
}
```

## Best Practices

- Use `acks: all` for producers to guarantee message delivery
- Set `retries: 3` with exponential backoff for transient failures
- Configure DLQ (Dead Letter Queue) for unprocessable messages
- Use manual acknowledgment for critical business events
- Always include `orderId` (or similar) as the key for partition ordering
- Keep consumer logic idempotent — Kafka may redeliver messages

## Related Skills

- `spring-boot-event-driven-patterns` — @TransactionalEventListener, application event patterns
- `ddd-event-driven` — domain event design, event stores, aggregate boundaries
- `spring-boot-actuator` — Kafka consumer health indicators and metrics