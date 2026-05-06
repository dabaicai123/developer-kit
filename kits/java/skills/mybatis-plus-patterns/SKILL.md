---
name: mybatis-plus-patterns
description: "MyBatis-Plus: mapper, data object (DO), service layer, pagination, soft delete, field fill, and optimistic lock. Use when building Java Spring Boot backend with MyBatis-Plus as ORM."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# MyBatis-Plus Patterns

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
| `whereStrategy` | When to include field in WHERE | `@TableField(whereStrategy = FieldStrategy.NOT_EMPTY)` |

> **YAML**: Enable camelCase mapping with `mybatis-plus.configuration.map-underscore-to-camel-case: true`. Explicit `@TableField` mapping is only needed when the Java field name doesn't match the expected snake_case column.

> **mvnd + JDK 21 + Lombok**: If using mvnd with JDK 21, Lombok silently fails. See `ddd-cola` for the `<forceLegacyJavacApi>` fix.

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

**DDD/COLA projects** use the Gateway pattern instead — see `ddd-cola` skill for `OrderGateway` (with `save()` + `update()`) / `OrderGatewayImpl` (in `infrastructure/customer/` — flat per-domain package) pattern.

## Pagination Configuration

Since **3.5.9**, the pagination plugin requires a separate `mybatis-plus-jsqlparser` dependency. For **Spring Boot 3.x**, use `mybatis-plus-spring-boot3-starter` (not the old `mybatis-plus-boot-starter`):

Add `mybatis-plus-spring-boot3-starter` 3.5.9 and `mybatis-plus-jsqlparser` 3.5.9. See `ddd-cola` or `mybatis-plus-generator` for full dependency blocks.

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
LambdaQueryWrapper<UserDO> wrapper = Wrappers.lambdaQuery()
    .eq(UserDO::getStatus, UserStatus.ACTIVE);
```

**Anti-patterns**:
- Never use raw `QueryWrapper` with string column names — use `LambdaQueryWrapper` for type safety
- Inside ServiceImpl, prefer `lambdaQuery()` over `new LambdaQueryWrapper<>` — shorter and less error-prone
- Never use `new LambdaQueryWrapper<>` in ServiceImpl when `lambdaQuery()` is available

## Multi-Table Join Queries

**Prefer single-table queries** — design your schema and service layer to minimize joins. When joins are necessary, limit to **no more than 3 tables**. Beyond 3 tables, query planning complexity increases, indexes become less effective, and maintenance burden grows. For complex cross-domain data needs, query separately and assemble in application code, or use a read-optimized view/materialized table.

For multi-table queries, write raw SQL in **Mapper XML** files. XML gives full control over JOIN logic, column selection, and result mapping, without coupling to a third-party wrapper library.

```xml
<!-- resources/mapper/OrderMapper.xml -->
<select id="findOrderWithItems" resultMap="orderWithItemsResultMap">
    SELECT o.id, o.status, o.total_amount,
           i.product_name, i.quantity, i.unit_price
    FROM order o
    LEFT JOIN order_item i ON i.order_id = o.id
    WHERE o.status = #{status} AND o.deleted_at IS NULL
</select>

<resultMap id="orderWithItemsResultMap" type="OrderVO">
    <id column="id" property="id"/>
    <result column="status" property="status"/>
    <result column="total_amount" property="totalAmount"/>
    <collection property="items" ofType="OrderItemVO">
        <result column="product_name" property="productName"/>
        <result column="quantity" property="quantity"/>
        <result column="unit_price" property="unitPrice"/>
    </collection>
</resultMap>
```

```java
@Mapper
public interface OrderMapper extends BaseMapper<OrderDO> {
    List<OrderVO> findOrderWithItems(@Param("status") OrderStatus status);
}
```

> **SQL Injection Prevention**: Always use `#{param}` in XML — never `${param}` for values. `${param}` is only acceptable for dynamic column/table names where parameterization is impossible, with input validation.

> **Note**: Standard `LambdaQueryWrapper` does not support joins. For single-table queries, prefer `LambdaQueryWrapper` or `lambdaQuery()`. For multi-table joins, use Mapper XML.

## Batch Operations — Never Loop Individual DB Calls

Replace `for` loops with individual `insert/select/update/delete` with MyBatis-Plus batch methods or `IN` clause queries. Looping individual DB calls causes N+1 roundtrips and is a critical performance anti-pattern.

### Batch INSERT — saveBatch instead of for-loop insert

```java
// ❌ WRONG: for-loop insert — N roundtrips, no transaction wrapping
@Override
public void bindAdPlans(Long strategyId, List<Long> adPlanIds) {
    for (Long adPlanId : adPlanIds) {
        StrategyAdPlanDO junction = new StrategyAdPlanDO();
        junction.setStrategyId(strategyId);
        junction.setAdPlanId(adPlanId);
        strategyAdPlanMapper.insert(junction);  // N individual INSERTs
    }
}

// ✅ CORRECT: saveBatch — single transaction, reduced roundtrips
@Override
@Transactional(rollbackFor = Exception.class)
public void bindAdPlans(Long strategyId, List<Long> adPlanIds) {
    List<StrategyAdPlanDO> junctions = adPlanIds.stream()
        .map(adPlanId -> {
            StrategyAdPlanDO junction = new StrategyAdPlanDO();
            junction.setStrategyId(strategyId);
            junction.setAdPlanId(adPlanId);
            return junction;
        })
        .toList();
    saveBatch(junctions, 500);  // batchSize 500 per flush
}
```

> **Performance note**: `saveBatch` still executes individual INSERT statements (not multi-row INSERT). For truly high-volume bulk inserts (>1000 rows), use a custom `InsertAllBatch` SQL injector method that generates `INSERT INTO ... VALUES (...),(...),(...)`.

### Batch SELECT — IN clause instead of for-loop query

```java
// ❌ WRONG: for-loop selectById — N roundtrips
public List<AdPlanDO> findAdPlans(List<Long> adPlanIds) {
    List<AdPlanDO> result = new ArrayList<>();
    for (Long adPlanId : adPlanIds) {
        result.add(adPlanMapper.selectById(adPlanId));  // N individual SELECTs
    }
    return result;
}

// ✅ CORRECT: listByIds — single SELECT with IN clause
public List<AdPlanDO> findAdPlans(List<Long> adPlanIds) {
    return listByIds(adPlanIds);  // SELECT ... WHERE id IN (1, 2, 3, ...)
}

// ✅ CORRECT: LambdaQueryWrapper with in() — single query by arbitrary field
public List<StrategyAdPlanDO> findByStrategyId(Long strategyId) {
    return lambdaQuery().eq(StrategyAdPlanDO::getStrategyId, strategyId).list();
}

// ✅ CORRECT: in() for batch query by arbitrary field values
public List<UserDO> findUsersByStatuses(List<UserStatus> statuses) {
    return lambdaQuery().in(UserDO::getStatus, statuses).list();
}
```

### Batch UPDATE — updateBatchById instead of for-loop update

```java
// ❌ WRONG: for-loop updateById — N roundtrips
public void updateAllStatuses(List<UserDO> users, UserStatus status) {
    for (UserDO user : users) {
        user.setStatus(status);
        updateById(user);  // N individual UPDATEs
    }
}

// ✅ CORRECT: updateBatchById — single transaction batch UPDATE
@Transactional(rollbackFor = Exception.class)
public void updateAllStatuses(List<UserDO> users, UserStatus status) {
    users.forEach(user -> user.setStatus(status));
    updateBatchById(users);  // batch UPDATE in one transaction
}
```

### Batch DELETE — removeByIds instead of for-loop delete

```java
// ❌ WRONG: for-loop removeById — N roundtrips
public void deleteAll(List<Long> ids) {
    for (Long id : ids) {
        removeById(id);  // N individual DELETE/soft-DELETEs
    }
}

// ✅ CORRECT: removeByIds — single batch DELETE
public void deleteAll(List<Long> ids) {
    removeByIds(ids);  // single DELETE WHERE id IN (...)
}
```

### Batch Method Reference

| Operation | Batch Method | SQL Generated |
|-----------|-------------|---------------|
| INSERT multiple | `saveBatch(entities)` or `saveBatch(entities, batchSize)` | Individual INSERTs in one transaction |
| SELECT by IDs | `listByIds(idList)` | `SELECT ... WHERE id IN (...)` |
| SELECT by field | `lambdaQuery().in(field, values).list()` | `SELECT ... WHERE field IN (...)` |
| UPDATE multiple | `updateBatchById(entities)` or `updateBatchById(entities, batchSize)` | Individual UPDATEs in one transaction |
| DELETE by IDs | `removeByIds(idList)` | `DELETE WHERE id IN (...)` (or soft-delete) |
| SELECT count | `lambdaQuery().in(field, values).count()` | `SELECT COUNT(*) WHERE field IN (...)` |

## Best Practices

- **MVC**: Use `IService/ServiceImpl` pattern with `IService<DO>` / `ServiceImpl<Mapper, DO>`
- **DDD/COLA**: Use Gateway pattern — see `ddd-cola` skill
- **IService transaction behavior**: `saveBatch/saveOrUpdateBatch` have internal `@Transactional`; single methods (`save`, `updateById`, `removeById`) do NOT — add `@Transactional(rollbackFor=Exception.class)` on your method for multi-step writes
- Do not add `@Transactional(readOnly = true)` on pure query methods — auto-commit is sufficient for MyBatis
- Prefer single-table queries — limit JOINs to 3 tables max; for complex data needs, query separately and assemble in application code
- Use Mapper XML for multi-table JOIN queries
- Document each DO class with table mapping, each field with business meaning, each custom Mapper method with parameter descriptions

## Keywords

mybatis-plus, ORM, mapper, DO, LambdaQueryWrapper, lambdaQuery, soft-delete, optimistic-lock, pagination, field-fill, MetaObjectHandler, saveBatch, listByIds, removeByIds, updateBatchById, batch-insert, batch-select, IN-clause, N+1-anti-pattern, IService, ServiceImpl, BaseMapper, @TableName, @TableId, @TableLogic, @Version, @TableField, spring-boot3-starter, Wrappers, Mapper XML, resultMap, join query