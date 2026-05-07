# Flyway Rollback Strategies

## Flyway Community Edition: No Automatic Undo

The Flyway Community (free) edition does **not** support automatic undo migrations. There is no built-in mechanism to reverse an applied migration. When a migration has been applied, it cannot be automatically rolled back.

This is a critical limitation to understand before choosing Flyway — plan rollback strategies from the start.

## Flyway Teams Edition: Undo Migrations

The Flyway Teams (commercial) edition supports undo migrations using the `U` prefix:

```
V3__add_user_status_column.sql       -- forward migration
U3__add_user_status_column.sql       -- undo migration (Teams only)
```

Undo migrations:
- Must match the version number of the forward migration they reverse.
- Are executed with `flyway undo` command.
- Are NOT automatically executed on startup — they must be invoked explicitly.
- Require a Teams edition license.

If you are using the Community edition, ignore undo migrations entirely and use the manual rollback approach below.

## Manual Rollback Approach: Follow-Up Migration

The most practical rollback strategy for Community edition users is to create a new migration that reverses the effect of the previous one. This is a forward migration that happens to undo a prior change.

### Pattern: add column -> drop column

Forward migration:

```sql
-- V2__add_user_status_column.sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_time TIMESTAMPTZ;
```

Rollback migration:

```sql
-- V4__revert_user_status_column.sql
-- Reverts V2: remove the last_login_time column
ALTER TABLE users DROP COLUMN IF EXISTS last_login_time;
```

Note: the rollback migration uses a NEW version number (V4, not V2). It does NOT modify or replace the original V2 migration.

### Pattern: create table -> drop table

Forward migration:

```sql
-- V3__create_audit_log_table.sql
CREATE TABLE IF NOT EXISTS audit_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  TEXT    NOT NULL,
    action      TEXT    NOT NULL,
    old_data    JSONB,
    new_data    JSONB,
    create_time TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Rollback migration:

```sql
-- V5__revert_audit_log_table.sql
-- Reverts V3: remove the audit_log table
DROP TABLE IF EXISTS audit_log;
```

### Pattern: seed data -> delete data

Forward migration:

```sql
-- V3__seed_default_roles.sql
INSERT INTO roles (name, description)
VALUES ('ADMIN', 'System administrator')
ON CONFLICT (name) DO NOTHING;
```

Rollback migration:

```sql
-- V6__revert_default_roles.sql
-- Reverts V3: remove seeded default roles
DELETE FROM roles WHERE name IN ('ADMIN', 'USER', 'GUEST');
```

### Pattern: add constraint -> drop constraint

Forward migration:

```sql
-- V4__add_email_unique_constraint.sql
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);
```

Rollback migration:

```sql
-- V7__revert_email_unique_constraint.sql
-- Reverts V4: remove the email unique constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS uq_users_email;
```

## Repair Command: flyway repair

`flyway repair` resets metadata in the `flyway_schema_history` table. It does **NOT** rollback or undo any database changes.

### What it does

- Resets checksums on failed migration records to match the current file content.
- Removes failed migration records from `flyway_schema_history`.
- Aligns the `flyway_schema_history` table with the actual state of the migration files.

### When to use it

- A migration failed and you fixed the SQL — run `repair` to clear the failed record before re-running `migrate`.
- You intentionally modified a migration file and need to update the stored checksum.
- The `flyway_schema_history` table has stale or inconsistent entries.

### When NOT to use it

- Do NOT use `repair` to "skip" a migration that partially applied — you must manually clean up the partial DDL changes in the database first.
- Do NOT use `repair` as a substitute for rollback — it only fixes metadata, not data or schema.

```bash
# Via Maven
mvn flyway:repair

# Via Flyway CLI
flyway repair
```

## Baseline Recovery

### Failed baseline scenario

If baseline fails (e.g., `flyway_schema_history` could not be created, or the baseline version does not match the existing schema state):

1. Check the database — does the `flyway_schema_history` table exist?
   ```sql
   SELECT * FROM flyway_schema_history;
   ```
2. If it exists but has a failed baseline record, run `flyway repair` to clear it.
3. Ensure `baseline-on-migrate=true` and `baseline-version` matches the last schema version that already exists in the database.
4. Restart the application — Flyway will re-attempt the baseline.

### Baseline on a database with partial Flyway history

If Flyway was previously used but the `flyway_schema_history` table was corrupted or lost:

1. Create the `flyway_schema_history` table manually:
   ```sql
   CREATE TABLE flyway_schema_history (
       installed_rank INT NOT NULL,
       version        TEXT,
       description    TEXT NOT NULL,
       type           TEXT NOT NULL,
       script         TEXT NOT NULL,
       checksum       INT,
       installed_by   TEXT NOT NULL,
       installed_on   TIMESTAMPTZ NOT NULL DEFAULT now(),
       execution_time INT NOT NULL,
       success        BOOLEAN NOT NULL
   );
   ```
2. Insert baseline records for migrations that were already applied:
   ```sql
   INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success)
   VALUES (1, '1', 'init schema', 'SQL', 'V1__init_schema.sql', NULL, 'postgres', now(), 0, true);
   ```
3. Run `flyway repair` to validate the history table.
4. Run `flyway migrate` to apply any remaining pending migrations.

### Skipping a migration with baseline

If you have a migration (e.g., `V1__init_schema.sql`) that should NOT be applied because the database already has those tables:

- Set `baseline-version=1` in configuration.
- Flyway will create a baseline at version 1 and skip `V1__init_schema.sql`.
- Subsequent migrations (V2, V3, ...) will be applied normally.

## Rollback Decision Framework

| Scenario | Strategy |
|---|---|
| Migration failed before applying any changes | Fix SQL, run `flyway repair`, restart application |
| Migration partially applied (some DDL committed) | Manually clean up database, run `flyway repair`, restart |
| Need to undo a recently applied migration | Create a new follow-up migration that reverses the change |
| Need to undo an old migration | Create a follow-up migration — do NOT modify the original |
| Checksum mismatch after intentional file change | Run `flyway repair` to update checksums |
| Baseline failed | Check `flyway_schema_history`, run `flyway repair`, adjust `baseline-version` |
| Need automatic undo capability | Upgrade to Flyway Teams edition for `U{version}` undo migrations |

## Key Rules

1. Never modify an applied migration file — always create a new migration for changes or reversals.
2. `flyway repair` fixes metadata only — it does not change the database schema or data.
3. Rollback in Community edition means creating a forward migration that reverses a prior change.
4. Test rollback migrations on a staging database before applying them to production.
5. Document rollback plans alongside every forward migration — include what the corresponding reversal would look like.