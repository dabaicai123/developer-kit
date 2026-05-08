---
paths:
  - "**/*Mapper.java"
  - "**/*Service.java"
  - "**/*ServiceImpl.java"
  - "**/*DO.java"
---

# Rule: MyBatis-Plus Conventions

Enforce MyBatis-Plus best practices for mapper, service, and data object definitions. For detailed examples and patterns, use the `mybatis-plus-patterns` skill.

## Data Object (DO) Conventions

- Use `@TableName("xxx")` — explicit table name mapping, no prefix (plain snake_case)
- Use `@TableId(type = IdType.ASSIGN_ID)` — application-layer snowflake ID for distributed systems
- Use `@TableLogic(value = "", delval = "now()")` — timestamp-based soft delete with `deleted_at TIMESTAMPTZ` (NULL = active, `now()` = deleted)
- Use `@TableField(fill = FieldFill.INSERT/UPDATE)` — auto-fill `createdAt`, `updatedAt`, `createdBy`, `updatedBy`
- Use `@Version` — optimistic lock counter, increment on every update

**Standard columns** every DO must include: `id`, `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `deletedAt`, `version`

## Mapper Conventions

- Always extend `BaseMapper<XxxDO>`
- Only add custom methods when `LambdaQueryWrapper` cannot express the query
- Use `@Select` annotation for simple custom queries (prefer over XML mapper files)
- Use `#{param}` (parameterized) — never `${param}` (raw interpolation, SQL injection risk)

## Service Conventions (MVC)

- Interface must extend `IService<XxxDO>`
- Implementation must extend `ServiceImpl<XxxMapper, XxxDO>`
- Use `lambdaQuery()` / `lambdaUpdate()` inside ServiceImpl (not `new LambdaQueryWrapper`)
- Use conditional expressions: `.eq(condition, column, value)` for optional filters
- Use `@Transactional(readOnly = true)` for query methods
- Use `@Transactional(rollbackFor = Exception.class)` for write methods

**DDD/COLA projects** use the Gateway pattern instead — see `ddd-cola` skill.

## Pagination

- Use `PageResult.of(mpPage).map()` for type-safe pagination conversion
- Never paginate in memory (select all then subList)

## Soft Delete Pattern

- SQL column: `deleted_at TIMESTAMPTZ` (NULL = active, non-NULL = deleted timestamp)
- Java field: `@TableLogic(value = "", delval = "now()") private LocalDateTime deletedAt;`
- All SELECT queries automatically filter `WHERE deleted_at IS NULL` via MyBatis-Plus `@TableLogic`
- Partial index for active rows: `CREATE INDEX ON xxx (key) WHERE deleted_at IS NULL`

## Anti-Patterns

- `QueryWrapper` with string column names — use `LambdaQueryWrapper`
- `${param}` in mapper SQL — use `#{param}` (parameterized)
- Direct `BaseMapper` calls in Controller — go through Service
- In-memory pagination — use `Page<>` object
- Physical delete — use `@TableLogic(value = "", delval = "now()")` soft delete
- Integer-based soft delete (`deleted 0/1`) — use `deleted_at TIMESTAMPTZ`
- `new LambdaQueryWrapper<>` outside ServiceImpl — use `lambdaQuery()`
- `@TableName("t_xxx")` prefix — use plain snake_case (`@TableName("xxx")`)
- `Entity` suffix — use `DO` suffix for persistence objects