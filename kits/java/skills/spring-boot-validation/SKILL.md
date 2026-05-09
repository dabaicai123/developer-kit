---
name: spring-boot-validation
description: "Jakarta Bean Validation (JSR-380) for Spring Boot 3.5.x with @Valid/@Validated, custom validators, validation groups, nested validation, @ConfigurationProperties validation, programmatic Validator, response DTO for validation errors, and anti-patterns. Use when implementing input validation for REST APIs or service methods."
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

Define constraints on request DTOs. Use Java records or Lombok `@Data` classes:

```java
public record CreateUserCmd(
    @NotBlank(message = "用户名不能为空")
    @Size(min = 3, max = 50, message = "用户名长度必须在3-50个字符之间")
    String username,

    @NotBlank(message = "邮箱不能为空")
    @Email(message = "邮箱格式不正确")
    String email,

    @NotNull(message = "年龄不能为空")
    @Min(value = 18, message = "年龄必须大于18岁")
    @Max(value = 120, message = "年龄不能超过120岁")
    Integer age,

    @Pattern(regexp = "^(?=.*[A-Z])(?=.*\\d).{8,}$",
             message = "密码必须8位以上且包含大写字母和数字")
    String password,

    @Valid @NotNull(message = "地址不能为空")
    AddressVO address,

    @Valid @Size(min = 1, message = "至少需要一个角色")
    List<@NotBlank String> roles
) {}
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

    /** Path parameter validation requires @Validated on the controller class */
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

Define domain-specific validation annotations for rules not covered by built-in constraints:

```java
/**
 * Custom phone number validation annotation.
 * <p>Follows the JSR-380 contract: message(), groups(), payload() are required.</p>
 */
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
public @interface ValidPhone {
    String message() default "Invalid phone number format";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

/**
 * ConstraintValidator implementation — null values are considered valid
 * (use @NotNull separately if null is not allowed).
 */
public class PhoneNumberValidator implements ConstraintValidator<ValidPhone, String> {
    @Override
    public boolean isValid(String value, ConstraintValidatorContext ctx) {
        // null is valid per JSR-380 spec — @NotNull handles null checks
        return value == null || value.matches("^\\+?[1-9]\\d{7,14}$");
    }
}
```

Custom validator with dependency injection (e.g., checking database uniqueness):

```java
/**
 * Custom validator that checks database uniqueness via injected service.
 * <p>Spring injects dependencies into ConstraintValidator implementations.</p>
 */
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = UniqueEmailValidator.class)
public @interface UniqueEmail {
    String message() default "Email already exists";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class UniqueEmailValidator implements ConstraintValidator<UniqueEmail, String> {
    private final UserRepository userRepository;

    public UniqueEmailValidator(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public boolean isValid(String email, ConstraintValidatorContext ctx) {
        if (email == null) return true;
        return !userRepository.existsByEmail(email);
    }
}
```

### 5. Apply validation groups for create vs update

Use validation groups to apply different constraint sets for different operations:

```java
/** Validation group interfaces — used as meta-annotations on constraints */
public interface OnCreate {}
public interface OnUpdate {}

public record UserCmd(
    @NotBlank(groups = OnCreate.class, message = "创建时用户名不能为空")
    @Size(min = 3, max = 50, groups = {OnCreate.class, OnUpdate.class},
          message = "用户名长度必须在3-50个字符之间")
    String username,

    @NotNull(groups = {OnCreate.class, OnUpdate.class}, message = "邮箱不能为空")
    @Email(groups = {OnCreate.class, OnUpdate.class}, message = "邮箱格式不正确")
    String email,

    @Null(groups = OnUpdate.class, message = "创建时 ID 必须为空")
    @NotNull(groups = OnCreate.class, message = "更新时 ID 不能为空")
    Long id
) {}

// Controller — use @Validated(Group.class) to activate specific groups
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
public record CreateUserCmd(
    @NotBlank String username,

    @Valid @NotNull(message = "地址不能为空")
    AddressVO address,

    @Valid @Size(min = 1, message = "至少需要一个电话号码")
    List<@ValidPhone String> phoneNumbers,

    @Valid @Size(max = 5, message = "最多允许 5 个偏好设置")
    Map<@NotBlank String, @NotBlank String> preferences
) {}

public record AddressVO(
    @NotBlank(message = "街道不能为空")
    String street,

    @NotBlank(message = "城市不能为空")
    String city,

    @NotBlank(message = "邮编不能为空")
    @Pattern(regexp = "^\\d{5,6}$", message = "邮编格式不正确")
    String zipCode
) {}
```

### 7. Validate @ConfigurationProperties at startup

Spring Boot can validate `@ConfigurationProperties` at startup, catching configuration errors early:

```java
@ConfigurationProperties(prefix = "app.mail")
@Validated
public record MailProperties(
    @NotBlank(message = "SMTP 主机不能为空")
    String host,

    @NotNull(message = "端口不能为空") @Min(value = 1, message = "端口必须大于 1") @Max(value = 65535, message = "端口不能超过 65535")
    Integer port,

    @NotBlank(message = "发件人地址不能为空")
    String fromAddress,

    @Duration(min = PT1S, max = PT30S)
    Duration timeout
) {}
```

Enable startup validation with:

```yaml
spring:
  configuration-properties:
    validate: true  # Default in Spring Boot 3.x
```

Or add `@EnableConfigurationProperties(MailProperties.class)` on a configuration class.

### 8. Programmatic validation with Validator

When validation cannot be declarative (e.g., validating objects created in service layer, conditional validation):

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final Validator validator;

    /**
     * Programmatic validation — useful when objects are constructed
     * dynamically and cannot use @Valid at controller boundary.
     */
    public void validateManually(OrderCommand command) {
        Set<ConstraintViolation<OrderCommand>> violations = validator.validate(command);
        if (!violations.isEmpty()) {
            String msg = violations.stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .collect(Collectors.joining("; "));
            throw new ValidationException(msg);
        }
    }

    /** Validate with specific groups */
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
validation.username.required=用户名不能为空
validation.username.size=用户名长度必须在{min}和{max}个字符之间
validation.email.format=邮箱格式不正确
validation.phone.format=手机号格式不正确
```

Reference message keys in annotations:

```java
public record CreateUserCmd(
    @NotBlank(message = "{validation.username.required}")
    @Size(min = 3, max = 50, message = "{validation.username.size}")
    String username,

    @NotBlank(message = "{validation.email.required}")
    @Email(message = "{validation.email.format}")
    String email
) {}
```

Spring Boot auto-detects `messages.properties` in the classpath root.

## Best Practices

- **Use `@Valid` for request body validation** (all constraints) and **`@Validated` for groups and path/query params** (method-level constraints)
- **Add `@Validated` on controller class** when using path/query parameter constraints — without it, they are silently ignored
- **Define validation messages in `messages.properties`** for i18n and centralization
- **Validate at controller boundary** — don't re-validate in service layer; validate DTOs at the controller, service methods receive pre-validated data
- **Use `@Validated` on `@Service` classes** only when method-level validation is needed (e.g., internal API contracts between services)
- **Custom validators must treat `null` as valid** — per JSR-380 spec, `@NotNull` handles null checks separately
- **Custom validators must include `message()`, `groups()`, `payload()`** — required by the JSR-380 contract
- **Use `@Valid` on nested fields** to cascade validation — without it, nested constraints are silently ignored
- **Keep validation annotations on DTOs, not entities** — entities may be constructed in contexts where validation should not apply
- **Use validation groups sparingly** — prefer separate DTOs for create vs update when the difference is significant

## Constraints and Warnings

**Anti-patterns**:

- **Manual if-checks for validation** — `if (username == null || username.isEmpty()) throw ...` is repetitive, untestable, and bypasses the validation framework. Use `@NotBlank` instead.
- **Re-validating in service layer after controller `@Valid`** — redundant and wasteful. Once validated at the controller boundary, the data is clean. Service layer should only validate business rules (not format/constraint checks).
- **Validating entities instead of DTOs** — entities are constructed in many contexts (mappers, tests, database reads) where validation constraints may not apply. Put constraints on request DTOs only.
- **Custom validators that return false for null** — violates JSR-380 spec. Use `@NotNull` for null checks, and let custom validators accept null as valid.
- **Missing `@Valid` on nested fields** — without `@Valid`, only `@NotNull` is checked on the nested field; constraints inside the nested object are silently skipped.
- **Missing `@Validated` on controller for path/query params** — `@Positive`, `@NotBlank`, `@Size` on `@PathVariable`/`@RequestParam` are silently ignored without `@Validated` on the controller class.
- **Validation groups for everything** — when create and update DTOs differ significantly, prefer separate DTOs (`CreateUserCmd` vs `UpdateUserCmd`) over a single DTO with groups. Groups add complexity and are easy to misapply.
- **Business rule validation in annotations** — annotations should validate format and constraints, not business rules (e.g., "order total must not exceed credit limit"). Business rules belong in the service layer.

**Technical constraints**:

- **`@Valid` vs `@Validated`**: `@Valid` is a JSR-380 standard annotation that validates all constraints (no group support). `@Validated` is a Spring extension that supports groups and method-level validation. Use `@Valid` for nested cascading; use `@Validated` for group-based or method-parameter validation.
- **Path/query parameter validation requires `@Validated` on controller class** — without it, constraints like `@Positive`, `@NotBlank` on `@PathVariable`/`@RequestParam` are silently ignored. This is a common source of validation gaps.
- **`@Valid` on nested fields is required for cascade** — without it, only the outer constraint (`@NotNull`) is checked; inner constraints are silently skipped.
- **Custom validators must treat null as valid per JSR-380 spec** — use `@NotNull` separately when null is not allowed.
- **Validation happens before `@Transactional`** — `MethodArgumentNotValidException` is thrown before the service method executes, so it never enters a transactional context. This is correct behavior.
- **`ConstraintViolationException` vs `MethodArgumentNotValidException`**: `@Valid` on `@RequestBody` produces `MethodArgumentNotValidException`; `@Validated` on method parameters produces `ConstraintViolationException`. The global exception handler must handle both.
- **`@ConfigurationProperties` validation errors cause startup failure** — this is intentional; invalid configuration should prevent the application from starting.

## References

- `spring-boot-exception-handling` — global handler that catches `MethodArgumentNotValidException` and `ConstraintViolationException`
- `spring-boot-rest-api-standards/references/unified-result-pattern.md` — `Result<T>` definition used in validation error responses
- Hibernate Validator reference: https://docs.jboss.org/hibernate/stable/validator/reference/en-US/html_single/

## Related Skills

- `spring-boot-exception-handling` — global handler catches `MethodArgumentNotValidException` and `ConstraintViolationException` from validation
- `spring-boot-rest-api-standards` — REST API design, DTO patterns, unified `Result<T>` response format
- `spring-boot-configuration-management` — `@ConfigurationProperties` with validation at startup
- `unit-test-bean-validation` — unit testing validation constraints and custom validators
- `unit-test-controller-layer` — integration testing `@Valid` behavior in controllers
- `ddd-cola` — DTO validation at the API gateway layer in COLA architecture

## Keywords

validation, @Valid, @Validated, JSR-380, Jakarta Bean Validation, Hibernate Validator, custom validator, validation groups, nested validation, @ConfigurationProperties, programmatic validation, ConstraintValidator, MethodArgumentNotValidException, ConstraintViolationException, i18n, messages.properties, DTO validation