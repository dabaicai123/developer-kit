---
name: mybatis-plus-patterns
description: "MyBatis-Plus for Spring Boot 3.5.x: mapper, data object (DO), service layer, pagination, soft delete, field fill, and optimistic lock. Use when building Java Spring Boot backend with MyBatis-Plus as ORM."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# MyBatis-Plus Patterns

MyBatis-Plus ORM patterns for Spring Boot 3.5.x with PostgreSQL.

## When to use this skill

- Manually writing or editing a single Mapper/DO/Service (not batch generation)
- Configuring MyBatis-Plus pagination, soft delete, field fill, optimistic lock
- Understanding data object annotations (@TableName, @TableId, @TableLogic, @Version)
- Setting up MyBatis-Plus interceptors
- Writing LambdaQueryWrapper queries

## When NOT to Use

- For batch code generation from database tables → use `mybatis-plus-generator`
- `mybatis-plus-generator` creates full CRUD scaffolding; this skill is for coding patterns when writing/editing individual modules

## Architecture Note

- **MVC projects**: Use `IService/ServiceImpl` pattern (see Service section below)
- **DDD/COLA projects**: Use Gateway pattern — domain port interface in domain layer, MyBatis-Plus implementation in infrastructure layer (see `ddd-cola` skill)

## Related Skills

- `spring-boot-transaction-management` — transaction boundaries with MyBatis-Plus IService/ServiceImpl
- `spring-boot-database-migration` — Flyway migrations for schema evolution
- `postgresql-table-design` — PostgreSQL data types, indexing, and constraints
- `mybatis-plus-generator` — batch code generation from database tables
- `ddd-cola` — COLA/DDD Gateway pattern for complex domains

## Mapper Pattern

```java
@Mapper
public interface UserMapper extends BaseMapper<UserDO> {
    @Select("SELECT * FROM user WHERE status = #{status} ORDER BY created_at DESC")
    List<UserDO> findActiveUsers(@Param("status") UserStatus status, Page<UserDO> page);
}
```

> **SQL Injection Prevention**: Always use `#{param}` (parameterized) in custom SQL — never `${param}` (raw string interpolation). `${param}` directly concatenates values into SQL, enabling injection attacks. Only use `${param}` for dynamic column names or table names where parameterization is impossible, and always validate the input before substitution.

## Data Object (DO) Definition

```java
@Data
@EqualsAndHashCode(callSuper = false)
@TableName("user")
public class UserDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    private String username;

    private String email;

    /** Exclude from SELECT queries (sensitive fields like password) */
    @TableField(select = false)
    private String password;

    /** Soft delete: NULL = active, now() = deleted timestamp */
    @TableLogic(value = "", delval = "now()")
    private LocalDateTime deletedAt;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableField(fill = FieldFill.INSERT)
    private Long createdBy;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private Long updatedBy;

    @Version
    private Integer version;
}
```

### @TableField Key Attributes

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `value` | Explicit column name mapping | `@TableField("nickname")` maps field `name` to column `nickname` |
| `exist` | `false` = non-database field (transient) | `@TableField(exist = false)` for computed fields |
| `select` | `false` = exclude from SELECT | `@TableField(select = false)` for password, sensitive data |
| `fill` | Auto-fill strategy | `@TableField(fill = FieldFill.INSERT)` |
| `updateStrategy` | When to include field in UPDATE SET | `@TableField(updateStrategy = FieldStrategy.NOT_NULL)` — only update if value is not null |
| `condition` | When to include field in WHERE | `@TableField(condition = FieldStrategy.NOT_EMPTY)` |

> **YAML**: Enable camelCase mapping with `mybatis-plus.configuration.map-underscore-to-camel-case: true`. Explicit `@TableField` mapping is only needed when the Java field name doesn't match the expected snake_case column.

> **mvnd + JDK 21 + Lombok**: If using mvnd with JDK 21, Lombok annotations (`@Data`, `@Builder`, `@Slf4j`) silently fail. Add `<forceLegacyJavacApi>true</forceLegacyJavacApi>` to `maven-compiler-plugin`. See `ddd-cola` skill for full configuration.

## IService Internal Transaction Behavior

`ServiceImpl` methods have different transaction defaults — understanding this is critical:

| Method | Built-in @Transactional? | Behavior |
|--------|--------------------------|----------|
| `save(T)` | **No** | Single INSERT, auto-commit |
| `updateById(T)` | **No** | Single UPDATE, auto-commit |
| `removeById(Serializable)` | **No** | Single UPDATE (soft delete) or DELETE, auto-commit |
| `getById(Serializable)` | **No** | Single SELECT, auto-commit |
| `saveBatch(Collection, int)` | **Yes** — `@Transactional(rollbackFor=Exception.class)` | Entire batch in one transaction |
| `saveOrUpdateBatch(Collection, int)` | **Yes** — `@Transactional(rollbackFor=Exception.class)` | Entire batch in one transaction |

**Implication**: If you call `save(entityA)` then `save(entityB)` in a custom method **without** `@Transactional`, each INSERT auto-commits independently — a failure on entityB will NOT roll back entityA. Always add `@Transactional(rollbackFor=Exception.class)` on your method when multiple DB operations must share one transaction.

> **saveBatch is NOT multi-row INSERT**: `saveBatch` loops through individual `INSERT` statements, not a single `INSERT INTO ... VALUES (...),(...),(...)`. For truly efficient bulk inserts, use a custom SQL injector method (e.g., `InsertAllBatch`) that generates multi-row SQL.

## Service Interface & Implementation (MVC Pattern)

```java
public interface UserService extends IService<UserDO> {
    UserDO findByEmail(String email);
}

@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {
    @Override
    public UserDO findByEmail(String email) {  // single SQL — no @Transactional needed
        return lambdaQuery().eq(UserDO::getEmail, email).one();
    }
}
```

**DDD/COLA projects** use the Gateway pattern instead — see `ddd-cola` skill for `OrderGateway` (with `save()` + `update()`) / `OrderGatewayImpl` (in `infrastructure/gatewayimpl/`) pattern.

## Pagination Configuration

Since **3.5.9**, the pagination plugin requires a separate `mybatis-plus-jsqlparser` dependency. For **Spring Boot 3.x**, use `mybatis-plus-spring-boot3-starter` (not the old `mybatis-plus-boot-starter`):

```xml
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
    <version>3.5.9</version>
</dependency>
<!-- Pagination plugin (required since 3.5.9) -->
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>mybatis-plus-jsqlparser</artifactId>
    <version>3.5.9</version>
</dependency>
```

```java
@Configuration
public class MybatisPlusConfig {
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.POSTGRE_SQL));
        interceptor.addInnerInterceptor(new OptimisticLockerInnerInterceptor()); // required for @Version!
        return interceptor;
    }
}
```

> **Important**: `OptimisticLockerInnerInterceptor` must be registered for `@Version` to work. Without it, optimistic lock checks are silently skipped — concurrent modifications will overwrite each other without detection.

## Field Fill (Auto-fill timestamps and audit fields)

```java
@Component
public class MybatisPlusMetaObjectHandler implements MetaObjectHandler {
    @Override
    public void insertFill(MetaObject metaObject) {
        this.strictInsertFill(metaObject, "createdAt", LocalDateTime.class, LocalDateTime.now());
        this.strictInsertFill(metaObject, "updatedAt", LocalDateTime.class, LocalDateTime.now());
        this.strictInsertFill(metaObject, "createdBy", Long.class, getCurrentUserId());
        this.strictInsertFill(metaObject, "updatedBy", Long.class, getCurrentUserId());
    }

    @Override
    public void updateFill(MetaObject metaObject) {
        this.strictUpdateFill(metaObject, "updatedAt", LocalDateTime.class, LocalDateTime.now());
        this.strictUpdateFill(metaObject, "updatedBy", Long.class, getCurrentUserId());
    }

    private Long getCurrentUserId() {
        // Extract from SecurityContext or request header
        return 0L; // placeholder
    }
}
```

## Soft Delete

- **SQL column**: `deleted_at TIMESTAMPTZ` (NULL = active, non-NULL = deleted timestamp)
- **Java field**: `@TableLogic(value = "", delval = "now()") private LocalDateTime deletedAt;`
- **YAML config**: `logic-delete-field: deletedAt`, `logic-delete-value: "now()"`, `logic-not-delete-value: ""`
- All SELECT queries automatically filter `WHERE deleted_at IS NULL` via MyBatis-Plus `@TableLogic`
- `deleteById` executes `UPDATE SET deleted_at = now()` instead of physical DELETE
- **Partial index** for active rows: `CREATE INDEX ON xxx (key) WHERE deleted_at IS NULL`
- **Never use** integer `deleted 0/1` or `@TableLogic` without `(value="", delval="now()")`

## Optimistic Lock

- **Java field**: `@Version private Integer version;`
- **SQL column**: `version INTEGER NOT NULL DEFAULT 1`
- **Interceptor**: must register `OptimisticLockerInnerInterceptor` in `MybatisPlusConfig` — without it, `@Version` is silently ignored
- Update with version check: `UPDATE SET version = version + 1 WHERE id = ? AND version = ?`
- If affected rows = 0, throw concurrent modification error

```java
@Override
@Transactional(rollbackFor = Exception.class)
public void updateOrder(OrderDO order) {
    boolean success = updateById(order);
    if (!success) {
        throw new ConcurrentModificationException(
            "Order " + order.getId() + " was modified by another transaction");
    }
}
```

## Query Wrapper

**Inside ServiceImpl** (preferred — use `lambdaQuery()` provided by `ServiceImpl`):

```java
@Override
@Transactional(readOnly = true)
public PageResult<UserVO> page(int pageNum, int pageSize, UserQueryBO query) {
    LambdaQueryWrapper<UserDO> wrapper = lambdaQuery()
        .like(StringUtils.isNotBlank(query.getUsername()), UserDO::getUsername, query.getUsername())
        .eq(query.getStatus() != null, UserDO::getStatus, query.getStatus())
        .orderByDesc(UserDO::getCreatedAt);
    Page<UserDO> mpPage = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
    return PageResult.of(mpPage).map(UserConverter::toVO);
}
```

**Outside ServiceImpl** (GatewayImpl, test, etc. — use `Wrappers` static factory):

```java
LambdaQueryWrapper<UserDO> wrapper = Wrappers.lambdaQuery(User.class)
    .eq(UserDO::getStatus, UserStatus.ACTIVE);
```

**Anti-patterns**:
- Never use raw `QueryWrapper` with string column names — use `LambdaQueryWrapper` for type safety
- Inside ServiceImpl, prefer `lambdaQuery()` over `new LambdaQueryWrapper<>` — shorter and less error-prone
- Never use `new LambdaQueryWrapper<>` in ServiceImpl when `lambdaQuery()` is available

## Multi-Table Join Queries

For type-safe multi-table joins, use the `mybatis-plus-join` library (`MPJLambdaWrapper`):

```xml
<dependency>
    <groupId>com.github.yulichang</groupId>
    <artifactId>mybatis-plus-join-boot-starter</artifactId>
    <version>1.4.13</version>
</dependency>
```

```java
// MPJLambdaWrapper for type-safe join queries
List<OrderVO> result = orderMapper.selectJoinList(OrderVO.class,
    new MPJLambdaWrapper<OrderDO>()
        .selectAll(OrderDO.class)
        .select(OrderItemDO::getProductName)
        .leftJoin(OrderItemDO.class, OrderItemDO::getOrderId, OrderDO::getId)
        .eq(OrderDO::getStatus, OrderStatus.COMPLETED));
```

> **Note**: Standard `LambdaQueryWrapper` does not support joins. For complex multi-table queries that `MPJLambdaWrapper` cannot express, use custom `@Select` SQL in Mapper interfaces.

## Best Practices

- **MVC**: Use `IService/ServiceImpl` pattern with `IService<DO>` / `ServiceImpl<Mapper, DO>`
- **DDD/COLA**: Use Gateway pattern — see `ddd-cola` skill
- **IService transaction behavior**: `saveBatch/saveOrUpdateBatch` have internal `@Transactional`; single methods (`save`, `updateById`, `removeById`) do NOT — add `@Transactional(rollbackFor=Exception.class)` on your method for multi-step writes
- Use `@Transactional(readOnly = true)` on multi-step query methods only (not single-statement queries) → see `spring-boot-transaction-management`
- Use `LambdaQueryWrapper` instead of `QueryWrapper` for type safety; inside ServiceImpl prefer `lambdaQuery()` over `new LambdaQueryWrapper<>`
- Use `#{param}` (parameterized) in custom SQL — never `${param}` (SQL injection risk)
- Use `@TableLogic(value = "", delval = "now()")` with `deleted_at TIMESTAMPTZ` for soft deletes
- Use `@Version` for optimistic locking — must register `OptimisticLockerInnerInterceptor`
- Use `Page<>` for pagination, never manually calculate offset
- Use `@Data + @EqualsAndHashCode(callSuper = false)` for DO classes
- Use `@TableName("xxx")` with plain snake_case — no `t_` prefix
- Use `@TableId(type = IdType.ASSIGN_ID)` — application-layer snowflake ID
- Use `DO` suffix for persistence objects, never `Entity` suffix
- Use `mybatis-plus-spring-boot3-starter` for Spring Boot 3.x (not old `mybatis-plus-boot-starter`)
- Use `mybatis-plus-join` (`MPJLambdaWrapper`) for type-safe multi-table joins
- Add detailed JavaDoc comments on classes, methods, and fields

## Keywords

mybatis-plus, ORM, mapper, DO, LambdaQueryWrapper, lambdaQuery, soft-delete, optimistic-lock, pagination, field-fill, MetaObjectHandler, saveBatch, IService, ServiceImpl, BaseMapper, @TableName, @TableId, @TableLogic, @Version, @TableField, spring-boot3-starter, MPJLambdaWrapper, mybatis-plus-join, Wrappers