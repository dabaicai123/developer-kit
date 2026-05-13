---
name: spring-boot-jackson-config
description: "Jackson ObjectMapper configuration for Spring Boot 3.x: JavaTimeModule, JsonInclude, date serialization, custom serializers. Use when configuring JSON serialization/deserialization in infrastructure layer."
version: "1.0.0"
type: skill
---

# Spring Boot Jackson Configuration

Jackson ObjectMapper configuration patterns for Spring Boot 3.x projects.

## When to use this skill

- Configuring Jackson ObjectMapper for custom JSON serialization/deserialization
- Registering JavaTimeModule for LocalDateTime/LocalDate support
- Setting JsonInclude policy (ALWAYS, NON_NULL, NON_EMPTY)
- Disabling WRITE_DATES_AS_TIMESTAMPS for ISO-8601 date format
- Adding custom serializers/deserializers for domain types

## Spring Boot Auto-Configuration (Read This First)

**`spring-boot-starter-web` already does most of what you need** — it transitively pulls `spring-boot-starter-json`, which bundles:

- `jackson-databind`
- `jackson-datatype-jsr310` (LocalDateTime/LocalDate support)
- `jackson-datatype-jdk8` (Optional support)
- `jackson-module-parameter-names`

And Spring Boot's `JacksonAutoConfiguration` **automatically registers `JavaTimeModule`** on the default ObjectMapper bean. You can verify this by injecting `ObjectMapper` and serializing a `LocalDateTime` — it works out of the box.

**You only need a custom JacksonConfig when**:
1. You need a non-default `JsonInclude` policy globally (e.g., `NON_NULL` instead of `ALWAYS`)
2. You're adding custom serializers/deserializers for domain types
3. You need a non-default date format (most projects don't — ISO-8601 default is fine)

**You do NOT need a custom JacksonConfig when**:
- You just want `LocalDateTime` to serialize correctly — already handled
- You want ISO-8601 date format — already the default

## Where to Place JacksonConfig (COLA Architecture)

| Module | Should have JacksonConfig? | Reason |
|--------|---------------------------|--------|
| **adapter** | ✅ Yes (preferred) | HTTP boundary; closest to where JSON matters |
| **start** | ✅ Yes (alternative) | Bootstrap config module |
| **infrastructure** | ❌ **No** | Reuse the auto-configured `ObjectMapper` bean via `@Autowired` |
| **domain** | ❌ Forbidden | Domain must not know about JSON |
| **client** | ❌ Forbidden | API contract, no Spring beans |

**Anti-pattern**: Writing a duplicate `JacksonConfig` in infrastructure to "configure JSON for Redis or RestClient". This duplicates Spring Boot's auto-configuration and forces the infrastructure module to declare Jackson dependencies it shouldn't need.

**Correct pattern** — infrastructure injects the global ObjectMapper:

```java
// infrastructure/config/RedisConfig.java
@Configuration
@RequiredArgsConstructor
public class RedisConfig {
    private final ObjectMapper objectMapper;  // ← injected, NOT created

    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer(objectMapper));
        return template;
    }
}
```

## Dependencies

If you have `spring-boot-starter-web` somewhere in your dependency tree (adapter module), **no extra dependencies needed** — Jackson + jsr310 are already on the classpath.

Only add these when your module has NO spring-boot-starter-web/json transitively (rare):

```xml
<!-- Jackson core (already in spring-boot-starter-web) -->
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
</dependency>

<!-- Java 8 date/time support — JSR-310 spec, NOT a JDK 8 compat shim.
     Required for LocalDateTime/LocalDate serialization in ALL Java versions (8/11/17/21).
     Already bundled via spring-boot-starter-json. -->
<dependency>
    <groupId>com.fasterxml.jackson.datatype</groupId>
    <artifactId>jackson-datatype-jsr310</artifactId>
</dependency>
```

> **Naming note**: `jsr310` refers to JSR-310 (Java Specification Request 310 — Date and Time API), NOT to JDK 8. The `java.time.*` types it supports are the standard date/time API in all modern Java versions including Java 21.

## Basic Configuration

```java
package com.example.infrastructure.config;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JacksonConfig {

    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        
        // Register Java 8 date/time module (LocalDateTime, LocalDate, etc.)
        mapper.registerModule(new JavaTimeModule());
        
        // Serialize dates as ISO-8601 strings, not timestamps
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        
        // Include policy: ALWAYS (default), NON_NULL, NON_EMPTY, NON_DEFAULT
        mapper.setSerializationInclusion(JsonInclude.Include.ALWAYS);
        
        return mapper;
    }
}
```

## JsonInclude Policies

```java
// Include all fields (default)
mapper.setSerializationInclusion(JsonInclude.Include.ALWAYS);

// Exclude null fields
mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);

// Exclude null and empty collections/strings
mapper.setSerializationInclusion(JsonInclude.Include.NON_EMPTY);

// Exclude fields with default values (0, false, empty)
mapper.setSerializationInclusion(JsonInclude.Include.NON_DEFAULT);
```

## Custom Serializers

```java
@Configuration
public class JacksonConfig {

    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        
        // Register custom serializers
        SimpleModule module = new SimpleModule();
        module.addSerializer(OrderStatus.class, new OrderStatusSerializer());
        module.addDeserializer(OrderStatus.class, new OrderStatusDeserializer());
        mapper.registerModule(module);
        
        return mapper;
    }
}

// Custom enum serializer
public class OrderStatusSerializer extends JsonSerializer<OrderStatus> {
    @Override
    public void serialize(OrderStatus value, JsonGenerator gen, SerializerProvider serializers) 
            throws IOException {
        gen.writeString(value.name());
    }
}

// Custom enum deserializer
public class OrderStatusDeserializer extends JsonDeserializer<OrderStatus> {
    @Override
    public OrderStatus deserialize(JsonParser p, DeserializationContext ctxt) 
            throws IOException {
        return OrderStatus.valueOf(p.getText());
    }
}
```

## Common Configurations

```java
@Bean
public ObjectMapper objectMapper() {
    ObjectMapper mapper = new ObjectMapper();
    
    // Java 8 date/time support
    mapper.registerModule(new JavaTimeModule());
    mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    
    // Ignore unknown properties during deserialization
    mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
    
    // Pretty print JSON (dev only)
    mapper.enable(SerializationFeature.INDENT_OUTPUT);
    
    // Exclude null fields
    mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);
    
    return mapper;
}
```

## Anti-Patterns

- **NOT** writing JacksonConfig in infrastructure module — Spring Boot auto-configures ObjectMapper at adapter level; infrastructure should inject and reuse it.
- **NOT** manually registering `JavaTimeModule` if `spring-boot-starter-web` is on the classpath — already done by `JacksonAutoConfiguration`. Only register it when you're building a non-web module from scratch.
- **NOT** `mapper.setDefaultPropertyInclusion(JsonInclude.Value.ALWAYS)` — `JsonInclude.Value` has no `ALWAYS` constant. Use `mapper.setSerializationInclusion(JsonInclude.Include.ALWAYS)` instead.
- **NOT** using `@JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")` on every field — configure globally via JavaTimeModule + disabling WRITE_DATES_AS_TIMESTAMPS, then ISO-8601 is the default.
- **NOT** creating multiple ObjectMapper beans without `@Primary` — Spring will fail with `NoUniqueBeanDefinitionException`. Override the default with `@Primary` or use `@Qualifier`.
- **NOT** declaring `jackson-datatype-jsr310` explicitly when `spring-boot-starter-web` is already a transitive dependency — it's redundant and risks version conflicts.

## Related Skills

- `spring-boot-rest-client`
- `ddd-cola`
- `spring-boot-rest-api-standards`
