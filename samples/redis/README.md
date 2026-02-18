# Redis

A Redis StatefulSet for Kubernetes.

## Usage

1. Copy this folder to your infra directory:
   ```bash
   cp -r samples/redis infra/redis
   ```

2. Deploy:
   ```bash
   kubectl apply -k infra/redis/k8s/overlays/dev
   ```

3. Register in `.github/actions/detect-changes/action.yml`

## Structure

```
redis/
├── VERSION
├── deploy.yaml
└── k8s/
    ├── base/
    │   ├── kustomization.yaml
    │   ├── statefulset.yaml
    │   ├── service.yaml
    │   └── configmap.yaml
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

## Connecting from Applications

Use the service DNS name:
- `redis.{namespace}.svc.cluster.local:6379`

Example:
- Dev: `redis.dev.svc.cluster.local:6379`
- Prod: `redis.prod.svc.cluster.local:6379`

## Persistence

Data is persisted using a PersistentVolumeClaim. Configure storage class in overlays as needed.
