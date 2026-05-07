# Flyway Migration Naming Conventions

## Standard Naming Pattern

Flyway SQL migrations must follow this naming pattern:

```
V{version}__{description}.sql
```

- **V** — prefix for versioned migrations (uppercase)
- **{version}** — version number (see strategies below)
- **__** — double underscore separator (NOT single underscore)
- **{description}** — brief, human-readable description using underscores as word separators
- **.sql** — file extension

Example: `V2__add_user_status_column.sql`

### Why double underscore?

Single underscore (`V2_add_user_status.sql`) is parsed differently by Flyway — the portion after the single underscore is treated as part of the version identifier, not as the description. This causes unexpected behavior and should never be used for versioned migrations.

## Version Numbering Strategies

### Sequential numbering

Simple, easy to read, common for small teams:

```
V1__init_schema.sql
V2__add_user_status.sql
V3__seed_default_roles.sql
V4__create_order_table.sql
```

Pros: intuitive ordering, easy to find the latest migration.
Cons: prone to merge conflicts when multiple developers create migrations simultaneously (two developers may both create `V4__...`).

### Timestamp-based numbering

Uses a timestamp as the version number, eliminates merge conflicts:

```
V20250507120000__init_schema.sql
V20250507143000__add_user_status.sql
V20250508100000__seed_default_roles.sql
```

Format: `V{YYYYMMDDHHmmss}__description.sql`

Pros: no version number collisions in parallel development.
Cons: less readable, harder to quickly determine the number of migrations or find the "next" one.

### Recommendation

- Small teams (1-3 developers): sequential numbering is sufficient.
- Larger teams or parallel feature branches: timestamp-based numbering avoids collisions.
- Either way, enforce the convention in CI — reject migrations that don't follow the pattern.

## Repeatable Migrations

Repeatable migrations use the `R` prefix:

```
R__{description}.sql
```

- Run every time their checksum changes (not based on version).
- Useful for views, functions, stored procedures, and triggers that may need updating.
- Applied after all versioned migrations.
- Re-run automatically when the file content changes.

Examples:

```
R__create_user_detail_view.sql
R__create_status_check_function.sql
R__create_audit_trigger.sql
```

## Undo Migrations

Undo migrations use the `U` prefix:

```
U{version}__{description}.sql
```

- **Flyway Teams edition only** — the free Community edition does NOT support undo migrations.
- Reverse the effect of the corresponding versioned migration.
- Must match the version number of the migration they undo.

Example:

```
V3__add_user_status.sql       -- adds column
U3__add_user_status.sql       -- removes column (Teams edition only)
```

For Community edition users: create manual follow-up migrations to reverse changes (see [flyway-rollback-strategies](flyway-rollback-strategies.md)).

## Baseline Migrations

Baseline migrations use the `B` prefix:

```
B__{description}.sql
```

- Used to baseline an existing database that was created before Flyway was introduced.
- Flyway executes the baseline migration to establish the initial `flyway_schema_history` entry.
- In practice, setting `baseline-on-migrate=true` with a `baseline-version` in Spring Boot configuration is more common than using `B__` files.

## Directory Structure

The standard directory for Flyway migrations in a Spring Boot project:

```
src/main/resources/
  db/
    migration/              -- versioned and repeatable migrations
      V1__init_schema.sql
      V2__add_user_status.sql
      V3__seed_default_roles.sql
      R__create_user_view.sql
```

Configure custom locations in `application.yml`:

```yaml
spring:
  flyway:
    locations: classpath:db/migration
```

Multiple locations can be specified:

```yaml
spring:
  flyway:
    locations: classpath:db/migration,classpath:db/migration-prod
```

## Common Naming Mistakes

1. **Single underscore instead of double underscore**:
   - Wrong: `V2_add_user_status.sql` — Flyway misparses the version and description.
   - Correct: `V2__add_user_status.sql`

2. **Spaces in file names**:
   - Wrong: `V2__add user status.sql` — Flyway may reject or misparse.
   - Correct: `V2__add_user_status.sql`

3. **Lowercase V prefix**:
   - Wrong: `v2__add_user_status.sql` — Flyway only recognizes uppercase `V` by default.
   - Correct: `V2__add_user_status.sql`

4. **Modifying an applied migration**:
   - Wrong: editing `V2__add_user_status.sql` after it has been applied to any database.
   - Correct: create a new migration (e.g., `V5__modify_user_status.sql`) for any additional changes.

5. **Missing version gap**:
   - Wrong: `V1__init.sql`, `V1.1__patch.sql` — fractional versions are valid but confusing.
   - Correct: use integer sequences (`V1`, `V2`, `V3`) or timestamps consistently.

6. **Non-SQL file extensions**:
   - Wrong: `V2__add_user_status.txt`
   - Correct: `V2__add_user_status.sql`

7. **Mixed naming strategies**:
   - Wrong: mixing `V1__init.sql` with `V20250507__add_column.sql` in the same project.
   - Correct: pick one strategy (sequential or timestamp) and use it consistently.