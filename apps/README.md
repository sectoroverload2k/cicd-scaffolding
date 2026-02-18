# Apps Directory

This directory contains **user-facing applications** - frontends, dashboards, and other client-facing services.

## Structure

Each application follows this structure:

```
apps/
└── <app-name>/
    ├── VERSION              # Semantic version (e.g., 1.0.0)
    ├── Dockerfile           # Container build instructions
    ├── src/                 # Application source code
    └── k8s/
        ├── base/
        │   ├── kustomization.yaml
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── configmap.yaml
        └── overlays/
            ├── dev/
            │   ├── kustomization.yaml
            │   └── patch-env.yaml
            ├── staging/
            │   ├── kustomization.yaml
            │   └── patch-env.yaml
            └── prod/
                ├── kustomization.yaml
                ├── patch-env.yaml
                └── hpa.yaml
```

## Creating a New App

1. Create the app directory:
   ```bash
   mkdir -p apps/my-app/{src,k8s/{base,overlays/{dev,staging,prod}}}
   ```

2. Create the VERSION file:
   ```bash
   echo "1.0.0" > apps/my-app/VERSION
   ```

3. Create a Dockerfile:
   ```dockerfile
   FROM node:20-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci --production
   COPY . .
   EXPOSE 3000
   CMD ["npm", "start"]
   ```

4. Create Kustomize base and overlays (see examples in existing apps)

5. Add the app to the change detection in `.github/actions/detect-changes/action.yml`

## Version Management

- Use `scripts/version-bump.sh apps/my-app patch|minor|major` to bump versions
- Version format: `X.Y.Z` (major.minor.patch)
- CI/CD adds environment suffixes: `X.Y.Z-beta.N`, `X.Y.Z-rc.N`

## Conventions

- App names should be lowercase with hyphens (e.g., `admin-dashboard`)
- Each app must have a VERSION file or package.json with version field
- Dockerfiles must accept VERSION build arg for labeling
- Health endpoints must be exposed at `/health` for k8s probes
