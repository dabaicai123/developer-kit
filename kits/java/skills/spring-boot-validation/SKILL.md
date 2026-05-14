---
name: spring-boot-validation
description: "Applies Jakarta Bean Validation for Spring Boot, including @Valid vs @Validated, constraint placement, groups, and validation anti-patterns. Use when validating request DTOs, method parameters, or domain inputs."
version: "1.1.0"
---

# Spring Boot Validation

Jakarta Bean Validation decision guide for Spring Boot.

## When to use this skill

- Validating REST API request bodies and parameters
- Deciding between `@Valid` and `@Validated`
- Placing constraints correctly (DTOs vs entities, controller vs service)
- Avoiding common validation anti-patterns

## Instructions

### Dependency

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
```

Spring Boot auto-configures the `Validator` bean. No additional setup needed.

### @Valid vs @Validated — Decision Matrix

| Scenario | Annotation | Where |
|----------|-----------|-------|
| Request body validation | `@Valid` | On `@RequestBody` parameter |
| Path/query param constraints | `@Validated` | On controller **class** |
| Validation groups (create/update) | `@Validated(Group.class)` | On `@RequestBody` parameter |
| Nested object cascade | `@Valid` | On the nested field in DTO |
| ConfigurationProperties | `@Validated` | On the properties class |
| Programmatic validation | Inject `Validator` | In service layer |

### Core Pattern — Request Body

```java
@Data
public class CreateUserCmd extends Command {

    @NotBlank @Size(min = 3, max = 50)
    private String username;

    @NotBlank @Email
    private String email;

    @NotNull @Min(18) @Max(120)
    private Integer age;

    @Valid @NotNull
    private AddressVO address;
}
```

```java
@PostMapping
public Result<Void> create(@Valid @RequestBody CreateUserCmd request) {
    userServiceI.create(request);
    return Result.success();
}
```

### Core Pattern — Path/Query Params

`@Validated` on the controller class is required — `@Valid` alone does not trigger param constraints:

```java
@RestController
@RequestMapping("/v1/users")
@Validated  // Required for path/query param validation
public class UserController {

    @GetMapping("/{id}")
    public Result<UserResponse> get(@PathVariable @Positive Long id) { ... }

    @GetMapping
    public Result<PageResult<UserResponse>> search(
            @RequestParam @NotBlank @Size(max = 50) String keyword,
            @RequestParam(defaultValue = "1") @Positive int page) { ... }
}
```

### Common Annotations Quick Reference

| Annotation | Applies to | Notes |
|-----------|-----------|-------|
| `@NotNull` | Any type | Rejects null only |
| `@NotBlank` | String | Rejects null, empty, whitespace-only |
| `@NotEmpty` | String/Collection/Map | Rejects null and empty |
| `@Size(min, max)` | String/Collection/Map | Length/size bounds |
| `@Min` / `@Max` | Numeric | Value bounds |
| `@Positive` / `@Negative` | Numeric | Sign constraints |
| `@Email` | String | RFC format check |
| `@Pattern(regexp)` | String | Regex match |
| `@Valid` | Object/Collection field | Cascades validation into nested |
| `@Past` / `@Future` | Temporal | Date/time bounds |

## Constraints and Warnings

- `@Valid` on nested fields to cascade — omitting silently skips inner constraints
- Custom validators: null is valid per JSR-380; combine with `@NotNull` separately
- Constraints on DTOs, not entities — entities are constructed in mappers/tests/DB reads
- No manual if-checks — use constraint annotations instead
- No re-validation in service layer — format checks at controller boundary are sufficient
- No business rules in annotations — format/constraint checks only; business rules belong in service layer
- `MethodArgumentNotValidException` from `@Valid` on `@RequestBody`; `ConstraintViolationException` from `@Validated` on method params
- Validation happens before `@Transactional` — exceptions never enter transactional context

## Advanced Patterns

See `references/advanced-patterns.md` for:
- Custom validators (annotation + ConstraintValidator)
- Validation groups (create vs update)
- Nested object and collection validation
- @ConfigurationProperties validation
- Programmatic Validator usage
- i18n message externalization

## Related Skills

- `spring-boot-exception-handling`
- `spring-boot-rest-api-standards`
- `spring-boot-configuration-management`
