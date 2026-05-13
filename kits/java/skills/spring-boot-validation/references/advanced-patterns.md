# Spring Boot Validation — Advanced Patterns

Detailed implementation examples for patterns referenced in the main SKILL.md.

## Custom Validators

Define domain-specific validation annotations. Must include `message()`, `groups()`, `payload()` per JSR-380. Null is valid per JSR-380 — use `@NotNull` separately.

### Basic custom validator

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

### Custom validator with dependency injection

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

## Validation Groups

Use validation groups to apply different constraint sets for create vs update operations.

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

## Nested Object and Collection Validation

Use `@Valid` on nested fields to cascade validation into embedded objects and collections.

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

## @ConfigurationProperties Validation

Spring Boot validates `@ConfigurationProperties` at startup when `@Validated` is present, catching configuration errors early.

```java
@ConfigurationProperties(prefix = "app.mail")
@Validated
public record MailProperties(
    @NotBlank(message = "SMTP host must not be blank")
    String host,

    @NotNull(message = "Port must not be null")
    @Min(value = 1, message = "Port must be at least 1")
    @Max(value = 65535, message = "Port must not exceed 65535")
    Integer port,

    @NotBlank(message = "Sender address must not be blank")
    String fromAddress,

    @DurationMin(seconds = 1, message = "Timeout must be at least 1 second")
    @DurationMax(seconds = 30, message = "Timeout must not exceed 30 seconds")
    Duration timeout
) {}
```

No additional YAML configuration needed — `@Validated` on the class triggers validation at startup.

## Programmatic Validation with Validator

When validation cannot be declarative (e.g., objects constructed dynamically in service layer), inject `Validator` directly.

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final Validator validator;

    public void validateManually(OrderCommand command) {
        Set<ConstraintViolation<OrderCommand>> violations = validator.validate(command);
        if (!violations.isEmpty()) {
            String msg = violations.stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .collect(Collectors.joining("; "));
            throw new ValidationException(msg);
        }
    }

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

Spring Boot auto-configures the `Validator` bean from `spring-boot-starter-validation`.

## i18n Message Externalization

Move validation messages to `messages.properties` for internationalization and centralization.

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
