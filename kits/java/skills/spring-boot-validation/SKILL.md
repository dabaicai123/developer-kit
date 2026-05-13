---
name: spring-boot-validation
description: "Jakarta Bean Validation (JSR-380) with @Valid/@Validated, custom validators, validation groups, nested validation, @ConfigurationProperties validation, programmatic Validator, response DTO for validation errors, and anti-patterns. Use when implementing input validation for REST APIs or service methods."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Validation

Jakarta Bean Validation (JSR-380) patterns for Spring Boot 3.5.x.

## When to use this skill

- Validating REST API request bodies and parameters with `@Valid` / `@Validated`
- Creating custom validation annotations for domain-specific rules
- Applying group-based validation for create vs update scenarios
- Validating nested objects and collections
- Validating `@ConfigurationProperties` at startup
- Programmatically invoking validation in service or utility code
- Designing response DTOs that carry field-level validation error detail
- Avoiding common validation anti-patterns (manual if-checks, validation in service layer)

## Instructions

### 1. Add validation dependency

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
```

This brings in Hibernate Validator (JSR-380 provider). No additional configuration is needed — Spring Boot auto-configures the `Validator` bean.

### 2. Validate request body with @Valid

Define constraints on request DTOs:

```java
@Data
public class CreateUserCmd extends Command {

    @NotBlank(message = "Username must not be blank")
    @Size(min = 3, max = 50, message = "Username must be between 3 and 50 characters")
    private String username;

    @NotBlank(message = "Email must not be blank")
    @Email(message = "Invalid email format")
    private String email;

    @NotNull(message = "Age must not be null")
    @Min(value = 18, message = "Age must be at least 18")
    @Max(value = 120, message = "Age must not exceed 120")
    private Integer age;

    @Pattern(regexp = "^(?=.*[A-Z])(?=.*\\d).{8,}$",
             message = "Password must be at least 8 characters with uppercase and digit")
    private String password;

    @Valid @NotNull(message = "Address must not be null")
    private AddressVO address;

    @Valid @Size(min = 1, message = "At least one role is required")
    private List<@NotBlank String> roles;
}
```

Apply `@Valid` in the controller:

```java
@RestController
@RequestMapping("/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserServiceI userServiceI;

    @PostMapping
    public Result<Void> create(@Valid @RequestBody CreateUserCmd request) {
        userServiceI.create(request);
        return Result.success();
    }

    /** Path/query params require @Validated on the controller class */
    @GetMapping("/{id}")
    public Result<UserResponse> get(@PathVariable @Positive Long id) {
        return Result.success(userServiceI.getById(id));
    }
}
```

### 3. Enable path/query parameter validation with @Validated

Path and query parameter constraints (`@Positive`, `@NotBlank`, `@Size`, etc.) require `@Validated` on the **controller class** — they are not triggered by `@Valid` alone:

```java
@RestController
@RequestMapping("/v1/users")
@Validated  // Required for path/query parameter constraint validation
@RequiredArgsConstructor
public class UserController {

    @GetMapping("/{id}")
    public Result<UserResponse> get(@PathVariable @Positive Long id) {
        return Result.success(userServiceI.getById(id));
    }

    @GetMapping
    public Result<PageResult<UserResponse>> search(
            @RequestParam @NotBlank @Size(max = 50) String keyword,
            @RequestParam(defaultValue = "1") @Positive int page,
            @RequestParam(defaultValue = "10") @Positive int pageSize) {
        return Result.success(userServiceI.search(keyword, page, pageSize));
    }
}
```

### 4. Create custom validators

Define domain-specific validation annotations (must include `message()`, `groups()`, `payload()` per JSR-380). Null is valid per JSR-380 — use `@NotNull` separately:

```java
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
public @interface ValidPhone {
    String message() default "Invalid phone number format";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class PhoneNumberValidator implements ConstraintValidator<ValidPhone, String> {
    @Override
    public boolean isValid(String value, ConstraintValidatorContext ctx) {
        return value == null || value.matches("^\\+?[1-9]\\d{7,14}$");
    }
}
```

Custom validator with dependency injection:

```java
@Constraint(validatedBy = UniqueEmailValidator.class)
public @interface UniqueEmail {
    String message() default "Email already exists";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class UniqueEmailValidator implements ConstraintValidator<UniqueEmail, String> {
    private final UserRepository userRepository;

    @Override
    public boolean isValid(String email, ConstraintValidatorContext ctx) {
        return email == null || !userRepository.existsByEmail(email);
    }
}
```

### 5. Apply validation groups for create vs update

Use validation groups to apply different constraint sets for different operations:

```java
// Validation group interfaces
public interface OnCreate {}
public interface OnUpdate {}

@Data
public class UserCmd extends Command {

    @NotBlank(groups = OnCreate.class, message = "Username is required on creation")
    @Size(min = 3, max = 50, groups = {OnCreate.class, OnUpdate.class},
          message = "Username must be between 3 and 50 characters")
    private String username;

    @NotNull(groups = {OnCreate.class, OnUpdate.class}, message = "Email must not be blank")
    @Email(groups = {OnCreate.class, OnUpdate.class}, message = "Invalid email format")
    private String email;

    @Null(groups = OnCreate.class, message = "ID must be null on creation")
    @NotNull(groups = OnUpdate.class, message = "ID is required on update")
    private Long id;
}

// Use @Validated(Group.class) to activate specific groups
@RestController
@RequestMapping("/v1/users")
@RequiredArgsConstructor
public class UserController {

    @PostMapping
    public Result<Void> create(
            @Validated(OnCreate.class) @RequestBody UserCmd request) {
        userServiceI.create(request);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(
            @PathVariable Long id,
            @Validated(OnUpdate.class) @RequestBody UserCmd request) {
        userServiceI.update(id, request);
        return Result.success();
    }
}
```

### 6. Validate nested objects and collections

Use `@Valid` on nested fields to cascade validation into embedded objects and collections:

```java
@Data
public class CreateUserCmd extends Command {

    @NotBlank private String username;

    @Valid @NotNull(message = "Address must not be null")
    private AddressVO address;

    @Valid @Size(min = 1, message = "At least one phone number is required")
    private List<@ValidPhone String> phoneNumbers;

    @Valid @Size(max = 5, message = "Maximum 5 preferences allowed")
    private Map<@NotBlank String, @NotBlank String> preferences;
}

public record AddressVO(
    @NotBlank(message = "Street must not be blank")
    String street,

    @NotBlank(message = "City must not be blank")
    String city,

    @NotBlank(message = "Zip code must not be blank")
    @Pattern(regexp = "^\\d{5,6}$", message = "Invalid zip code format")
    String zipCode
) {}
```

### 7. Validate @ConfigurationProperties at startup

Spring Boot can validate `@ConfigurationProperties` at startup, catching configuration errors early:

```java
@ConfigurationProperties(prefix = "app.mail")
@Validated
public record MailProperties(
    @NotBlank(message = "SMTP host must not be blank")
    String host,

    @NotNull(message = "Port must not be null") @Min(value = 1, message = "Port must be at least 1") @Max(value = 65535, message = "Port must not exceed 65535")
    Integer port,

    @NotBlank(message = "Sender address must not be blank")
    String fromAddress,

    @DurationMin(seconds = 1, message = "Timeout must be at least 1 second")
    @DurationMax(seconds = 30, message = "Timeout must not exceed 30 seconds")
    Duration timeout
) {}
```

`@Validated` on the class triggers validation at startup. No additional YAML configuration is needed.

### 8. Programmatic validation with Validator

When validation cannot be declarative (e.g., objects constructed dynamically in service layer):

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final Validator validator;

    // Programmatic validation for dynamically constructed objects
    public void validateManually(OrderCommand command) {
        Set<ConstraintViolation<OrderCommand>> violations = validator.validate(command);
        if (!violations.isEmpty()) {
            String msg = violations.stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .collect(Collectors.joining("; "));
            throw new ValidationException(msg);
        }
    }

    // Validate with specific groups
    public void validateWithGroups(OrderCommand command, Class<?>... groups) {
        Set<ConstraintViolation<OrderCommand>> violations = validator.validate(command, groups);
        if (!violations.isEmpty()) {
            String msg = violations.stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .collect(Collectors.joining("; "));
            throw new ValidationException(msg);
        }
    }
}
```

Inject `Validator` via constructor — Spring Boot auto-configures it from `spring-boot-starter-validation`.

### 9. Define i18n validation messages

Move validation messages to `messages.properties` for internationalization and centralization:

```properties
# src/main/resources/messages.properties
validation.username.required=Username must not be blank
validation.username.size=Username must be between {min} and {max} characters
validation.email.format=Invalid email format
validation.phone.format=Invalid phone number format
```

Reference message keys in annotations:

```java
@Data
public class CreateUserCmd extends Command {

    @NotBlank(message = "{validation.username.required}")
    @Size(min = 3, max = 50, message = "{validation.username.size}")
    private String username;

    @NotBlank(message = "{validation.email.required}")
    @Email(message = "{validation.email.format}")
    private String email;
}
```

Spring Boot auto-detects `messages.properties` in the classpath root.

## Constraints and Warnings

- `@Valid` on `@RequestBody`; `@Validated` for groups and path/query params
- `@Validated` on controller class required for path/query param constraints
- `@Valid` on nested fields to cascade validation — omitting silently skips inner constraints
- Custom validators: null is valid per JSR-380; include `message()`, `groups()`, `payload()`
- Constraints on DTOs, not entities — entities are constructed in mappers/tests/DB reads where constraints may not apply
- No manual if-checks — use `@NotBlank`, `@NotNull` etc. instead
- No re-validation in service layer after controller `@Valid` — format checks are redundant at boundary
- No business rules in annotations — format/constraint checks only; business rules belong in service layer
- `@Valid` (JSR-380) validates all constraints, no group support; `@Validated` (Spring) supports groups and method-level validation
- `MethodArgumentNotValidException` from `@Valid` on `@RequestBody`; `ConstraintViolationException` from `@Validated` on method params
- Validation happens before `@Transactional` — `MethodArgumentNotValidException` never enters transactional context

## Related Skills

- `spring-boot-exception-handling` — handles `MethodArgumentNotValidException` and `ConstraintViolationException`
- `spring-boot-rest-api-standards` — DTO patterns, unified `Result<T>` response
- `spring-boot-configuration-management` — `@ConfigurationProperties` with validation

## Keywords

validation, @Valid, @Validated, JSR-380, Jakarta Bean Validation, Hibernate Validator, custom validator, validation groups, nested validation, @ConfigurationProperties, programmatic validation, ConstraintValidator, MethodArgumentNotValidException, ConstraintViolationException, i18n, messages.properties, DTO validation