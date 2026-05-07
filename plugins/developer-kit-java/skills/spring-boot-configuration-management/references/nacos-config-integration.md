# Nacos Config Center Integration

## Dependency

```xml
<!-- Nacos Config Center -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
</dependency>

<!-- Required for bootstrap.yml in Spring Boot 3.x -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-bootstrap</artifactId>
</dependency>

<!-- BOM (Spring Boot 3.5.x + Spring Cloud Alibaba 2023.x) -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>2023.0.3.2</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

> Spring Boot 3.x removed the bootstrap context by default. You MUST add `spring-cloud-starter-bootstrap` to enable `bootstrap.yml` loading. Without it, use `spring.config.import=nacos:` in `application.yml` instead.

## bootstrap.yml Configuration

```yaml
# bootstrap.yml — loaded before application.yml by bootstrap context
spring:
  application:
    name: user-service
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}
  cloud:
    nacos:
      config:
        server-addr: ${NACOS_ADDR:localhost:8848}
        namespace: ${NACOS_NAMESPACE:dev}
        group: DEFAULT_GROUP
        file-extension: yaml
        # Data ID convention: ${spring.application.name}-${spring.profiles.active}.${file-extension}
        # Example: user-service-dev.yaml
        shared-configs:
          - data-id: common-datasource.yaml
            group: DEFAULT_GROUP
            refresh: true
          - data-id: common-redis.yaml
            group: DEFAULT_GROUP
            refresh: true
        extension-configs:
          - data-id: user-service-custom.yaml
            group: DEFAULT_GROUP
            refresh: true
```

### Alternative: spring.config.import (without bootstrap context)

If you do not use `spring-cloud-starter-bootstrap`, configure Nacos via `spring.config.import` in `application.yml`:

```yaml
spring:
  application:
    name: user-service
  config:
    import: nacos:user-service-dev.yaml?group=DEFAULT_GROUP&refresh=true
  cloud:
    nacos:
      config:
        server-addr: ${NACOS_ADDR:localhost:8848}
        namespace: ${NACOS_NAMESPACE:dev}
        group: DEFAULT_GROUP
        file-extension: yaml
```

## Data ID Naming Convention

The Data ID determines which config file Nacos loads for your service. Convention:

```
${spring.application.name}-${spring.profiles.active}.${file-extension}
```

Examples:

| Application Name | Profile | File Extension | Data ID               |
|-----------------|---------|---------------|----------------------|
| user-service    | dev     | yaml          | user-service-dev.yaml |
| user-service    | prod    | yaml          | user-service-prod.yaml |
| order-service   | test    | properties    | order-service-test.properties |

> The `file-extension` must match the actual format of the config stored in Nacos. If you set `file-extension: yaml`, Nacos expects YAML-formatted content.

## Shared Configs vs Extension Configs

### Shared configs — cross-service common settings

Shared configs apply to ALL services in the same namespace/group. Use for infrastructure settings that every service needs.

```yaml
spring:
  cloud:
    nacos:
      config:
        shared-configs:
          # Common datasource config — every service connects to the same MySQL
          - data-id: common-datasource.yaml
            group: DEFAULT_GROUP
            refresh: true
          # Common Redis config — every service uses the same Redis cluster
          - data-id: common-redis.yaml
            group: DEFAULT_GROUP
            refresh: true
          # Common logging config — consistent log format across services
          - data-id: common-logging.yaml
            group: SHARED_GROUP
            refresh: false  # logging config rarely needs dynamic refresh
```

### Extension configs — service-specific settings

Extension configs apply to a specific service. Use for settings unique to this service.

```yaml
spring:
  cloud:
    nacos:
      config:
        extension-configs:
          # Custom rate-limiting rules for this service only
          - data-id: user-service-rate-limit.yaml
            group: DEFAULT_GROUP
            refresh: true
          # Custom business rules for this service
          - data-id: user-service-business.yaml
            group: DEFAULT_GROUP
            refresh: true
```

### Config merging priority (highest wins)

1. Service-specific config (Data ID: `${name}-${profile}.${ext}`)
2. Extension configs (listed in order, last wins)
3. Shared configs (listed in order, last wins)
4. `application.yml` / `application-{profile}.yml` in the jar

## @RefreshScope for Dynamic Refresh

`@RefreshScope` wraps a bean in a proxy. When Nacos config changes and a refresh event is triggered, Spring destroys the proxy and recreates the bean with new property values.

```java
@Service
@RefreshScope
@RequiredArgsConstructor
@Slf4j
public class DynamicConfigService {

    // @Value works with @RefreshScope — properties are re-read on refresh
    @Value("${app.feature.enabled:true}")
    private boolean featureEnabled;

    @Value("${app.max-connections:100}")
    private int maxConnections;

    public boolean isFeatureEnabled() {
        return featureEnabled;
    }

    public int getMaxConnections() {
        return maxConnections;
    }
}
```

### @RefreshScope with @ConfigurationProperties

`@ConfigurationProperties` beans are NOT automatically refreshed by Nacos config changes. To make them refreshable, combine `@RefreshScope` with `@ConfigurationProperties`:

```java
@ConfigurationProperties(prefix = "app.rate-limit")
@RefreshScope
@Validated
public record RateLimitProperties(
    @NotNull @Min(1) Integer requestsPerSecond,
    @NotNull @Min(1) Integer burstCapacity
) {}
```

> **Warning**: `@RefreshScope` creates a CGLIB proxy. Avoid using `@PostConstruct` in `@RefreshScope` beans — the proxy may not be fully initialized during the first call after a refresh. Use `@AfterRefresh` or lazy initialization instead.

## ConfigListener for Programmatic Change Detection

For cases where you need to react to config changes in code (e.g., re-initializing a connection pool, updating a cache), use `NacosConfigListener`:

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class NacosConfigListener {

    private final NacosConfigService nacosConfigService;

    @PostConstruct
    public void registerListeners() {
        // Listen to service-specific config changes
        nacosConfigService.addListener(
            "user-service-dev.yaml",
            "DEFAULT_GROUP",
            configInfo -> {
                log.info("Config changed for user-service-dev.yaml: {}", configInfo);
                handleConfigChange(configInfo);
            }
        );

        // Listen to shared config changes
        nacosConfigService.addListener(
            "common-datasource.yaml",
            "DEFAULT_GROUP",
            configInfo -> {
                log.info("Shared datasource config changed: {}", configInfo);
                handleDatasourceChange(configInfo);
            }
        );
    }

    private void handleConfigChange(ConfigInfo configInfo) {
        // Parse new config and re-initialize resources
        // Example: update thread pool size, toggle feature flags, etc.
    }

    private void handleDatasourceChange(ConfigInfo configInfo) {
        // Re-create datasource connection pool
        // WARNING: datasource refresh requires DataSource rebuild
    }
}
```

## Nacos Config File Formats

Nacos supports YAML and properties formats. The `file-extension` in bootstrap.yml determines which format to use:

### YAML format (recommended)

```yaml
# In Nacos config editor — Format: YAML
spring:
  datasource:
    url: jdbc:mysql://prod-mysql:3306/mydb
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}

app:
  feature:
    enabled: true
  rate-limit:
    requests-per-second: 100
```

### Properties format

```properties
# In Nacos config editor — Format: Properties
spring.datasource.url=jdbc:mysql://prod-mysql:3306/mydb
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}

app.feature.enabled=true
app.rate-limit.requests-per-second=100
```

> **Recommendation**: Use YAML format for Nacos configs. YAML supports nested structure, lists, and maps naturally. Properties format is flat and harder to manage for complex configs.

## Common Issues and Solutions

### Issue: Config not loading from Nacos

**Cause**: Missing `spring-cloud-starter-bootstrap` dependency (Spring Boot 3.x).

**Solution**: Add the dependency, or use `spring.config.import=nacos:` in `application.yml`.

### Issue: Config changes not propagating

**Cause**: `@ConfigurationProperties` beans are not refreshable by default.

**Solution**: Add `@RefreshScope` on the config bean, or use `@NacosConfigurationProperties` (Alibaba-specific annotation that supports auto-refresh).

### Issue: @PostConstruct runs before refresh completes

**Cause**: `@RefreshScope` proxy lifecycle — bean is lazily initialized on first access, not at startup.

**Solution**: Avoid `@PostConstruct` in `@RefreshScope` beans. Use `SmartLifecycle` or `ApplicationReadyEvent` for initialization.

### Issue: Shared config overrides service config

**Cause**: Config merging priority — shared configs listed later override earlier ones.

**Solution**: List shared configs before extension configs. Service-specific config (Data ID) has the highest priority.