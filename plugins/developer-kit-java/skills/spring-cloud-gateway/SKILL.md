---
name: spring-cloud-gateway
description: Spring Cloud Gateway patterns for Spring Boot 3.5.x covering routing, filters, rate limiting, and load balancing. Use when building API gateways for microservices.
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Cloud Gateway

API gateway patterns for Spring Boot 3.5.x microservices.

## When to use this skill

- Building an API gateway for microservices
- Configuring routing, load balancing, or rate limiting
- Adding cross-cutting concerns (auth, logging, CORS) at gateway level

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
```

BOM:
```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>2025.0.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

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
@Bean
public KeyResolver ipKeyResolver() {
    return exchange -> Mono.just(
        Objects.requireNonNull(exchange.getRequest().getRemoteAddress())
            .getAddress().getHostAddress());
}
```

## Best Practices

- Use `lb://service-name` URIs with Nacos/Eureka for load balancing
- Apply global filters for cross-cutting concerns (auth, logging, tracing)
- Configure circuit breakers per route with fallback URIs
- Use rate limiting with Redis to protect downstream services
- Keep gateway stateless — no business logic here
