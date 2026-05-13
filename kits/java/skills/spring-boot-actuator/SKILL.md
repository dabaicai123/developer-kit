---
name: spring-boot-actuator
description: "Spring Boot Actuator for production monitoring: health probes, secured management endpoints, and Micrometer metrics. Use when setting up monitoring, health checks, or metrics for Spring Boot applications."
version: "1.0.0"
type: skill
---

# Spring Boot Actuator

## When to use this skill

- Enable actuator endpoints / bootstrap monitoring for a service
- Configure health probes for Kubernetes readiness/liveness
- Export metrics to Prometheus / Micrometer
- Secure management endpoints
- Debug startup or auto-configuration issues

## Quick Start

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<!-- For Prometheus metrics -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

## Configuration

### Basic (dev)

```yaml
management:
  endpoints:
    web:
      exposure:
        include: "health,info,metrics"
  endpoint:
    health:
      show-details: always
```

### Production with Prometheus

```yaml
management:
  server:
    port: 9091
  endpoints:
    web:
      exposure:
        include: "health,info,metrics,prometheus"
      base-path: "/management"
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when-authorized
      group:
        readiness:
          include: "readinessState,db,redis"
        liveness:
          include: "livenessState"
  prometheus:
    metrics:
      export:
        descriptions: true
        step: 30s
```

## Secure Management Endpoints

```java
@Configuration
public class ActuatorSecurityConfig {

    @Bean
    @Order(1)
    public SecurityFilterChain actuatorChain(HttpSecurity http) throws Exception {
        http.securityMatcher(EndpointRequest.toAnyEndpoint())
            .authorizeHttpRequests(c -> c
                .requestMatchers(EndpointRequest.to("health")).permitAll()
                .anyRequest().hasRole("ENDPOINT_ADMIN"))
            .httpBasic(Customizer.withDefaults());
        return http.build();
    }
}
```

## Custom Health Indicator

```java
@Component
public class ExternalServiceHealth implements HealthIndicator {
    private final ExternalClient client;

    public ExternalServiceHealth(ExternalClient client) {
        this.client = client;
    }

    @Override
    public Health health() {
        boolean reachable = client.ping();
        return reachable
            ? Health.up().withDetail("latencyMs", client.latency()).build()
            : Health.down().withDetail("error", "Service timeout").build();
    }
}
```

## Best Practices

- Expose only required endpoints; never expose `/env`, `/heapdump`, `/logfile` on public networks
- Use dedicated management port (`management.server.port`) with firewall rules
- Keep `/health` publicly accessible for load balancer checks only
- Add `application` and `environment` tags via `MeterRegistryCustomizer` for metric correlation
- Health indicators must be fast (< 250ms) — never block on slow operations

## Related Skills

- `spring-boot-logging`
- `spring-boot-resilience4j`
- `spring-boot-security-jwt`
