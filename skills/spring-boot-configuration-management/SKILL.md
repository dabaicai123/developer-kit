---
name: spring-boot-configuration-management
description: "Spring Boot configuration management — @ConfigurationProperties, Nacos Config Center integration, profile-based configuration, property validation, and type-safe config patterns"
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Configuration Management

## When to use this skill

- Creating type-safe configuration classes with `@ConfigurationProperties`
- Integrating Nacos Config Center for dynamic configuration refresh
- Setting up profile-based configuration for multi-environment deployment
- Adding property validation with JSR-380 annotations and `@Validated`
- Choosing between `@Value` and `@ConfigurationProperties` for property binding
- Managing nested, list, and map configuration structures

## Instructions

### Type-safe configuration with @ConfigurationProperties

Use `@ConfigurationProperties` to bind grouped properties into a single type-safe object. Prefer constructor binding (Java record for Spring Boot 3.x) over setter binding to keep config immutable.

Steps:

1. **Define a configuration class** — Use a Java record with `@ConfigurationProperties(prefix = "...")` and `@Validated` for constructor binding. Each field maps to a property under the prefix.
2. **Register the config class** — Either use `@ConfigurationPropertiesScan` on the main application class to auto-discover, or use `@EnableConfigurationProperties` on a `@Configuration` class to register explicitly.
3. **Write matching YAML properties** — Use kebab-case (`my-property`) for property keys in YAML. Spring Boot auto-converts kebab-case to camelCase in Java.
4. **Inject and use** — Inject the config class via constructor injection into services that need the config values.

### Nacos Config Center integration for dynamic config

Use Nacos Config Center (spring-cloud-starter-alibaba-nacos-config) for centralized, dynamically refreshed configuration in microservices.

Steps:

1. **Add Nacos Config dependency** — Include `spring-cloud-starter-alibaba-nacos-config` and `spring-cloud-starter-bootstrap` (Spring Boot 3.x requires bootstrap context).
2. **Create bootstrap.yml** — Configure Nacos server address, namespace, group, shared configs, and extension configs. The Data ID follows the convention `${spring.application.name}-${profile}.${file-extension}`.
3. **Use @RefreshScope for dynamic refresh** — Annotate beans that need live config updates with `@RefreshScope`. When Nacos config changes, Spring destroys and recreates the proxy bean with new values.
4. **Use ConfigListener for programmatic change detection** — Register a `ConfigListener` on the `NacosConfigService` to react to config changes in code (e.g., re-initializing a cache pool).
5. **Manage shared vs extension configs** — Use `shared-configs` for cross-service settings (e.g., common datasource, Redis); use `extension-configs` for service-specific settings.

### Profile-based configuration

Use Spring profiles to separate configuration for different environments (dev, test, prod).

Steps:

1. **Create profile-specific YAML files** — Name them `application-{profile}.yml` (e.g., `application-dev.yml`, `application-prod.yml`). Each file contains only the properties that differ from the default.
2. **Activate a profile** — Set `spring.profiles.active` in `application.yml`, or use the environment variable `SPRING_PROFILES_ACTIVE`, or pass `--spring.profiles.active=dev` as a command-line argument.
3. **Use multi-document YAML** — Within a single YAML file, use the `---` separator with `spring.config.activate.on-profile` to define profile-specific sections inline.
4. **Apply @Profile to @ConfigurationProperties** — Use `@Profile("prod")` on config classes that should only activate in specific environments.
5. **Understand default profile behavior** — Properties in `application.yml` apply to all profiles unless overridden by a profile-specific file.

### Property validation

Use JSR-380 (Jakarta Bean Validation) annotations with `@Validated` on `@ConfigurationProperties` classes to catch invalid config at startup.

Steps:

1. **Add validation dependency** — Include `spring-boot-starter-validation`.
2. **Annotate config fields** — Use `@NotNull`, `@NotBlank`, `@Min`, `@Max`, `@Pattern`, `@Email`, `@Size` on config class fields.
3. **Add @Validated to the config class** — Spring validates all properties at startup. If validation fails, the application fails to start with a clear `BindValidationException`.
4. **Validate nested properties** — Add `@Valid` on nested config fields to cascade validation into inner config objects.
5. **Create custom validators** — For domain-specific rules, create a custom constraint annotation with `@Constraint` and a `ConstraintValidator` implementation.

## Examples

### Example 1: @ConfigurationProperties class with @Validated and JSR-380 constraints

```java
@ConfigurationProperties(prefix = "app.jwt")
@Validated
public record JwtProperties(
    @NotBlank(message = "JWT secret must not be blank")
    @Size(min = 32, max = 512, message = "JWT secret must be 32-512 characters")
    String secret,

    @NotNull(message = "JWT expiration must not be null")
    @Min(value = 60, message = "JWT expiration must be at least 60 seconds")
    @Max(value = 86400, message = "JWT expiration must be at most 86400 seconds")
    Long expirationSeconds,

    @NotBlank(message = "JWT issuer must not be blank")
    String issuer,

    @Valid
    @NotNull
    TokenProperties token
) {
    public record TokenProperties(
        @NotBlank String accessTokenHeader,
        @NotBlank String refreshTokenPath,
        @Min(1) @Max(30) Integer refreshTokenExpirationDays
    ) {}
}
```

### Example 2: application.yml with nested properties matching the config class

```yaml
app:
  jwt:
    secret: ${JWT_SECRET:my-default-secret-at-least-32-characters-long}
    expiration-seconds: 3600
    issuer: my-app
    token:
      access-token-header: Authorization
      refresh-token-path: /api/v1/auth/refresh
      refresh-token-expiration-days: 7

# Property key naming convention: use kebab-case in YAML
# Spring Boot maps kebab-case to camelCase automatically:
#   expiration-seconds -> expirationSeconds
#   access-token-header -> accessTokenHeader
```

### Example 3: Nacos Config Center setup — bootstrap.yml, @RefreshScope, dynamic property refresh

```yaml
# bootstrap.yml (loaded before application.yml)
spring:
  application:
    name: user-service
  profiles:
    active: dev
  cloud:
    nacos:
      config:
        server-addr: ${NACOS_ADDR:localhost:8848}
        namespace: ${NACOS_NAMESPACE:dev}
        group: DEFAULT_GROUP
        file-extension: yaml
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

```java
@RestController
@RefreshScope
@RequiredArgsConstructor
public class ConfigController {

    private final AppProperties appProperties;

    @GetMapping("/config")
    public AppProperties getConfig() {
        return appProperties;
    }
}

// ConfigListener for programmatic change detection
@Component
@RequiredArgsConstructor
@Slf4j
public class NacosConfigChangeListener {

    private final NacosConfigService nacosConfigService;

    @PostConstruct
    public void init() {
        nacosConfigService.addListener("user-service-dev.yaml", "DEFAULT_GROUP",
            configInfo -> {
                log.info("Config changed: {}", configInfo);
                // Re-initialize resources based on new config
            });
    }
}
```

### Example 4: Profile-specific YAML (application-dev.yml, application-prod.yml)

```yaml
# application.yml — shared defaults
app:
  name: my-app
  jwt:
    issuer: my-app
    token:
      access-token-header: Authorization
      refresh-token-path: /api/v1/auth/refresh

---
# application-dev.yml — development overrides
spring:
  config:
    activate:
      on-profile: dev

app:
  jwt:
    secret: dev-secret-for-local-testing-at-least-32-chars
    expiration-seconds: 86400
  cache:
    type: local
    ttl-seconds: 60

server:
  port: 8080

logging:
  level:
    root: DEBUG

---
# application-prod.yml — production overrides
spring:
  config:
    activate:
      on-profile: prod

app:
  jwt:
    secret: ${JWT_SECRET}
    expiration-seconds: 1800
  cache:
    type: redis
    ttl-seconds: 3600

server:
  port: 8443

logging:
  level:
    root: WARN
```

### Example 5: @Value vs @ConfigurationProperties comparison — when to use each

```java
// @Value — for single, simple property injection
// Use ONLY for one-off values, third-party config keys, or SpEL expressions
@Service
public class S3Service {
    @Value("${aws.s3.bucket-name}")
    private String bucketName;

    @Value("${aws.s3.region:us-east-1}")  // supports default value inline
    private String region;
}

// @ConfigurationProperties — for grouped, type-safe, validated properties
// Use for ANY set of related config properties
@ConfigurationProperties(prefix = "app.cache")
@Validated
public record CacheProperties(
    @NotBlank String type,
    @NotNull @Min(1) Integer ttlSeconds,
    @NotNull @Min(1) @Max(10000) Integer maxSize
) {}

// Comparison table:
// | Aspect                | @Value                        | @ConfigurationProperties    |
// |-----------------------|-------------------------------|----------------------------|
// | Type-safe binding     | No (String only)              | Yes (any type)             |
// | Validation            | No                            | Yes (@Validated + JSR-380) |
// | Grouped properties    | No (one per field)            | Yes (single object)        |
// | Nested binding        | No                            | Yes                        |
// | List/Map binding      | No                            | Yes                        |
// | Default values        | Yes (:default syntax)         | Yes (field defaults)       |
// | SpEL support          | Yes                           | No                         |
// | Dynamic refresh       | With @RefreshScope            | Not directly               |
// | Use case              | Single value / SpEL           | Grouped config             |
```

## Best Practices

- Always use `@ConfigurationProperties` over `@Value` for grouped properties
- Use `@Validated` with JSR-380 annotations for config validation
- Prefix config classes with meaningful module names (e.g., `app.jwt`, `app.cache`)
- Keep config classes immutable — use constructor binding (Java record in Spring Boot 3.x)
- Use profile-specific files for environment differences
- With Nacos: use `shared-configs` for cross-service settings, `extension-configs` for service-specific
- Never store secrets in plain YAML — use environment variables (`${ENV_VAR}`) or Vault / Nacos encrypted config
- Use kebab-case for property keys in YAML — Spring Boot auto-maps to camelCase in Java
- Set defaults in `application.yml` and override only differences in profile-specific files
- Register config classes with `@ConfigurationPropertiesScan` for auto-discovery, or `@EnableConfigurationProperties` when you need explicit control

## Constraints and Warnings

- `@Value` doesn't support type-safe binding or validation — avoid for grouped properties
- `@RefreshScope` creates proxy objects — be careful with `@PostConstruct` initialization order; the proxy may not be fully initialized during construction
- Nacos config changes may not propagate to beans created before refresh — `@ConfigurationProperties` beans are NOT refreshable by default; use `@RefreshScope` or `@NacosConfigurationProperties` (Alibaba-specific)
- Constructor binding requires no-args constructor is absent — Java records naturally satisfy this; for classes, ensure only one constructor and do NOT use `@Autowired` on it (Spring Boot 3.x auto-detects the constructor)
- Property key naming: use kebab-case (`my-property`) not camelCase or snake_case in YAML — this is the Spring Boot standard; camelCase keys work but are not recommended
- `@ConfigurationPropertiesScan` may accidentally pick up config classes from third-party libraries — limit with `basePackages`
- `spring.cloud.nacos.config.file-extension` must match the actual config format in Nacos (yaml vs properties)
- In Spring Boot 3.x, `bootstrap.yml` requires `spring-cloud-starter-bootstrap` dependency; without it, use `application.yml` with `spring.config.import=nacos:`

## References

- [configuration-properties-patterns.md](references/configuration-properties-patterns.md): @ConfigurationProperties patterns, constructor binding, nested properties, list/map binding, scan vs enable
- [nacos-config-integration.md](references/nacos-config-integration.md): Nacos Config Center setup, bootstrap.yml, shared/extension configs, @RefreshScope, ConfigListener
- [profile-based-configuration.md](references/profile-based-configuration.md): Profile activation, profile-specific files, multi-document YAML, @Profile on config classes
- [property-validation-patterns.md](references/property-validation-patterns.md): JSR-380 validation on config, @Validated, custom ConstraintValidator, nested validation

## Related Skills

- `spring-boot-dependency-injection` — constructor injection, @Autowired, Bean lifecycle
- `spring-boot-actuator` — production monitoring and environment info endpoints
- `spring-cloud-alibaba` — Nacos Config Center, shared/extension configs, @RefreshScope

## Keywords

ConfigurationProperties, Nacos, profile, property, validation, type-safe, RefreshScope, constructor binding