# @ConfigurationProperties Patterns

## Basic Pattern with prefix

```java
@ConfigurationProperties(prefix = "app.server")
public record ServerProperties(
    String host,
    Integer port,
    Integer timeoutSeconds
) {
    // Default values via record field defaults
    public ServerProperties() {
        this("localhost", 8080, 30);
    }
}
```

```yaml
app:
  server:
    host: 192.168.1.100
    port: 9090
    timeout-seconds: 60
```

## Constructor Binding with Java Record (Spring Boot 3.x preferred)

Spring Boot 3.x uses Java records for immutable configuration. Records naturally support constructor binding — no `@ConstructorBinding` annotation needed (it was removed in Spring Boot 3.0).

```java
@ConfigurationProperties(prefix = "app.database")
public record DatabaseProperties(
    String url,
    String username,
    String password,
    Integer poolSize,
    Duration connectionTimeout
) {
    // Compact constructor for defaults
    public DatabaseProperties {
        if (poolSize == null) poolSize = 10;
        if (connectionTimeout == null) connectionTimeout = Duration.ofSeconds(30);
    }
}
```

For classes (when you cannot use records), constructor binding requires exactly one constructor:

```java
@ConfigurationProperties(prefix = "app.database")
@Validated
public class DatabaseProperties {

    @NotBlank
    private final String url;
    @NotBlank
    private final String username;
    private final String password;
    @Min(1)
    @Max(100)
    private final Integer poolSize;

    // Single constructor — Spring Boot 3.x auto-detects for binding
    public DatabaseProperties(String url, String username, String password, Integer poolSize) {
        this.url = url;
        this.username = username;
        this.password = password;
        this.poolSize = poolSize == null ? 10 : poolSize;
    }

    // Getters (no setters — immutable)
    public String getUrl() { return url; }
    public String getUsername() { return username; }
    public String getPassword() { return password; }
    public Integer getPoolSize() { return poolSize; }
}
```

## Nested Configuration Properties

### Using inner records

```java
@ConfigurationProperties(prefix = "app")
@Validated
public record AppProperties(
    @Valid @NotNull JwtProperties jwt,
    @Valid @NotNull CacheProperties cache,
    @Valid @NotNull DataSourceProperties datasource
) {
    public record JwtProperties(
        @NotBlank String secret,
        @NotNull @Min(60) Long expirationSeconds,
        @NotBlank String issuer
    ) {}

    public record CacheProperties(
        @NotBlank String type,
        @NotNull @Min(1) Integer ttlSeconds
    ) {}

    public record DataSourceProperties(
        @NotBlank String url,
        @NotBlank String username,
        String password,
        @NotNull @Min(1) Integer poolSize
    ) {}
}
```

```yaml
app:
  jwt:
    secret: ${JWT_SECRET}
    expiration-seconds: 3600
    issuer: my-app
  cache:
    type: redis
    ttl-seconds: 300
  datasource:
    url: jdbc:mysql://localhost:3306/mydb
    username: root
    password: ${DB_PASSWORD}
    pool-size: 20
```

### Using separate classes (for complex or shared sub-configs)

```java
@ConfigurationProperties(prefix = "app.datasource")
@Validated
public record DataSourceProperties(
    @NotBlank String url,
    @NotBlank String username,
    String password,
    @Valid HikariProperties hikari
) {
    public record HikariProperties(
        @Min(1) @Max(100) Integer maximumPoolSize,
        @Min(1) Long connectionTimeout,
        @Min(1) Long idleTimeout
    ) {}
}
```

```yaml
app:
  datasource:
    url: jdbc:mysql://localhost:3306/mydb
    username: root
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 20
      connection-timeout: 30000
      idle-timeout: 600000
```

## @ConfigurationPropertiesScan vs @EnableConfigurationProperties

### @ConfigurationPropertiesScan (auto-discovery)

Recommended for projects where all config classes reside within your application's base package.

```java
@SpringBootApplication
@ConfigurationPropertiesScan(basePackages = "com.mycompany.myapp.config")
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

All `@ConfigurationProperties` classes in `com.mycompany.myapp.config` are auto-registered as Spring beans.

**Advantages**: No need to register each class individually; just annotate with `@ConfigurationProperties`.

**Caveat**: May accidentally scan config classes from third-party libraries if `basePackages` is too broad.

### @EnableConfigurationProperties (explicit registration)

Recommended when you need fine-grained control over which config classes are registered, or when config classes come from external packages.

```java
@Configuration
@EnableConfigurationProperties({
    JwtProperties.class,
    CacheProperties.class,
    DataSourceProperties.class
})
public class PropertiesConfig {
    // No additional bean definitions needed —
    // @EnableConfigurationProperties registers the listed classes as beans
}
```

**Advantages**: Explicit control; no accidental discovery; works with config classes in any package.

## List and Map Binding Patterns

### List binding

```java
@ConfigurationProperties(prefix = "app.security")
public record SecurityProperties(
    List<String> allowedOrigins,
    List<String> publicEndpoints,
    List<IpRange> blockedIpRanges
) {
    public record IpRange(String start, String end) {}
}
```

```yaml
app:
  security:
    allowed-origins:
      - https://myapp.com
      - https://admin.myapp.com
    public-endpoints:
      - /v1/auth/login
      - /v1/auth/refresh
      - /v1/public/**
    blocked-ip-ranges:
      - start: 10.0.0.1
        end: 10.0.0.255
      - start: 192.168.1.1
        end: 192.168.1.100
```

### Map binding

```java
@ConfigurationProperties(prefix = "app.rate-limit")
public record RateLimitProperties(
    Map<String, RateLimitConfig> endpoints
) {
    public record RateLimitConfig(
        Integer requestsPerSecond,
        Integer burstCapacity
    ) {}
}
```

```yaml
app:
  rate-limit:
    endpoints:
      login:
        requests-per-second: 5
        burst-capacity: 10
      order-create:
        requests-per-second: 100
        burst-capacity: 200
      search:
        requests-per-second: 50
        burst-capacity: 100
```

Map keys are the property names under the map prefix (`login`, `order-create`, `search`). Spring Boot converts kebab-case keys to camelCase map keys automatically.

## Multi-property Source Merging (defaults + overrides)

Spring Boot merges properties from multiple sources with a well-defined priority order (highest wins):

1. Command-line arguments (`--app.jwt.secret=xxx`)
2. `SPRING_APPLICATION_JSON` environment variable
3. ServletConfig / ServletContext parameters
4. JNDI attributes
5. Java system properties (`System.getProperties()`)
6. OS environment variables (`SPRING_PROFILES_ACTIVE`, `APP_JWT_SECRET`)
7. Profile-specific YAML outside jar (`application-dev.yml`)
8. Profile-specific YAML inside jar (`application-dev.yml`)
9. Default YAML outside jar (`application.yml`)
10. Default YAML inside jar (`application.yml`)
11. `@PropertySource` annotated sources
12. Default properties (`SpringApplication.setDefaultProperties`)

### Practical merging pattern

```yaml
# application.yml — safe defaults (inside jar)
app:
  jwt:
    secret: change-me-in-production  # placeholder, overridden in prod
    expiration-seconds: 3600
    issuer: my-app

# application-prod.yml — production overrides (outside jar or in Nacos)
app:
  jwt:
    secret: ${JWT_SECRET}  # from environment variable
    expiration-seconds: 1800
```

Environment variable mapping for Spring Boot relaxed binding:

| YAML key              | Environment variable          |
|-----------------------|-------------------------------|
| `app.jwt.secret`      | `APP_JWT_SECRET`              |
| `app.jwt.expiration-seconds` | `APP_JWT_EXPIRATION_SECONDS` |
| `spring.profiles.active`     | `SPRING_PROFILES_ACTIVE`      |

> Use environment variables for secrets and environment-specific values. Use YAML defaults for safe, non-sensitive values that work across all environments.