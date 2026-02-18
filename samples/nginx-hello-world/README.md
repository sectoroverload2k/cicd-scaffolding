# nginx Hello World

A minimal nginx deployment for Kubernetes.

## Usage

1. Copy this folder to your apps or services directory:
   ```bash
   cp -r samples/nginx-hello-world apps/my-app
   ```

2. Rename and customize:
   ```bash
   cd apps/my-app
   # Edit html/index.html with your content
   # Update VERSION
   # Rename references in k8s/ manifests
   ```

3. Register in `.github/actions/detect-changes/action.yml`

4. Commit and push to trigger deployment

## Structure

```
nginx-hello-world/
├── VERSION
├── Dockerfile
├── deploy.yaml
├── html/
│   └── index.html
└── k8s/
    ├── base/
    │   ├── kustomization.yaml
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── configmap.yaml
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

## Customization

- Edit `html/index.html` for your content
- Add more HTML/CSS/JS files to `html/`
- Modify nginx config in `k8s/base/configmap.yaml`
