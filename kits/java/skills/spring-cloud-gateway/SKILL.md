---
name: spring-cloud-gateway
description: "Spring Cloud Gateway: routing, filters, rate limiting, and load balancing. Use when building API gateways for microservices."
version: "1.1.0"
---

# Spring Cloud Gateway

## When to use

- Building an API gateway for microservices
- Configuring routing, load balancing, or rate limiting
- Adding cross-cutting concerns (auth, logging, CORS) at gateway level

## Critical constraint

Spring Cloud Gateway runs on **WebFlux + Netty** only.
NOT compatible with `spring-boot-starter-web` (Tomcat) — adding it breaks the gateway at startup.

## Dependencies

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-gateway</artifactId>
</dependency>
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
</dependency>
<!-- CircuitBreaker filter (optional, requires Resilience4j) -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-circuitbreaker-reactor-resilience4j</artifactId>
</dependency>
```

BOM: For version alignment, see `spring-cloud-alibaba` skill.

## Route Configuration

```yaml
spring:
  cloud:
    gateway:
      discovery:
        locator:
          enabled: true
          lower-case-service-id: true
      routes:
        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
          filters:
            - StripPrefix=1
            - name: CircuitBreaker
              args:
                name: userServiceCB
                fallbackUri: forward:/fallback/user
        - id: order-service
          uri: lb://order-service
          predicates:
            - Path=/api/orders/**
            - Method=GET,POST
          filters:
            - AddRequestHeader=X-Gateway-Source, gateway
```

## CORS (Global)

```yaml
spring:
  cloud:
    gateway:
      globalcors:
        cors-configurations:
          '[/**]':
            allowedOrigins: "https://example.com"
            allowedMethods: GET,POST,PUT,DELETE
            allowedHeaders: "*"
            maxAge: 3600
```

## Global Filter (Auth)

```java
@Component
@Order(-1)
public class AuthGlobalFilter implements GlobalFilter {
    private final JwtService jwtService;

    public AuthGlobalFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getPath().value();
        if (path.startsWith("/api/auth/")) {
            return chain.filter(exchange);
        }
        String token = extractToken(exchange.getRequest());
        if (token == null || !jwtService.isValid(token)) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }
        return chain.filter(exchange);
    }

    private String extractToken(ServerHttpRequest request) {
        String header = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        return (header != null && header.startsWith("Bearer ")) ? header.substring(7) : null;
    }
}
```

## Rate Limiting

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 10
                redis-rate-limiter.burstCapacity: 20
                key-resolver: "#{@ipKeyResolver}"
```

```java
@Configuration
public class RateLimiterConfig {
    @Bean
    public KeyResolver ipKeyResolver() {
        return exchange -> Mono.just(
            Objects.requireNonNull(exchange.getRequest().getRemoteAddress())
                .getAddress().getHostAddress());
    }
}
```

## Best Practices

- NOT put domain logic or data transformations in the gateway — keep it a thin routing layer
- NOT use `@Controller` / `@RequestMapping` — gateway is WebFlux-only, use `GlobalFilter` or `WebHandler`
- NOT add `spring-boot-starter-web` — conflicts with WebFlux and breaks startup
- Prefer programmatic `KeyResolver` bean over SpEL `#{@...}` for testability
- Keep filters short and single-purpose — chain multiple focused filters instead of one monolithic filter

## Related Skills

`spring-boot-resilience4j`, `spring-cloud-alibaba`