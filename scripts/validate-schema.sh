#!/usr/bin/env bash
#
# validate-schema.sh - Validate that baseline schema matches migrations
#
# Usage:
#   ./scripts/validate-schema.sh
#   ./scripts/validate-schema.sh --ci  # Exit with error code for CI
#
# This script:
#   1. Spins up a temporary MySQL container
#   2. Runs all migrations using Flyway
#   3. Dumps the resulting schema
#   4. Compares against baseline.sql
#   5. Reports any differences
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MYSQL_VERSION="${MYSQL_VERSION:-8.0}"
MYSQL_ROOT_PASSWORD="testpassword"
MYSQL_DATABASE="testdb"
CONTAINER_NAME="schema-validator-$$"
MIGRATIONS_DIR="infra/mysql/migrations"
SCHEMA_DIR="infra/mysql/schema"
CI_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ci)
            CI_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--ci]"
            echo ""
            echo "Options:"
            echo "  --ci    CI mode - exit with error code if validation fails"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
    rm -rf /tmp/schema-validate-$$ || true
}

trap cleanup EXIT

# Check prerequisites
if ! command -v docker &> /dev/null; then
    log_error "Docker is required but not installed"
    exit 1
fi

# Check for migration files
MIGRATION_FILES=$(find "$MIGRATIONS_DIR" -name "V*.sql" -type f 2>/dev/null | grep -v ".example" | head -1)
if [[ -z "$MIGRATION_FILES" ]]; then
    log_warn "No migration files found in $MIGRATIONS_DIR (only .example files)"
    log_info "Skipping validation - rename .example files to .sql to enable"
    exit 0
fi

# Check for baseline
if [[ ! -f "$SCHEMA_DIR/baseline.sql" ]]; then
    log_error "Baseline file not found: $SCHEMA_DIR/baseline.sql"
    exit 1
fi

log_info "Starting MySQL $MYSQL_VERSION container..."

# Start MySQL container
docker run -d \
    --name "$CONTAINER_NAME" \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DATABASE" \
    mysql:$MYSQL_VERSION \
    --default-authentication-plugin=mysql_native_password \
    > /dev/null

# Wait for MySQL to be ready
log_info "Waiting for MySQL to be ready..."
RETRIES=30
until docker exec "$CONTAINER_NAME" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" > /dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [[ $RETRIES -le 0 ]]; then
        log_error "MySQL failed to start"
        exit 1
    fi
    sleep 1
done
log_success "MySQL is ready"

# Create temp directory for work
WORK_DIR="/tmp/schema-validate-$$"
mkdir -p "$WORK_DIR"

# -----------------------------------------------------------------------------
# Path 1: Run migrations
# -----------------------------------------------------------------------------
log_info "Running migrations..."

# Copy migrations to container
docker cp "$MIGRATIONS_DIR" "$CONTAINER_NAME:/migrations"

# Run Flyway migrations
docker run --rm \
    --network container:"$CONTAINER_NAME" \
    -v "$(pwd)/$MIGRATIONS_DIR:/flyway/sql:ro" \
    flyway/flyway:10 \
    -url="jdbc:mysql://127.0.0.1:3306/$MYSQL_DATABASE" \
    -user=root \
    -password="$MYSQL_ROOT_PASSWORD" \
    -locations="filesystem:/flyway/sql" \
    -baselineOnMigrate=true \
    -validateMigrationNaming=true \
    migrate \
    > "$WORK_DIR/flyway.log" 2>&1 || {
        log_error "Flyway migration failed"
        cat "$WORK_DIR/flyway.log"
        exit 1
    }

log_success "Migrations completed"

# Dump schema after migrations
log_info "Dumping schema after migrations..."

docker exec "$CONTAINER_NAME" mysqldump \
    -uroot -p"$MYSQL_ROOT_PASSWORD" \
    --no-data \
    --skip-comments \
    --skip-add-drop-table \
    --skip-add-locks \
    --skip-disable-keys \
    --compact \
    "$MYSQL_DATABASE" \
    2>/dev/null | grep -v "^/\*" | grep -v "flyway_schema_history" \
    > "$WORK_DIR/from_migrations.sql"

# -----------------------------------------------------------------------------
# Path 2: Run baseline
# -----------------------------------------------------------------------------
log_info "Testing baseline schema..."

# Create a second database for baseline
docker exec "$CONTAINER_NAME" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" \
    -e "CREATE DATABASE baseline_test" 2>/dev/null

# Run baseline
docker exec -i "$CONTAINER_NAME" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" baseline_test \
    < "$SCHEMA_DIR/baseline.sql" 2>/dev/null

log_success "Baseline applied"

# Dump schema after baseline
log_info "Dumping schema after baseline..."

docker exec "$CONTAINER_NAME" mysqldump \
    -uroot -p"$MYSQL_ROOT_PASSWORD" \
    --no-data \
    --skip-comments \
    --skip-add-drop-table \
    --skip-add-locks \
    --skip-disable-keys \
    --compact \
    baseline_test \
    2>/dev/null | grep -v "^/\*" \
    > "$WORK_DIR/from_baseline.sql"

# -----------------------------------------------------------------------------
# Compare
# -----------------------------------------------------------------------------
log_info "Comparing schemas..."

# Normalize both files for comparison (sort, remove whitespace variations)
normalize_sql() {
    cat "$1" | \
        sed 's/AUTO_INCREMENT=[0-9]* //g' | \
        sed 's/  */ /g' | \
        tr -s '\n' | \
        sort
}

normalize_sql "$WORK_DIR/from_migrations.sql" > "$WORK_DIR/migrations_normalized.sql"
normalize_sql "$WORK_DIR/from_baseline.sql" > "$WORK_DIR/baseline_normalized.sql"

if diff -q "$WORK_DIR/migrations_normalized.sql" "$WORK_DIR/baseline_normalized.sql" > /dev/null 2>&1; then
    log_success "Schema validation passed!"
    echo ""
    log_info "Baseline matches migrations - they produce identical schemas"
    exit 0
else
    log_error "Schema validation FAILED!"
    echo ""
    log_info "Differences found between migrations and baseline:"
    echo ""

    diff --color=auto -u \
        "$WORK_DIR/migrations_normalized.sql" \
        "$WORK_DIR/baseline_normalized.sql" \
        | head -50 || true

    echo ""
    log_info "Full diff saved to: $WORK_DIR/schema_diff.txt"
    diff -u "$WORK_DIR/migrations_normalized.sql" "$WORK_DIR/baseline_normalized.sql" \
        > "$WORK_DIR/schema_diff.txt" 2>&1 || true

    echo ""
    log_warn "To fix this:"
    log_info "1. Run migrations on a dev database"
    log_info "2. Regenerate baseline: ./scripts/generate-schema.sh --from-db <url>"
    log_info "3. Commit the updated schema files"

    if [[ "$CI_MODE" == "true" ]]; then
        exit 1
    else
        exit 0
    fi
fi
