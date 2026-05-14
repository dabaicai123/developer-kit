# Domain Events Design

## Domain Event Base Class

Create an immutable base class for all domain events:

```java
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
public abstract class DomainEvent {
    private final UUID eventId;
    private final LocalDateTime occurredAt;
    private final UUID correlationId;

    protected DomainEvent() {
        this.eventId = UUID.randomUUID();
        this.occurredAt = LocalDateTime.now();
        this.correlationId = UUID.randomUUID();
    }

    protected DomainEvent(UUID correlationId) {
        this.eventId = UUID.randomUUID();
        this.occurredAt = LocalDateTime.now();
        this.correlationId = correlationId;
    }
}
```

## Specific Domain Events

### Product Created Event

```java
import lombok.Getter;

import java.math.BigDecimal;

@Getter
public class ProductCreatedEvent extends DomainEvent {
    private final ProductId productId;
    private final String name;
    private final BigDecimal price;
    private final Integer stock;

    public ProductCreatedEvent(ProductId productId, String name, BigDecimal price, Integer stock) {
        super();
        this.productId = productId;
        this.name = name;
        this.price = price;
        this.stock = stock;
    }
}
```

### Product Stock Decreased Event

```java
import lombok.Getter;

@Getter
public class ProductStockDecreasedEvent extends DomainEvent {
    private final ProductId productId;
    private final Integer quantity;
    private final Integer remainingStock;

    public ProductStockDecreasedEvent(ProductId productId, Integer quantity, Integer remainingStock) {
        super();
        this.productId = productId;
        this.quantity = quantity;
        this.remainingStock = remainingStock;
    }
}
```

### Order Created Event

```java
import lombok.Getter;

import java.util.List;

@Getter
public class OrderCreatedEvent extends DomainEvent {
    private final OrderId orderId;
    private final CustomerId customerId;
    private final List<OrderItem> items;
    private final BigDecimal total;

    public OrderCreatedEvent(OrderId orderId, CustomerId customerId, List<OrderItem> items, BigDecimal total) {
        super();
        this.orderId = orderId;
        this.customerId = customerId;
        this.items = List.copyOf(items);
        this.total = total;
    }
}
```

## Event Design Guidelines

### Naming Conventions

- **Use past tense**: `ProductCreated` (not `CreateProduct`)
- **Reflect business domain**: `OrderPaid`, `InventoryReserved`
- **Be explicit**: `ProductStockDecreased` (not `ProductStockChanged`)

### Event Content

- **Include all relevant data**: Events should be self-contained
- **Use value objects**: `ProductId`, `OrderId` instead of primitive `Long`
- **Make events immutable**: All fields should be `final`

### Event Metadata

- **eventId**: Unique identifier for the event
- **occurredAt**: Timestamp when the event occurred
- **correlationId**: Links related events across aggregates

### Example: Rich Event Design

```java
import lombok.Getter;

@Getter
public class OrderPlacedEvent extends DomainEvent {
    private final OrderId orderId;
    private final CustomerId customerId;
    private final List<OrderItem> items;
    private final BigDecimal totalAmount;
    private final String shippingAddress;
    private final PaymentMethod paymentMethod;
    private final Instant estimatedDeliveryDate;

    public OrderPlacedEvent(
        OrderId orderId,
        CustomerId customerId,
        List<OrderItem> items,
        BigDecimal totalAmount,
        String shippingAddress,
        PaymentMethod paymentMethod,
        Instant estimatedDeliveryDate,
        UUID correlationId
    ) {
        super(correlationId);
        this.orderId = orderId;
        this.customerId = customerId;
        this.items = List.copyOf(items);
        this.totalAmount = totalAmount;
        this.shippingAddress = shippingAddress;
        this.paymentMethod = paymentMethod;
        this.estimatedDeliveryDate = estimatedDeliveryDate;
    }

    public record OrderItem(
        ProductId productId,
        String productName,
        Integer quantity,
        BigDecimal unitPrice
    ) {}
}
```

## Event Serialization

### JSON Serialization

```java
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;

@Getter
public class ProductCreatedEvent extends DomainEvent {
    private final String productId;
    private final String name;

    @JsonFormat(shape = JsonFormat.Shape.STRING)
    private final BigDecimal price;

    private final Integer stock;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private final LocalDateTime occurredAt;
}
```

### Event DTO Pattern

```java
import lombok.Getter;

// Domain event (internal)
@Getter
public class ProductCreatedEvent extends DomainEvent {
    private final ProductId productId;
    private final String name;
    private final BigDecimal price;
}

// Event DTO (external communication)
public class ProductCreatedEventDto {
    private final String eventId;
    private final String productId;
    private final String name;
    private final BigDecimal price;
    private final LocalDateTime occurredAt;
    private final String correlationId;

    public static ProductCreatedEventDto from(ProductCreatedEvent event) {
        return new ProductCreatedEventDto(
            event.getEventId().toString(),
            event.getProductId().getValue(),
            event.getName(),
            event.getPrice(),
            event.getOccurredAt(),
            event.getCorrelationId().toString()
        );
    }
}
```

## Event Versioning

### Versioned Events

```java
import lombok.Getter;

@Getter
public class ProductCreatedEventV2 extends DomainEvent {
    private final ProductId productId;
    private final String name;
    private final BigDecimal price;
    private final Integer stock;
    private final String category; // New field in V2

    // Include version information
    private final String eventVersion = "2.0";
}
```

### Upcaster Pattern

```java
@Component
public class EventUpcaster {
    public ProductCreatedEventV2 upcast(ProductCreatedEventV1 v1Event) {
        return new ProductCreatedEventV2(
            v1Event.getProductId(),
            v1Event.getName(),
            v1Event.getPrice(),
            v1Event.getStock(),
            "uncategorized" // Default value for new field
        );
    }
}
```
