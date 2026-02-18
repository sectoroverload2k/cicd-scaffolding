# Services Directory

This directory contains **backend microservices** - APIs, workers, and other backend components.

## Structure

Each service follows this structure:

```
services/
└── <service-name>/
    ├── VERSION              # Semantic version (e.g., 1.0.0)
    ├── Dockerfile           # Container build instructions
    ├── src/                 # Service source code
    └── k8s/
        ├── base/
        │   ├── kustomization.yaml
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── configmap.yaml
        └── overlays/
            ├── dev/
            │   ├── kustomization.yaml
            │   ├── patch-env.yaml
            │   └── secret.yaml        # Secret template
            ├── staging/
            │   ├── kustomization.yaml
            │   ├── patch-env.yaml
            │   └── secret.yaml
            └── prod/
                ├── kustomization.yaml
                ├── patch-env.yaml
                ├── secret.yaml
                └── hpa.yaml           # Production autoscaling
```

## Creating a New Service

1. Create the service directory:
   ```bash
   mkdir -p services/my-service/{src,k8s/{base,overlays/{dev,staging,prod}}}
   ```

2. Create the VERSION file:
   ```bash
   echo "1.0.0" > services/my-service/VERSION
   ```

3. Create Kustomize manifests

4. Add the service to `.github/actions/detect-changes/action.yml`

5. Update `platform/compatibility.yaml` if the service has dependencies

## Database Migrations

If your service requires database migrations:

1. Add SQL files to `infra/mysql/migrations/`
2. Follow naming convention: `V{NNN}__{description}.sql`
3. Set `run-migrations: true` in the deploy workflow

## Secrets

Secret templates use environment variable substitution:

```yaml
# services/api/k8s/overlays/dev/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-secrets
type: Opaque
stringData:
  MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
  JWT_SECRET: "${JWT_SECRET}"
```

Variables are substituted during deployment from GitHub Secrets.

## Health Checks

All services must expose:
- `GET /health` - Liveness probe
- `GET /ready` - Readiness probe (optional, checks dependencies)
- `GET /metrics` - Prometheus metrics (optional)

## Conventions

- Service names should be lowercase with hyphens (e.g., `user-service`)
- Use REST APIs with OpenAPI specs when possible
- Log to stdout in JSON format
- Exit with non-zero code on fatal errors
