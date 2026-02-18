# Infrastructure Directory

This directory contains **infrastructure components** - databases, caches, message queues, and shared configurations.

## Structure

```
infra/
├── mysql/
│   ├── migrations/          # Flyway SQL migrations (incremental)
│   │   ├── V001__initial_schema.sql
│   │   └── V002__add_users_table.sql
│   ├── schema/              # Current schema (baseline)
│   │   ├── tables/          # Individual table definitions
│   │   ├── triggers/
│   │   ├── procedures/
│   │   ├── views/
│   │   └── baseline.sql     # Combined schema for bootstrapping
│   └── k8s/
│       ├── base/
│       │   ├── kustomization.yaml
│       │   └── migration-job.yaml
│       └── overlays/
│           ├── dev/
│           ├── staging/
│           └── prod/
│
├── redis/
│   └── k8s/
│       ├── base/
│       └── overlays/
│
└── shared/
    └── k8s/
        └── base/
            ├── kustomization.yaml
            └── namespace.yaml     # Environment namespaces
```

## Components

### MySQL
- Flyway migrations for incremental schema changes
- Schema baseline for bootstrapping new environments
- ConfigMap for migration files
- Job for running migrations during deployment

See [`mysql/schema/README.md`](mysql/schema/README.md) for baseline usage.

### Redis
- Caching and session storage
- Deployed as StatefulSet or using managed service

### Shared
- Namespace definitions
- Network policies
- Common ConfigMaps and Secrets
- RBAC resources

## Database Migrations

We use Flyway Community Edition for forward migrations.

### Migration File Naming

```
V{version}__{description}.sql
```

- Version: Zero-padded number (001, 002, ..., 999)
- Double underscore separator
- Description with underscores for spaces

Examples:
- `V001__create_users_table.sql`
- `V002__add_orders_table.sql`
- `V003__add_user_email_index.sql`

### Creating Migrations

1. Add new SQL file in `infra/mysql/migrations/`
2. Use the next version number
3. Write idempotent SQL when possible
4. Test locally before committing

### Migration Execution

Migrations run automatically during deployment:
1. SQL files packaged into ConfigMap
2. Flyway Job executes against target database
3. Application deployment waits for Job completion

### Rollback

Flyway Community doesn't support automatic rollback. For rollbacks:
1. Create a new forward migration to undo changes
2. Or manually apply undo script

## Namespace Strategy

| Environment | Namespace | Description |
|-------------|-----------|-------------|
| Development | `dev` | Development deployments |
| Staging | `staging` | Pre-production testing |
| Production | `prod` | Production workloads |

## Network Policies

Shared network policies enforce:
- Services can only communicate with declared dependencies
- Ingress only from ingress controller
- Egress restrictions for production

## Adding Infrastructure Components

1. Create directory under `infra/`
2. Add Kustomize base and overlays
3. Update `platform/platform.yaml` if it's a platform component
4. Update `platform/compatibility.yaml` for dependency tracking
