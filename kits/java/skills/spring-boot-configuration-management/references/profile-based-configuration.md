# Profile-Based Configuration

## Profile Activation

### Via application.yml

```yaml
spring:
  profiles:
    active: dev
```

### Via environment variable

```bash
# Linux/macOS
export SPRING_PROFILES_ACTIVE=prod

# Windows PowerShell
$env:SPRING_PROFILES_ACTIVE = "prod"

# Docker
docker run -e SPRING_PROFILES_ACTIVE=prod my-app
```

### Via command-line argument

```bash
java -jar my-app.jar --spring.profiles.active=prod
```

### Priority (highest wins)

1. Command-line argument (`--spring.profiles.active=prod`)
2. Environment variable (`SPRING_PROFILES_ACTIVE=prod`)
3. `application.yml` (`spring.profiles.active: dev`)

> **Production recommendation**: Use environment variable or command-line argument for profile activation. Never hardcode `spring.profiles.active: prod` in `application.yml` — it should always be overrideable.

## Profile-Specific File Naming

Spring Boot automatically loads profile-specific files alongside the default file:

```
application.yml          # Default — applies to all profiles
application-dev.yml      # Development overrides
application-test.yml     # Test overrides
application-prod.yml     # Production overrides
```

### File loading and merging

1. Load `application.yml` (default properties)
2. Load `application-{profile}.yml` (profile-specific overrides)
3. Profile properties override default properties for the same keys
4. Properties NOT present in profile file keep their default values

### Example: dev vs prod

```yaml
# application.yml — safe defaults
app:
  name: my-app
  jwt:
    issuer: my-app
    token:
      access-token-header: Authorization
      refresh-token-path: /v1/auth/refresh

server:
  port: 8080

logging:
  level:
    root: INFO
```

```yaml
# application-dev.yml — only overrides that differ from default
app:
  jwt:
    secret: dev-secret-for-local-testing-at-least-32-characters
    expiration-seconds: 86400  # 1 day for dev convenience
  cache:
    type: local
    ttl-seconds: 60

logging:
  level:
    root: DEBUG
    com.mycompany.myapp: TRACE
```

```yaml
# application-prod.yml — only overrides that differ from default
app:
  jwt:
    secret: ${JWT_SECRET}  # MUST come from environment variable
    expiration-seconds: 1800  # 30 minutes for prod security
  cache:
    type: redis
    ttl-seconds: 3600

server:
  port: 8443

logging:
  level:
    root: WARN
    com.mycompany.myapp: INFO
```

## @Profile on @ConfigurationProperties

Use `@Profile` on config classes to activate them only in specific environments:

```java
// Dev-only config — uses local cache
@ConfigurationProperties(prefix = "app.cache")
@Profile("dev")
public record DevCacheProperties(
    String type,  // defaults to "local"
    Integer ttlSeconds
) {
    public DevCacheProperties {
        if (type == null) type = "local";
        if (ttlSeconds == null) ttlSeconds = 60;
    }
}

// Prod-only config — uses Redis cache
@ConfigurationProperties(prefix = "app.cache")
@Profile("prod")
@Validated
public record ProdCacheProperties(
    @NotBlank String type,
    @NotNull @Min(300) Integer ttlSeconds,
    @NotBlank String redisHost,
    @NotNull Integer redisPort
) {}
```

> **Alternative approach**: Prefer a single config class with profile-specific YAML overrides, rather than `@Profile`-annotated config classes. Single config class is simpler and avoids code duplication.

```java
// Single config class — simpler, values differ per profile in YAML
@ConfigurationProperties(prefix = "app.cache")
@Validated
public record CacheProperties(
    @NotBlank String type,
    @NotNull @Min(1) Integer ttlSeconds,
    String redisHost,
    Integer redisPort
) {}
```

```yaml
# application-dev.yml
app:
  cache:
    type: local
    ttl-seconds: 60

# application-prod.yml
app:
  cache:
    type: redis
    ttl-seconds: 3600
    redis-host: ${REDIS_HOST:redis-cluster}
    redis-port: 6379
```

## Multi-Document YAML (--- separator)

Use the `---` separator within a single YAML file to define profile-specific sections inline:

```yaml
# application.yml — single file with all profiles

# Default section (no profile filter)
app:
  name: my-app
  jwt:
    issuer: my-app

server:
  port: 8080

---
# Dev profile section
spring:
  config:
    activate:
      on-profile: dev

app:
  jwt:
    secret: dev-secret-for-local-testing-at-least-32-characters
    expiration-seconds: 86400

logging:
  level:
    root: DEBUG

---
# Test profile section
spring:
  config:
    activate:
      on-profile: test

app:
  jwt:
    secret: test-secret-for-ci-environment-at-least-32-characters
    expiration-seconds: 3600

logging:
  level:
    root: INFO

---
# Prod profile section
spring:
  config:
    activate:
      on-profile: prod

app:
  jwt:
    secret: ${JWT_SECRET}
    expiration-seconds: 1800

server:
  port: 8443

logging:
  level:
    root: WARN
```

> **Spring Boot 3.5.x**: The `spring.config.activate.on-profile` property replaces the deprecated `spring.profiles` property for multi-document YAML sections. The old `spring.profiles: dev` syntax is removed.

## Default Profile Behavior

### What is the "default" profile?

If no profile is active, Spring Boot uses the properties from `application.yml` only. There is NO automatic "default" profile.

### Creating a default profile

You can define a `default` profile that activates when no other profile is specified:

```yaml
# application-default.yml
app:
  jwt:
    secret: default-secret-for-development-at-least-32-characters
    expiration-seconds: 86400
```

When `spring.profiles.active` is empty, Spring Boot activates the `default` profile automatically (if `application-default.yml` exists).

### Adding profiles at runtime

```bash
# Activate multiple profiles
java -jar my-app.jar --spring.profiles.active=prod,metrics

# Add a profile without overriding the active one
java -jar my-app.jar --spring.profiles.include=debug
```

The `spring.profiles.include` property adds profiles without replacing the currently active ones. Use it to layer additional config groups.

## Profile Groups (Spring Boot 3.x)

Profile groups let you activate a group of profiles together:

```yaml
spring:
  profiles:
    group:
      # "local" activates dev + localdb + localcache
      local:
        - dev
        - localdb
        - localcache
      # "production" activates prod + prodmon + prodsecurity
      production:
        - prod
        - prodmon
        - prodsecurity
```

```bash
# Activates dev + localdb + localcache together
java -jar my-app.jar --spring.profiles.active=local
```

This is useful for grouping environment-specific configuration sets (e.g., local development uses local DB + local cache, while production uses cloud DB + Redis + monitoring).

## Environment Variable Override

Spring Boot maps environment variables to properties using relaxed binding rules:

| YAML Property                     | Environment Variable                    |
|-----------------------------------|----------------------------------------|
| `spring.profiles.active`          | `SPRING_PROFILES_ACTIVE`               |
| `app.jwt.secret`                  | `APP_JWT_SECRET`                       |
| `app.jwt.expiration-seconds`      | `APP_JWT_EXPIRATION_SECONDS`           |
| `server.port`                     | `SERVER_PORT`                           |

Rules for environment variable mapping:
1. Replace dots (`.`) with underscores (`_`)
2. Convert to uppercase
3. Strip hyphens (`-`) or convert to underscores (both work)

> **Production deployment**: Always use environment variables for secrets and profile activation in containerized environments (Docker, Kubernetes). Never store secrets in YAML files.

## Kubernetes ConfigMap and Secret

```yaml
# Kubernetes Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  template:
    spec:
      containers:
        - name: user-service
          image: myapp/user-service:latest
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: prod
            - name: APP_JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: user-service-secrets
                  key: jwt-secret
            - name: APP_JWT_EXPIRATION_SECONDS
              value: "1800"
          envFrom:
            - configMapRef:
                name: user-service-config
```