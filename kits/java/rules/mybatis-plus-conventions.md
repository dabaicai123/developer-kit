---
paths:
  - "**/*Mapper.java"
  - "**/*DO.java"
---

# Rule: MyBatis-Plus Conventions

For full patterns, see `mybatis-plus-patterns` skill. This rule enforces the minimum on every DO/Mapper file.

## Standard Columns (every DO must include)

`id`, `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `deletedAt`, `version`

## Quick Checks

- `@TableName("xxx")` — plain snake_case, no `t_` prefix
- `@TableId(type = IdType.ASSIGN_ID)` — snowflake ID
- `@TableLogic(value = "", delval = "now()")` — timestamp soft delete
- `@TableField(fill = FieldFill.INSERT/UPDATE)` — auto-fill audit fields
- `@Version` — optimistic lock
- `DO` suffix — never `Entity` suffix
- `#{param}` in XML — never `${param}` (SQL injection)
- `lambdaQuery()` inside ServiceImpl — never `new LambdaQueryWrapper<>()`
