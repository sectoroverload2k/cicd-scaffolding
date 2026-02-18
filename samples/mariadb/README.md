# MariaDB

A MariaDB StatefulSet for Kubernetes.

## Usage

1. Copy this folder to your infra directory:
   ```bash
   cp -r samples/mariadb infra/mariadb
   ```

2. Customize:
   - Edit `k8s/base/configmap.yaml` for MySQL configuration
   - Edit `k8s/base/init.sql` for initial schema (or remove if using migrations)
   - Update secrets in `k8s/overlays/{env}/secret.yaml`

3. Register in `.github/actions/detect-changes/action.yml`

4. Deploy:
   ```bash
   kubectl apply -k infra/mariadb/k8s/overlays/dev
   ```

## Structure

```
mariadb/
├── VERSION
├── deploy.yaml
└── k8s/
    ├── base/
    │   ├── kustomization.yaml
    │   ├── statefulset.yaml
    │   ├── service.yaml
    │   ├── configmap.yaml
    │   └── init.sql
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

## Connecting from Applications

Use the service DNS name:
- `mariadb.{namespace}.svc.cluster.local:3306`

Example connection string:
```
mysql://user:password@mariadb.dev.svc.cluster.local:3306/myapp
```

## Persistence

Data is persisted using a PersistentVolumeClaim. Default is 10Gi.

## Configuration

MySQL configuration is in `k8s/base/configmap.yaml`. Adjust settings like:
- `innodb_buffer_pool_size`
- `max_connections`
- `max_allowed_packet`

## Initial Schema

The `init.sql` file runs on first deployment. Options:
1. Include your schema here for simple setups
2. Remove it and use Flyway migrations instead (recommended)

## Secrets

Secrets are configured per environment in overlays. Variables are substituted from GitHub Secrets during deployment:
- `MARIADB_ROOT_PASSWORD`
- `MARIADB_USER`
- `MARIADB_PASSWORD`
