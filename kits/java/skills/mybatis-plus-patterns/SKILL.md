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

## Service Interface & Implementation (MVC Pattern)

```java
public interface UserService extends IService<UserDO> {
    UserDO findByEmail(String email);
}

@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {
    @Override
    @Transactional(readOnly = true)
    public UserDO findByEmail(String email) {
        return lambdaQuery().eq(UserDO::getEmail, email).one();
    }
}
```

**DDD/COLA projects** use the Gateway pattern instead — see `ddd-cola` skill for `OrderGateway` / `OrderGatewayImpl` pattern.

## Pagination Configuration

Since **3.5.9**, the pagination plugin requires a separate `mybatis-plus-jsqlparser` dependency:

```xml
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>mybatis-plus-jsqlparser</artifactId>
    <version>${mybatis-plus.version}</version>
</dependency>
```

```java
@Configuration
public class MybatisPlusConfig {
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.POSTGRE_SQL));
        return interceptor;
    }
}
```

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
- Update with version check: `UPDATE SET version = version + 1 WHERE id = ? AND version = ?`
- If affected rows = 0, throw concurrent modification error

## Query Wrapper

```java
LambdaQueryWrapper<UserDO> wrapper = new LambdaQueryWrapper<>();
wrapper.eq(UserDO::getStatus, UserStatus.ACTIVE)
       .like(UserDO::getUsername, keyword)
       .orderByDesc(UserDO::getCreatedAt);
Page<UserDO> result = userMapper.selectPage(page, wrapper);
```

## Best Practices

- **MVC**: Use `IService/ServiceImpl` pattern with `IService<DO>` / `ServiceImpl<Mapper, DO>`
- **DDD/COLA**: Use Gateway pattern — see `ddd-cola` skill
- Use `@Transactional(readOnly = true)` on all query methods → see `spring-boot-transaction-management`
- Use `LambdaQueryWrapper` instead of `QueryWrapper` for type safety
- Use `@TableLogic(value = "", delval = "now()")` with `deleted_at TIMESTAMPTZ` for soft deletes
- Use `@Version` for optimistic locking
- Use `Page<>` for pagination, never manually calculate offset
- Use `@Data + @EqualsAndHashCode(callSuper = false)` for DO classes
- Use `@TableName("xxx")` with plain snake_case — no `t_` prefix
- Use `@TableId(type = IdType.ASSIGN_ID)` — application-layer snowflake ID
- Use `DO` suffix for persistence objects, never `Entity` suffix
- Add detailed JavaDoc comments on classes, methods, and fields