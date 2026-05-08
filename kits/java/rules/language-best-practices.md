---
paths:
  - "**/*.java"
---

# Rule: Java Language Best Practices

Enforce Java best practices for Spring Boot + MyBatis-Plus projects. For detailed examples on specific topics, use the relevant skills.

## Guidelines

1. **Use constructor injection** for required dependencies. Use `@Autowired` only for optional dependencies. Never use field injection for required dependencies.

2. **Use `LambdaQueryWrapper`** for type-safe queries. Never use `QueryWrapper` with string column names. For patterns, see the `mybatis-plus-patterns` skill.

3. **Use `@Transactional(readOnly = true)`** for all query methods; `@Transactional(rollbackFor = Exception.class)` for writes. Keep transactions short — never hold locks during external calls. For details, see the `spring-boot-transaction-management` skill.

4. **Set expiration on cached data** — always use `expire` with JetCache `@Cached`. Never cache without expiration. For patterns, see the `spring-boot-jetcache` skill.

5. **Use `@TableLogic(value = "", delval = "now()")` timestamp-based soft delete** — `deleted_at TIMESTAMPTZ` (NULL = active, `now()` = deleted). Never use physical delete for business data, never use integer `deleted 0/1`. For patterns, see the `mybatis-plus-patterns` skill.

6. **Use unified `Result<T>` wrapper** for all API responses — `code/msg/data` format. Never return bare objects. For details, see the `spring-boot-rest-api-standards` skill.

7. **Use Java 21 features** when appropriate: `var` for obvious types, records for immutable DTOs/VOs, pattern matching for `instanceof`, switch expressions, sealed classes, text blocks for multi-line strings.

8. **Use `DO` suffix for persistence objects** — `UserDO`, `OrderDO`. Domain entities in DDD use bare names (`Order`). Never use `Entity` suffix for persistence objects.

9. **Add Javadoc to classes, public methods, and fields** — every class must have a one-line description of its responsibility. Every public method must explain WHAT it does. Every field in domain objects, DTOs, VOs, and DOs must have a Javadoc comment explaining its meaning — especially in DDD where field names alone may not convey business intent (e.g., `/** Order total amount including tax */ BigDecimal totalAmount`). Only write comments for WHY, not for obvious WHAT.

## Anti-Patterns

- `SELECT *` — always specify needed columns
- Catching generic `Exception` — use specific business exceptions
- `@Autowired` on fields for required deps — use constructor injection
- `QueryWrapper` with string names — use `LambdaQueryWrapper`
- Cache without `expire` — always set expiration
- Missing `@Transactional(readOnly = true)` on queries
- Bare objects in API responses — use `Result<T>` wrapper
- Integer soft delete (`deleted 0/1`) — use `deleted_at TIMESTAMPTZ` with `@TableLogic(value = "", delval = "now()")`
- `Entity` suffix for persistence objects — use `DO` suffix
- Table name prefix (`t_xxx`) — use plain snake_case (`xxx`)
- Classes, methods, or fields without Javadoc — always document responsibility and meaning
- Comments that repeat the code (`// set the name`) — write WHY, not WHAT