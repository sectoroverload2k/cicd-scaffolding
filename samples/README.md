# Samples

Copy-paste ready samples for different application types.

## Available Samples

| Sample | Type | Deploy | Description |
|--------|------|--------|-------------|
| [nginx-hello-world](nginx-hello-world/) | Kubernetes | kubernetes | Minimal nginx container |
| [coming-soon](coming-soon/) | Static HTML | server | Static page via SSH/rsync |
| [php-api](php-api/) | PHP REST API | kubernetes | PHP-FPM + nginx container |
| [redis](redis/) | Redis | kubernetes | Redis StatefulSet |
| [mariadb](mariadb/) | MariaDB | kubernetes | MariaDB StatefulSet |
| [hugo-k8s](hugo-k8s/) | Hugo site | kubernetes | Hugo built into nginx container |
| [hugo-server](hugo-server/) | Hugo site | server | Hugo deployed via SSH/rsync |

## Usage

1. Copy sample to `apps/` or `services/`:
   ```bash
   cp -r samples/nginx-hello-world apps/my-app
   ```

2. Customize:
   - Update `VERSION`
   - Modify source files
   - Update `deploy.yaml` with your targets
   - Rename references in k8s manifests (if applicable)

3. Register in change detection:
   ```yaml
   # .github/actions/detect-changes/action.yml
   my-app:
     - 'apps/my-app/**'
   ```

4. Commit and push

## Deploy Types

Each sample has a `deploy.yaml` specifying how it's deployed:

```yaml
# Kubernetes deployment
type: kubernetes

# Server deployment (SSH/rsync)
type: server
method: rsync
targets:
  prod:
    hosts:
      - web1.example.com
    path: /var/www/app

# Migration only (managed database)
type: migration
```

See [deploy/deploy.schema.yaml](../deploy/deploy.schema.yaml) for full options.
