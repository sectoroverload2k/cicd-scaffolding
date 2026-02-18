# Hugo Static Site (Kubernetes)

A Hugo static site deployed to Kubernetes via nginx.

## Usage

1. Copy this folder to your apps directory:
   ```bash
   cp -r samples/hugo-k8s apps/my-site
   ```

2. Customize:
   ```bash
   cd apps/my-site
   # Edit hugo.toml for site settings
   # Add content to content/
   # Customize layouts/ and static/
   # Update VERSION
   ```

3. Register in `.github/actions/detect-changes/action.yml`

4. Commit and push to trigger deployment

## Structure

```
hugo-k8s/
├── VERSION
├── Dockerfile
├── deploy.yaml
├── hugo.toml
├── content/
│   └── _index.md
├── layouts/
│   ├── _default/
│   │   ├── baseof.html
│   │   └── list.html
│   └── partials/
│       └── head.html
├── static/
│   └── css/
│       └── style.css
└── k8s/
    ├── base/
    └── overlays/
```

## Local Development

```bash
# Install Hugo (https://gohugo.io/installation/)
# Then run:
hugo server -D
```

## Build

```bash
hugo --minify
# Output is in public/
```
