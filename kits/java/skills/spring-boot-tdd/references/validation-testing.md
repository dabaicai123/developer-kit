# Bean Validation Unit Testing Reference

Unit testing for Jakarta Bean Validation (JSR-380) constraints using JUnit 5 and Hibernate Validator 8, without Spring container.

## Dependency Configuration

`spring-boot-starter-validation` (Spring Boot 3.5.x) provides `jakarta.validation-api` and `hibernate-validator` — version managed by Spring Boot BOM.

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
<dependency>
  <groupId>org.assertj</groupId>
  <artifactId>assertj-core</artifactId>
  <scope>test</scope>
</dependency>
```

For projects NOT using the starter, declare individually:

```xml
<dependency>
  <groupId>jakarta.validation</groupId>
  <artifactId>jakarta.validation-api</artifactId>
</dependency>
<dependency>
  <groupId>org.hibernate.validator</groupId>
  <artifactId>hibernate-validator</artifactId>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.assertj</groupId>
  <artifactId>assertj-core</artifactId>
  <scope>test</scope>
</dependency>
```

NOT use `javax.validation` — Spring Boot 3.5.x uses Jakarta EE 10 (`jakarta.validation`). The `javax` namespace is for Spring Boot 2.x only.

## Basic Test Setup

```java
import jakarta.validation.*;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.path.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class BaseValidationTest {
  protected Validator validator;

  @BeforeEach
  void setUpValidator() {
    validator = Validation.buildDefaultValidatorFactory().getValidator();
  }
}
```

`Validator` is thread-safe — share across tests.

## Built-in Constraint Testing

```java
class UserDTOTest extends BaseValidationTest {

  @Test
  void shouldPassValidationWithValidUser() {
    UserDTO user = new UserDTO("Alice", "alice@example.com", 25);
    assertThat(validator.validate(user)).isEmpty();
  }

  @Test
  void shouldFailWhenNameIsNull() {
    UserDTO user = new UserDTO(null, "alice@example.com", 25);
    assertThat(validator.validate(user))
      .extracting(ConstraintViolation::getMessage)
      .contains("Username must not be empty");
  }

  @Test
  void shouldFailWhenEmailIsInvalid() {
    UserDTO user = new UserDTO("Alice", "invalid-email", 25);
    Set<ConstraintViolation<UserDTO>> violations = validator.validate(user);
    assertThat(violations)
      .extracting(ConstraintViolation::getPropertyPath)
      .extracting(Path::toString)
      .contains("email");
  }

  @Test
  void shouldFailWhenMultipleConstraintsViolated() {
    UserDTO user = new UserDTO(null, "invalid", -5);
    assertThat(validator.validate(user)).hasSize(3);
  }
}
```

## COLA Naming Conventions

- **Cmd Objects**: `CreateUserCmd`, `UpdateUserCmd` — ServiceI input parameters, require validation
- **DTO**: Data objects returned to adapter.web layer — validate as needed
- **Messages**: Use localized constraint messages via `MessageSource` i18n

## Custom Validator Testing

### Annotation and Implementation

```java
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
public @interface ValidPhoneNumber {
  String message() default "Invalid phone number format";
  Class<?>[] groups() default {};
  Class<? extends Payload>[] payload() default {};
}

public class PhoneNumberValidator implements ConstraintValidator<ValidPhoneNumber, String> {
  private static final String PHONE_PATTERN = "^\\d{3}-\\d{3}-\\d{4}$";

  @Override
  public boolean isValid(String value, ConstraintValidatorContext context) {
    if (value == null) return true; // null handled by @NotNull
    return value.matches(PHONE_PATTERN);
  }
}
```

### Unit Testing

```java
class PhoneNumberValidatorTest extends BaseValidationTest {

  @Test
  void shouldAcceptValidPhoneNumber() {
    Contact contact = new Contact("Alice", "555-123-4567");
    assertThat(validator.validate(contact)).isEmpty();
  }

  @Test
  void shouldRejectInvalidFormat() {
    Contact contact = new Contact("Alice", "5551234567");
    assertThat(validator.validate(contact))
      .extracting(ConstraintViolation::getMessage)
      .contains("Invalid phone number format");
  }

  @Test
  void shouldAllowNull() {
    Contact contact = new Contact("Alice", null);
    assertThat(validator.validate(contact)).isEmpty();
  }
}
```

## Cross-Field Validation

```java
@PasswordsMatch
public class ChangePasswordCmd {
  private String newPassword;
  private String confirmPassword;
}

@Constraint(validatedBy = PasswordMatchValidator.class)
public @interface PasswordsMatch {
  String message() default "Passwords do not match";
  Class<?>[] groups() default {};
}

public class PasswordMatchValidator
    implements ConstraintValidator<PasswordsMatch, ChangePasswordCmd> {
  @Override
  public boolean isValid(ChangePasswordCmd value, ConstraintValidatorContext context) {
    if (value == null) return true;
    return value.getNewPassword().equals(value.getConfirmPassword());
  }
}

class PasswordValidationTest extends BaseValidationTest {

  @Test
  void shouldPassWhenPasswordsMatch() {
    var cmd = new ChangePasswordCmd("pass123", "pass123");
    assertThat(validator.validate(cmd)).isEmpty();
  }

  @Test
  void shouldFailWhenPasswordsDoNotMatch() {
    var cmd = new ChangePasswordCmd("pass123", "different");
    assertThat(validator.validate(cmd))
      .extracting(ConstraintViolation::getMessage)
      .contains("Passwords do not match");
  }
}
```

## Validation Groups

```java
public interface CreateValidation {}
public interface UpdateValidation {}

class UserCmd {
  @NotNull(groups = CreateValidation.class)
  private String name;

  @Min(value = 0, groups = {CreateValidation.class, UpdateValidation.class})
  private int age;
}
```

### Testing Groups

```java
class ValidationGroupsTest extends BaseValidationTest {

  @Test
  void shouldRequireNameOnlyDuringCreation() {
    UserCmd cmd = new UserCmd(null, 25);
    Set<ConstraintViolation<UserCmd>> violations =
        validator.validate(cmd, CreateValidation.class);

    assertThat(violations)
      .extracting(ConstraintViolation::getPropertyPath)
      .extracting(Path::toString)
      .contains("name");
  }

  @Test
  void shouldAllowNullNameDuringUpdate() {
    UserCmd cmd = new UserCmd(null, 25);
    assertThat(validator.validate(cmd, UpdateValidation.class)).isEmpty();
  }
}
```

## Parameterized Testing

```java
class EmailValidationTest extends BaseValidationTest {

  @ParameterizedTest
  @ValueSource(strings = {
    "user@example.com",
    "john.doe+tag@example.co.uk",
    "admin@subdomain.example.com"
  })
  void shouldAcceptValidEmails(String email) {
    UserCmd cmd = new UserCmd("Alice", email);
    assertThat(validator.validate(cmd)).isEmpty();
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "invalid-email", "user@", "@example.com", "user name@example.com"
  })
  void shouldRejectInvalidEmails(String email) {
    UserCmd cmd = new UserCmd("Alice", email);
    assertThat(validator.validate(cmd)).isNotEmpty();
  }
}
```

## Anti-patterns

- NOT only check violation count — verify property path and message for each violation
- NOT assume constraints reject null — most constraints ignore null by default. For required fields, add `@NotNull`
- NOT maintain instance state in custom validators — validators must be stateless
- NOT place `@Constraint(validatedBy=)` on getters instead of fields — annotation target must match element type
- NOT skip testing `@Valid` cascading on nested objects — verify violations propagate to sub-fields
- NOT use `System.out.println` for debugging violations — use `assertThat(violations).hasSize(n)` + `extracting(ConstraintViolation::getMessage)` for deterministic assertions

## Troubleshooting Guide

| Issue | Cause | Solution |
|------|------|----------|
| violation count is 0 | object is valid or constraint not triggered | check annotation parameters |
| property path incorrect | annotation on getter instead of field | confirm `@Constraint(validatedBy=)` targets the field |
| null passes validation | constraints ignore null by default | add `@NotNull` |
| violation count exceeds expected | multiple constraints fail simultaneously | use `hasSize()` to confirm exact count |
| ValidatorFactory not found | missing dependency | ensure `jakarta.validation-api` and `hibernate-validator` on test classpath |

## Constraints

- Most constraints ignore null — combine `@NotNull` for required fields
- `Validator` is thread-safe, can be shared
- `@Valid` cascading triggers recursive validation on nested objects
- Custom validators must be stateless and return `true` for `null`
- Validation unit tests must NOT depend on Spring container or database