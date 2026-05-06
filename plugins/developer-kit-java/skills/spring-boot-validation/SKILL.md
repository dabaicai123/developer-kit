---
name: spring-boot-validation
description: Bean Validation patterns for Spring Boot 3.5.x with @Valid, custom validators, and group validation. Use when implementing input validation for REST APIs.
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Validation

Input validation patterns for Spring Boot 3.5.x.

## When to use this skill

- Validating REST API request bodies and parameters
- Creating custom validation annotations
- Applying group-based validation

## Dependencies

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
```

## Request Validation

```java
public record CreateUserRequest(
    @NotBlank(message = "Username is required")
    @Size(min = 3, max = 50) String username,

    @NotBlank @Email String email,

    @NotNull @Min(18) @Max(120) Integer age,

    @Pattern(regexp = "^(?=.*[A-Z])(?=.*\\d).{8,}$",
             message = "Password must be 8+ chars with uppercase and digit")
    String password
) {}
```

## Controller Usage

```java
@PostMapping
public Result<Void> create(@Valid @RequestBody CreateUserRequest request) {
    userService.create(request);
    return Result.success();
}

@GetMapping("/{id}")
public Result<UserResponse> get(
        @PathVariable @Positive Long id) {
    return Result.success(userService.getById(id));
}
```

## Custom Validator

```java
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
public @interface ValidPhone {
    String message() default "Invalid phone number";
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

## Group Validation

```java
public interface OnCreate {}
public interface OnUpdate {}

public record UserRequest(
    @NotBlank(groups = OnCreate.class) String username,
    @NotNull(groups = {OnCreate.class, OnUpdate.class}) String email
) {}

@PostMapping
public Result<Void> create(
        @Validated(OnCreate.class) @RequestBody UserRequest request) { ... }

@PutMapping("/{id}")
public Result<Void> update(
        @PathVariable Long id,
        @Validated(OnUpdate.class) @RequestBody UserRequest request) { ... }
```

## Best Practices

- Use `@Valid` for nested objects, `@Validated` for groups
- Define validation messages in `messages.properties` for i18n
- Validate at controller boundary — don't re-validate in service layer
- Use `@Validated` on `@Service` classes for method-level validation
