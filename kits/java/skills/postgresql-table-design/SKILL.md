---
name: postgresql-table-design
description: "PostgreSQL table design: standard business columns, data types, soft delete, constraints, indexes, partitioning, JSONB, and schema evolution. Use when designing or reviewing PostgreSQL schemas."
version: "1.1.0"
---

# PostgreSQL Table Design

## Load Policy

Use this quick guide for normal schema work. Load `references/full-guide.md` only when choosing advanced data types, partitioning, JSONB indexes, migration strategies, or reviewing complex schemas.

## Standard Business Columns

Every normal business table should include:

- `id BIGINT PRIMARY KEY`: use identity or application snowflake IDs compatible with MyBatis-Plus `IdType.ASSIGN_ID`.
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`.
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`.
- `created_by BIGINT NOT NULL`.
- `updated_by BIGINT NOT NULL`.
- `deleted_at TIMESTAMPTZ`: `NULL` means active; non-null is the deletion timestamp.
- `version INTEGER NOT NULL DEFAULT 1`: optimistic locking.

Add `COMMENT ON TABLE` and `COMMENT ON COLUMN` for every business table and column.

## Type Rules

- Use `TIMESTAMPTZ` for event time. Avoid timestamp without time zone.
- Use `NUMERIC(p,s)` for money. Never use floating point for money.
- Use `TEXT` for strings unless a real constraint is needed; prefer `CHECK (length(col) <= n)` over arbitrary `VARCHAR(n)`.
- Use `BIGINT` for IDs and large counters.
- Use `BOOLEAN NOT NULL` unless tri-state is meaningful.
- Use `JSONB` only for optional or semi-structured attributes; keep core relations as columns/tables.
- Use `UUID` only when global uniqueness or opaque IDs are required.

## Constraint And Index Rules

- Add `NOT NULL` wherever business semantics require a value.
- Add `CHECK` constraints for bounded business states when values are stable.
- PostgreSQL does not auto-index foreign keys; create FK indexes manually.
- Create indexes for actual query predicates, joins, and sort paths.
- Use partial indexes for active rows, for example `CREATE INDEX ... WHERE deleted_at IS NULL`.
- For case-insensitive lookup, prefer an expression index on `lower(column)` unless `citext` is explicitly needed.

## Soft Delete Pattern

- Column: `deleted_at TIMESTAMPTZ`.
- Query active rows with `WHERE deleted_at IS NULL`.
- MyBatis-Plus field: `@TableLogic(value = "", delval = "now()")`.
- Avoid `is_deleted` boolean/integer flags for new tables.

## Safe Evolution

- Use transactional DDL where PostgreSQL supports it.
- Use `CREATE INDEX CONCURRENTLY` for large hot tables, noting it cannot run inside a transaction.
- Avoid volatile defaults when adding columns to large tables.
- Drop dependent constraints before dropping columns.

## Related Skills

- `mybatis-plus-patterns`: Java DO mapping, soft delete, optimistic lock.
- `spring-boot-database-migration`: schema migration workflow.

