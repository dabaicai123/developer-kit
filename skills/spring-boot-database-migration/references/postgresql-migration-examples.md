# PostgreSQL Migration Examples

Complete, runnable SQL migration scripts targeting PostgreSQL for common schema evolution patterns.

## V1__init_schema.sql — Initial Schema

Baseline schema with user, role, and user_role junction table:

```sql
-- V1__init_schema.sql
-- Initial baseline schema: users, roles, user_role

CREATE TABLE IF NOT EXISTS users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username    TEXT    NOT NULL UNIQUE,
    email       TEXT    NOT NULL UNIQUE,
    password    TEXT    NOT NULL,
    status      TEXT    NOT NULL DEFAULT 'ACTIVE'
                CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
    create_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    update_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    create_by   BIGINT  NOT NULL,
    update_by   BIGINT  NOT NULL,
    deleted_at  TIMESTAMPTZ,
    version     INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS roles (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT    NOT NULL UNIQUE,
    description TEXT,
    create_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    update_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_role (
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id     BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Indexes for common access paths
CREATE INDEX IF NOT EXISTS idx_users_email       ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at  ON users (deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_status      ON users (status);
CREATE INDEX IF NOT EXISTS idx_user_role_role_id ON user_role (role_id);
```

## V2__add_user_status.sql — ALTER TABLE with IF NOT EXISTS Guard

Add columns for user activity tracking:

```sql
-- V2__add_user_status.sql
-- Add last_login_time and login_count columns for user activity tracking

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_time TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_count     INTEGER NOT NULL DEFAULT 0;

-- Index for querying recently active users (descending order for "most recent" queries)
CREATE INDEX IF NOT EXISTS idx_users_last_login ON users (last_login_time DESC NULLS LAST);
```

Note: `IF NOT EXISTS` on `ALTER TABLE ADD COLUMN` is a PostgreSQL 9.6+ feature. If using an older version, check column existence before adding:

```sql
-- Alternative for PostgreSQL < 9.6
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'users' AND column_name = 'last_login_time') THEN
        ALTER TABLE users ADD COLUMN last_login_time TIMESTAMPTZ;
    END IF;
END $$;
```

## V3__create_index_and_constraints.sql — CREATE INDEX CONCURRENTLY and ADD CONSTRAINT

Add performance indexes and data integrity constraints:

```sql
-- V3__create_index_and_constraints.sql
-- Add indexes and constraints for query optimization and data integrity

-- IMPORTANT: CREATE INDEX CONCURRENTLY cannot run inside a transaction.
-- Flyway wraps migrations in transactions by default.
-- Either set spring.flyway.execute-in-transaction=false in configuration,
-- or run CONCURRENTLY index creation outside Flyway.

-- For Flyway with execute-in-transaction=false:
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_username_lower ON users (LOWER(username));

-- For Flyway with transactions (default) — use regular CREATE INDEX:
CREATE INDEX IF NOT EXISTS idx_users_username_lower ON users (LOWER(username));

-- Add check constraint for email format
ALTER TABLE users ADD CONSTRAINT chk_users_email_format
    CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Add foreign key with deferrable option for circular references if needed
-- (not needed here, but shown as reference pattern)
-- ALTER TABLE orders ADD CONSTRAINT fk_orders_user_id
--     FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
--     DEFERRABLE INITIALLY DEFERRED;

-- Add unique constraint on role name (already enforced by UNIQUE in V1,
-- shown here as pattern for adding constraints to existing columns)
-- ALTER TABLE roles ADD CONSTRAINT uq_roles_name UNIQUE (name);
```

## V4__seed_reference_data.sql — INSERT with ON CONFLICT DO NOTHING

Seed default roles and system configuration:

```sql
-- V4__seed_reference_data.sql
-- Insert default system roles and initial configuration

-- Seed roles — ON CONFLICT ensures idempotency
INSERT INTO roles (name, description)
VALUES ('ADMIN', 'System administrator with full access')
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description)
VALUES ('USER', 'Standard application user')
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description)
VALUES ('GUEST', 'Read-only guest access')
ON CONFLICT (name) DO NOTHING;

-- Seed system configuration using a key-value pattern
CREATE TABLE IF NOT EXISTS system_config (
    id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key   TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    create_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    update_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO system_config (key, value)
VALUES ('max_login_attempts', '5')
ON CONFLICT (key) DO NOTHING;

INSERT INTO system_config (key, value)
VALUES ('session_timeout_minutes', '30')
ON CONFLICT (key) DO NOTHING;

INSERT INTO system_config (key, value)
VALUES ('password_min_length', '8')
ON CONFLICT (key) DO NOTHING;
```

## V5__alter_column_type.sql — Safe Column Type Change with Temporary Column

Change a column type safely using a temporary column approach to avoid data loss:

```sql
-- V5__alter_column_type.sql
-- Change user.status from TEXT to an ENUM-like pattern with broader CHECK constraint
-- and change login_count from INTEGER to BIGINT for large-scale systems

-- Pattern 1: Simple type expansion (INTEGER -> BIGINT)
-- This is safe because BIGINT is a wider type that accepts all INTEGER values
ALTER TABLE users ALTER COLUMN login_count TYPE BIGINT;

-- Pattern 2: Change TEXT column constraint (add more allowed values)
-- Safe: just widen the CHECK constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS chk_users_status_values;
ALTER TABLE users ADD CONSTRAINT chk_users_status_values
    CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED', 'PENDING', 'LOCKED'));

-- Pattern 3: Safe column type change using temporary column (destructive type change)
-- Example: converting a TEXT column to a narrower type or incompatible type
-- Step 1: Add temporary column with the new type
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_new TEXT NOT NULL DEFAULT '';

-- Step 2: Copy and transform data to the new column
UPDATE users SET email_new = LOWER(TRIM(email));

-- Step 3: Validate the conversion — check for any issues
-- (Manual verification step: SELECT id, email, email_new FROM users WHERE email_new != LOWER(TRIM(email));)

-- Step 4: Drop the old column and rename the new one
-- WARNING: This is destructive. Ensure Step 3 validation passes before proceeding.
ALTER TABLE users DROP COLUMN email;
ALTER TABLE users RENAME COLUMN email_new TO email;

-- Step 5: Re-add constraints and indexes on the renamed column
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);
ALTER TABLE users ADD CONSTRAINT chk_users_email_format
    CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
```

## Additional Patterns

### Creating a junction table for many-to-many relationship

```sql
-- Pattern for creating a clean junction table
CREATE TABLE IF NOT EXISTS user_permission (
    user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    granted_by    BIGINT NOT NULL,
    granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_user_permission_permission ON user_permission (permission_id);
```

### Adding a soft-delete index for active row queries

```sql
-- Partial index for querying only active (non-deleted) rows
-- This is much smaller and faster than a full index
CREATE INDEX IF NOT EXISTS idx_users_active_email ON users (email) WHERE deleted_at IS NULL;
```

### Adding a generated column for computed values

```sql
-- Generated column for derived data (PostgreSQL 12+)
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_domain TEXT
    GENERATED ALWAYS AS (SPLIT_PART(email, '@', 2)) STORED;

CREATE INDEX IF NOT EXISTS idx_users_email_domain ON users (email_domain);
```

### Creating a partitioned table for time-series data

```sql
-- Partitioned table for large-volume time-series data
CREATE TABLE IF NOT EXISTS audit_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    action      TEXT    NOT NULL,
    table_name  TEXT    NOT NULL,
    row_id      BIGINT,
    old_data    JSONB,
    new_data    JSONB,
    create_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    create_by   BIGINT  NOT NULL
) PARTITION BY RANGE (create_time);

-- Create monthly partitions
CREATE TABLE IF NOT EXISTS audit_log_2025_01 PARTITION OF audit_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE IF NOT EXISTS audit_log_2025_02 PARTITION OF audit_log
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE IF NOT EXISTS audit_log_2025_03 PARTITION OF audit_log
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Default partition for catch-all
CREATE TABLE IF NOT EXISTS audit_log_default PARTITION OF audit_log DEFAULT;
```