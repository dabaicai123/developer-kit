---
name: mybatis-plus-patterns
description: "MyBatis-Plus mapper, data object, service, LambdaQueryWrapper, pagination, soft delete, field fill, optimistic lock, and batch patterns. Use when implementing Java Spring Boot persistence with MyBatis-Plus."
version: "1.1.0"
type: skill
---

# MyBatis-Plus Patterns

## Load Policy

Use this quick guide for normal feature work. Load `references/full-guide.md` only when generating detailed examples, configuring interceptors/meta-object handlers, writing Mapper XML joins, or explaining edge cases.

## Core Rules

- Use `mybatis-plus-spring-boot3-starter` for Spring Boot 3.x.
- Use DO suffix for persistence objects; never use `Entity` suffix for table records.
- Use `@TableName`, `@TableId(type = IdType.ASSIGN_ID)`, `@TableLogic(value = "", delval = "now()")`, and `@Version` when the table has those columns.
- Use `LambdaQueryWrapper`, `Wrappers.lambdaQuery()`, or ServiceImpl `lambdaQuery()`/`lambdaUpdate()`. Never use raw `QueryWrapper` with string column names.
- Use `IService<DO>` and `ServiceImpl<Mapper, DO>` for MVC modules.
- Use domain Gateway and infrastructure GatewayImpl for COLA/DDD modules; see `ddd-cola`.
- Controllers never call Mapper or BaseMapper directly.
- Select only needed columns in custom SQL. Avoid `SELECT *`.
- Use `#{param}` for SQL values. Do not use `${param}` unless validating a dynamic identifier.

## Data Object Checklist

- Java field names match snake_case columns through camel-case mapping.
- Standard columns map to `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `deletedAt`, `version`.
- Sensitive fields use `@TableField(select = false)`.
- Non-table fields use `@TableField(exist = false)`.
- Every DO class and field has the project-required Chinese Javadoc/field comment from `kits/java/rules/java-coding-style.md`.

## Query And Pagination

- In ServiceImpl, prefer `lambdaQuery()` and `lambdaUpdate()`.
- Outside ServiceImpl, use `Wrappers.lambdaQuery()`.
- Use `org.springframework.util.StringUtils.hasText()` for text predicates.
- Use MyBatis-Plus `Page<T>` for pagination, then convert to project `PageResult<T>`.
- For multi-table joins, use Mapper XML with explicit result maps. Keep joins small; split and assemble in application code when joins become complex.

## Writes And Batches

- Single `save`, `updateById`, and `removeById` are not transactional by themselves.
- Add `@Transactional(rollbackFor = Exception.class)` around multi-step writes.
- Replace looped DB calls with batch methods or `IN` queries: `saveBatch`, `updateBatchById`, `removeByIds`, `listByIds`, or `lambdaQuery().in(...)`.
- `saveBatch` is transactional but still emits individual inserts; for high-volume bulk insert, use a custom multi-row SQL path.
- After optimistic-lock update, if affected rows are zero, throw a concurrent modification business exception.

## Soft Delete And Locking

- Soft delete column is `deleted_at TIMESTAMPTZ`; active rows have `NULL`.
- Java field is `@TableLogic(value = "", delval = "now()") private LocalDateTime deletedAt;`.
- Create partial indexes for active rows, for example `WHERE deleted_at IS NULL`.
- Register `OptimisticLockerInnerInterceptor`; otherwise `@Version` is silently ineffective.

## Related References

- `references/full-guide.md`: examples, interceptor setup, Mapper XML, batch examples, detailed tables.
- `../spring-boot-transaction-management/references/full-guide.md`: transaction interaction details.

