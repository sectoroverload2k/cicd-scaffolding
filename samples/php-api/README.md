# PHP REST API

A PHP REST API deployed to Kubernetes.

## Usage

1. Copy this folder to your services directory:
   ```bash
   cp -r samples/php-api services/my-api
   ```

2. Customize:
   ```bash
   cd services/my-api
   # Add your dependencies to composer.json
   # Add your application code to src/
   # Update VERSION
   ```

3. Register in `.github/actions/detect-changes/action.yml`

4. Commit and push to trigger deployment

## Structure

```
php-api/
├── VERSION
├── Dockerfile
├── deploy.yaml
├── composer.json
├── public/
│   └── index.php
├── src/
│   └── .gitkeep
└── k8s/
    ├── base/
    └── overlays/
```

## Development

```bash
# Install dependencies
composer install

# Run locally
php -S localhost:8080 -t public/
```

## Configuration

Environment variables are configured via Kubernetes ConfigMaps and Secrets.

See `k8s/overlays/{env}/` for environment-specific configuration.
