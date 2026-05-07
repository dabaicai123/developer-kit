---
paths:
  - "**/*Mapper.java"
  - "**/*Service.java"
  - "**/*ServiceImpl.java"
  - "**/*Entity.java"
---

# Rule: MyBatis-Plus Conventions

Enforce MyBatis-Plus best practices for mapper, service, and entity definitions. For detailed examples and patterns, use the `mybatis-plus-patterns` skill.

## Entity Conventions

- Use `@TableName("t_xxx")` — explicit table name mapping
- Use `@TableId(type = IdType.ASSIGN_ID)` — for distributed systems
- Use `@TableLogic` — soft delete (never physical delete)
- Use `@TableField(fill = FieldFill.INSERT/UPDATE)` — auto-fill timestamps

## Mapper Conventions

- Always extend `BaseMapper<XxxEntity>`
- Only add custom methods when `LambdaQueryWrapper` cannot express the query
- Use `@Select` annotation for simple custom queries (prefer over XML mapper files)
- Use `#{param}` (parameterized) — never `${param}` (raw interpolation, SQL injection risk)

## Service Conventions

- Interface must extend `IService<XxxEntity>`
- Implementation must extend `ServiceImpl<XxxMapper, XxxEntity>`
- Use `lambdaQuery()` / `lambdaUpdate()` inside ServiceImpl (not `new LambdaQueryWrapper`)
- Use conditional expressions: `.eq(condition, column, value)` for optional filters
- Use `@Transactional(readOnly = true)` for query methods
- Use `@Transactional(rollbackFor = Exception.class)` for write methods

## Pagination

- Use `PageResult.of(mpPage).map()` for type-safe pagination conversion
- Never paginate in memory (select all then subList)

## Anti-Patterns

- `QueryWrapper` with string column names — use `LambdaQueryWrapper`
- `${param}` in mapper SQL — use `#{param}` (parameterized)
- Direct `BaseMapper` calls in Controller — go through Service
- In-memory pagination — use `Page<>` object
- Physical delete — use `@TableLogic` soft delete
- `new LambdaQueryWrapper<>` outside ServiceImpl — use `lambdaQuery()`