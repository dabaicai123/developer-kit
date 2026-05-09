---
name: spring-kafka
description: "Spring Kafka for Spring Boot 3.5.x: producer/consumer configuration, serialization, error handling, retry, and Spring Cloud Stream. Use when configuring Kafka clients, setting up topic subscriptions, or handling Kafka-specific errors."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Kafka

## When to use this skill

- Configuring Kafka producer/consumer properties and serialization
- Handling Kafka-specific errors, retries, and dead letter topics
- Setting up Spring Cloud Stream with Kafka binder

> For event-driven architecture patterns (domain events, `@TransactionalEventListener`, outbox pattern), use `spring-boot-event-driven-patterns`. This skill focuses on Kafka infrastructure configuration.

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

- Always set message key for partition ordering
- Keep consumers idempotent (Kafka may redeliver)
- Configure DLQ for unprocessable messages

## Related Skills

- `spring-boot-event-driven-patterns` — @TransactionalEventListener, application event patterns
- `ddd-event-driven` — domain event design, event stores, aggregate boundaries
- `spring-boot-actuator` — Kafka consumer health indicators and metrics