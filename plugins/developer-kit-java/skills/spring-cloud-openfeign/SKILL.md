---
name: spring-cloud-openfeign
description: Spring Cloud OpenFeign declarative HTTP client patterns for Spring Boot 3.5.x. Use when making service-to-service HTTP calls in microservices.
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Cloud OpenFeign

Declarative HTTP client for Spring Boot 3.5.x microservices.

## When to Use

- Making service-to-service HTTP calls
- Replacing RestTemplate/WebClient with declarative clients
- Integrating with Nacos service discovery for load balancing

## Dependencies

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-loadbalancer</artifactId>
</dependency>
```

## Enable Feign

```java
@SpringBootApplication
@EnableFeignClients
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
```

## Feign Client

```java
@FeignClient(name = "user-service", fallback = UserClientFallback.class)
public interface UserClient {

    @GetMapping("/api/users/{id}")
    UserResponse getUser(@PathVariable Long id);

    @PostMapping("/api/users")
    UserResponse createUser(@RequestBody CreateUserRequest request);
}
```

## Fallback

```java
@Component
public class UserClientFallback implements UserClient {

    @Override
    public UserResponse getUser(Long id) {
        return UserResponse.empty(id);
    }

    @Override
    public UserResponse createUser(CreateUserRequest request) {
        throw new ServiceUnavailableException("user-service unavailable");
    }
}
```

## Configuration

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connect-timeout: 3000
            read-timeout: 5000
            logger-level: BASIC
          user-service:
            connect-timeout: 1000
            read-timeout: 3000
```

## Request Interceptor (Pass JWT)

```java
@Component
public class FeignAuthInterceptor implements RequestInterceptor {

    @Override
    public void apply(RequestTemplate template) {
        ServletRequestAttributes attrs =
            (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attrs != null) {
            String token = attrs.getRequest().getHeader(HttpHeaders.AUTHORIZATION);
            if (token != null) {
                template.header(HttpHeaders.AUTHORIZATION, token);
            }
        }
    }
}
```

## Best Practices

- Always define fallbacks for resilience
- Use `name` matching Nacos service ID for automatic load balancing
- Set reasonable timeouts per client
- Pass JWT tokens via `RequestInterceptor` for auth propagation
- Use `@FeignClient(contextId = "...")` when multiple clients target the same service
