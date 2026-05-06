# Code Generation Standards

## Comment Standards

Generated code comments should explain business meaning, not just repeat field names. Use single-line comments for fields and brief JavaDoc for classes/methods — no multi-paragraph docstrings.

### Class Comments

```java
/** User entity — maps to `user` table, stores registered user info */
@Data
@TableName("user")
public class UserDO { ... }
```

### Field Comments

```java
/** Unique username for login */
private String username;

/** Soft delete: NULL = active, now() = deleted timestamp */
@TableLogic(value = "", delval = "now()")
private LocalDateTime deletedAt;
```

### Method Comments

Only add comments when the WHY is non-obvious:

```java
/** Checks whether user can be deactivated — business rule: active subscriptions must be cancelled first */
public boolean canDeactivate() { ... }
```

## Code Generation Order

1. DO (Entity with MyBatis-Plus annotations) — base for all other objects
2. Mapper — data access interface
3. Service / ServiceImpl — business layer (MVC)
4. Gateway + GatewayImpl — persistence port and implementation (COLA)
5. Controller — API layer
6. DTO / VO / BO / Cmd — data transfer objects (if needed by architecture)
7. Converter — MapStruct mappers (COLA)

## Custom Method Generation

Generate method signatures with brief comments for non-obvious logic. Do not leave TODO placeholders or stub returns in generated code:

```java
/** Find active user by email — used for login lookup */
User findByEmail(String email);
```

## Annotations

- Use OpenAPI 3 annotations (`@Schema`, `@Tag`, `@Operation`) for API documentation
- Add `@NotNull` / `@NotBlank` where columns have NOT NULL constraints
- Use `@Valid` / `@Validated` on controller request parameters
- Use `@Transactional(rollbackFor = Exception.class)` on multi-step write methods
- Do not add `@Transactional(readOnly = true)` on pure query methods — auto-commit is sufficient for MyBatis

## References

- `template-variables.md` — Complete template variable list
- `ddd-cola` skill — COLA naming conventions and layer structure
- `spring-boot-openapi-documentation` skill — OpenAPI 3 annotation reference
- `mapstruct-patterns` skill — Converter patterns at layer boundaries