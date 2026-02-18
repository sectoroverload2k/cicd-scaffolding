# Database Schema (Baseline)

This directory contains the **current database schema** - a snapshot of what the database looks like after all migrations have run.

## Purpose

| Use Case | What to Use |
|----------|-------------|
| **New environment** | Run `baseline.sql` (fast, single file) |
| **Existing environment** | Run migrations incrementally |
| **Code review** | Review individual files in `tables/`, `triggers/`, etc. |
| **Documentation** | Understand current schema without tracing migrations |

## Directory Structure

```
schema/
├── tables/           # CREATE TABLE statements
├── triggers/         # Trigger definitions
├── procedures/       # Stored procedures
├── views/            # View definitions
├── baseline.sql      # Combined schema for bootstrapping
└── README.md
```

## Bootstrapping a New Environment

### Option 1: Using baseline.sql (Recommended for new environments)

```bash
# 1. Run the baseline schema
mysql -u root -p database_name < infra/mysql/schema/baseline.sql

# 2. Tell Flyway this database is at the current version
#    (prevents Flyway from trying to run old migrations)
flyway -baselineVersion=XXX baseline
```

Replace `XXX` with the latest migration version (e.g., `001` if V001 is the latest).

### Option 2: Running all migrations

```bash
# Run all migrations from V001 to latest
flyway migrate
```

This works but is slower for databases with many migrations.

## Keeping Schema in Sync

The baseline must match what migrations produce. This is validated in CI:

```bash
# Run validation script
./scripts/validate-schema.sh
```

The script:
1. Spins up a test database
2. Runs all migrations
3. Dumps the resulting schema
4. Compares against `baseline.sql`
5. Fails if they differ

## Updating the Schema

When adding a new migration:

1. Create migration file: `migrations/V002__add_orders.sql`
2. Update individual schema files: `tables/orders.sql`
3. Regenerate baseline: `./scripts/generate-schema.sh`
4. Commit all three together

Or use the automated approach:

```bash
# After running migrations on a dev database
./scripts/generate-schema.sh --from-db mysql://user:pass@localhost/mydb
```

## File Conventions

### Tables (`tables/*.sql`)

```sql
-- tables/users.sql
CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL,
    -- ... columns ...
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Triggers (`triggers/*.sql`)

```sql
-- triggers/users_audit.sql
DELIMITER //
CREATE TRIGGER users_after_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (entity_type, entity_id, action)
    VALUES ('user', NEW.id, 'update');
END//
DELIMITER ;
```

### Stored Procedures (`procedures/*.sql`)

```sql
-- procedures/get_user_stats.sql
DELIMITER //
CREATE PROCEDURE get_user_stats(IN user_id BIGINT)
BEGIN
    SELECT COUNT(*) as order_count
    FROM orders
    WHERE user_id = user_id;
END//
DELIMITER ;
```

### Views (`views/*.sql`)

```sql
-- views/active_users.sql
CREATE OR REPLACE VIEW active_users AS
SELECT id, email, first_name, last_name
FROM users
WHERE status = 'active';
```
