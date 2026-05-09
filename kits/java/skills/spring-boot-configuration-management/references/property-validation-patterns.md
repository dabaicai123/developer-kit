# Property Validation Patterns

## JSR-380 Validation Annotations on @ConfigurationProperties

Spring Boot validates `@ConfigurationProperties` at startup when you add `@Validated` to the config class. If validation fails, the application refuses to start with a `BindValidationException`.

### Dependency

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
```

### Basic validation

```java
@ConfigurationProperties(prefix = "app.server")
@Validated
public record ServerProperties(
    @NotBlank(message = "Server host must not be blank")
    String host,

    @NotNull(message = "Server port must not be null")
    @Min(value = 1, message = "Server port must be at least 1")
    @Max(value = 65535, message = "Server port must be at most 65535")
    Integer port,

    @NotNull(message = "Server timeout must not be null")
    @Min(value = 100, message = "Server timeout must be at least 100ms")
    @Max(value = 30000, message = "Server timeout must be at most 30000ms")
    Duration timeout
) {}
```

```yaml
app:
  server:
    host: localhost
    port: 8080
    timeout: 5000ms
```

### Common JSR-380 annotations for config validation

| Annotation    | Purpose                                  | Example Usage                               |
|---------------|------------------------------------------|---------------------------------------------|
| `@NotNull`    | Value must not be null                   | `@NotNull Integer port`                     |
| `@NotBlank`   | String must not be null or empty/whitespace | `@NotBlank String secret`                |
| `@NotEmpty`   | Collection/String must not be empty      | `@NotEmpty List<String> endpoints`         |
| `@Min`        | Numeric minimum value                    | `@Min(1) Integer poolSize`                 |
| `@Max`        | Numeric maximum value                    | `@Max(100) Integer poolSize`               |
| `@Size`       | String/Collection size bounds            | `@Size(min=32, max=512) String secret`     |
| `@Pattern`    | Regex pattern match                      | `@Pattern(regexp = "^\\d{3}-\\d{4}$")`    |
| `@Email`      | Valid email format                       | `@Email String adminEmail`                 |
| `@Positive`   | Value must be > 0                        | `@Positive Integer retryCount`             |
| `@PositiveOrZero` | Value must be >= 0                   | `@PositiveOrZero Integer timeoutMs`        |
| `@DurationMin` | Duration minimum (Spring-specific)      | `@DurationMin(seconds = 1)`                |
| `@DurationMax` | Duration maximum (Spring-specific)      | `@DurationMax(hours = 24)`                 |

## @Validated on Configuration Class

### Single config class

```java
@ConfigurationProperties(prefix = "app.jwt")
@Validated
public record JwtProperties(
    @NotBlank(message = "JWT secret must not be blank")
    @Size(min = 32, max = 512, message = "JWT secret must be 32-512 characters")
    String secret,

    @NotNull(message = "JWT expiration must not be null")
    @Min(value = 60, message = "JWT expiration must be at least 60 seconds")
    Long expirationSeconds,

    @NotBlank(message = "JWT issuer must not be blank")
    String issuer
) {}
```

### Multiple config classes — each gets its own @Validated

```java
@ConfigurationProperties(prefix = "app.database")
@Validated
public record DatabaseProperties(
    @NotBlank String url,
    @NotBlank String username,
    String password,
    @NotNull @Min(1) @Max(100) Integer poolSize
) {}

@ConfigurationProperties(prefix = "app.redis")
@Validated
public record RedisProperties(
    @NotBlank String host,
    @NotNull @Min(1) @Max(65535) Integer port,
    Duration timeout
) {}
```

> **Important**: `@Validated` must be on EACH config class individually. Putting `@Validated` on the main application class does NOT validate config properties.

## Custom Validator with @Constraint and ConstraintValidator

### Define a custom constraint annotation

```java
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = EndpointValidator.class)
public @interface ValidEndpoint {
    String message() default "Invalid endpoint format — must start with / and match /v{n}/{resource}";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

### Implement the ConstraintValidator

```java
public class EndpointValidator implements ConstraintValidator<ValidEndpoint, String> {

    private static final Pattern ENDPOINT_PATTERN =
        Pattern.compile("^/v[0-9]+/[a-z][a-z0-9-]*(/[a-z0-9-]+)*$");

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null) {
            return true; // @NotBlank handles null check separately
        }
        return ENDPOINT_PATTERN.matcher(value).matches();
    }
}
```

### Use the custom validator on config properties

```java
@ConfigurationProperties(prefix = "app.api")
@Validated
public record ApiProperties(
    @NotBlank
    @ValidEndpoint
    String basePath,

    @NotEmpty
    List<@ValidEndpoint String> publicEndpoints,

    @NotNull
    Duration requestTimeout
) {}
```

```yaml
app:
  api:
    base-path: /v1
    public-endpoints:
      - /v1/auth/login
      - /v1/auth/refresh
    request-timeout: 30s
```

### Another custom validator: port range check

```java
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PortRangeValidator.class)
public @interface PortRange {
    String message() default "Port must be between {min} and {max}";
    int min() default 1;
    int max() default 65535;
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class PortRangeValidator implements ConstraintValidator<PortRange, Integer> {
    private int min;
    private int max;

    @Override
    public void initialize(PortRange annotation) {
        this.min = annotation.min();
        this.max = annotation.max();
    }

    @Override
    public boolean isValid(Integer value, ConstraintValidatorContext context) {
        if (value == null) {
            return true; // @NotNull handles null separately
        }
        return value >= min && value <= max;
    }
}
```

## Startup Validation Failure Handling

When config validation fails, Spring Boot throws a `BindValidationException` and the application refuses to start. The error message includes all failed constraints:

```
***************************
APPLICATION FAILED TO START
***************************

Description:

Binding to target JwtProperties failed:

    Property: app.jwt.secret
    Value: "short"
    Origin: Config file 'application.yml'
    Reason: JWT secret must be 32-512 characters

    Property: app.jwt.expiration-seconds
    Value: null
    Origin: Config file 'application.yml'
    Reason: JWT expiration must not be null
```

### Customizing startup failure behavior

For specific scenarios where you want to log validation errors instead of crashing (e.g., during migration), you can create a custom `ConfigurationPropertiesValidator`:

```java
@Configuration
public class ConfigValidationConfig {

    @Bean
    public ConfigurationPropertiesBindExceptionAdvisor configBindExceptionAdvisor() {
        // Customize how bind validation exceptions are handled
        return new ConfigurationPropertiesBindExceptionAdvisor();
    }
}
```

> **Recommendation**: Always let validation failures crash the application at startup. Invalid config in production is worse than a startup failure. Fix the config, don't silence the error.

### Testing config validation

```java
@SpringBootTest
@ActiveProfiles("test")
class JwtPropertiesValidationTest {

    @Autowired
    private JwtProperties jwtProperties;

    @Test
    void jwtPropertiesShouldBeValid() {
        assertThat(jwtProperties.secret()).isNotBlank();
        assertThat(jwtProperties.secret().length()).isGreaterThanOrEqualTo(32);
        assertThat(jwtProperties.expirationSeconds()).isGreaterThanOrEqualTo(60);
    }
}

// Test that invalid config fails startup
@SpringBootTest(properties = {
    "app.jwt.secret=short",
    "app.jwt.expiration-seconds=10"
})
class InvalidJwtPropertiesTest {

    @Test
    void invalidConfigShouldFailStartup() {
        // This test should NOT pass if validation is working correctly
        // The application should fail to start
        assertThrows(Exception.class, () -> {
            SpringApplication.run(MyApplication.class);
        });
    }
}
```

## Nested Property Validation

Use `@Valid` on nested config fields to cascade validation into inner config objects:

```java
@ConfigurationProperties(prefix = "app")
@Validated
public record AppProperties(
    @Valid @NotNull JwtProperties jwt,
    @Valid @NotNull CacheProperties cache,
    @Valid @NotNull SecurityProperties security
) {
    public record JwtProperties(
        @NotBlank @Size(min = 32, max = 512) String secret,
        @NotNull @Min(60) Long expirationSeconds,
        @NotBlank String issuer,
        @Valid @NotNull TokenProperties token
    ) {
        public record TokenProperties(
            @NotBlank String accessTokenHeader,
            @NotBlank String refreshTokenPath,
            @NotNull @Min(1) @Max(30) Integer refreshTokenExpirationDays
        ) {}
    }

    public record CacheProperties(
        @NotBlank String type,
        @NotNull @Min(1) Integer ttlSeconds,
        @Valid RedisProperties redis
    ) {
        public record RedisProperties(
            @NotBlank String host,
            @NotNull @Min(1) @Max(65535) Integer port,
            String password,
            @NotNull Duration timeout
        ) {}
    }

    public record SecurityProperties(
        @NotEmpty List<@NotBlank String> allowedOrigins,
        @NotEmpty List<@Valid EndpointConfig> publicEndpoints
    ) {
        public record EndpointConfig(
            @NotBlank @ValidEndpoint String path,
            @NotBlank String method
        ) {}
    }
}
```

> **Key rule**: Without `@Valid` on a nested field, Spring Boot does NOT validate the inner object. Always add `@Valid` when you want cascading validation.

### Nested validation failure example

```
Binding to target AppProperties failed:

    Property: app.jwt.token.refresh-token-expiration-days
    Value: 0
    Reason: must be at least 1

    Property: app.cache.redis.host
    Value: null
    Reason: must not be blank
```

The error message shows the full property path (`app.jwt.token.refresh-token-expiration-days`), making it easy to locate the invalid config in YAML.