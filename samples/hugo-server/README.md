# Hugo Static Site (Server)

A Hugo static site deployed via SSH/rsync to traditional web servers.

## Usage

1. Copy this folder to your apps directory:
   ```bash
   cp -r samples/hugo-server apps/my-site
   ```

2. Customize:
   ```bash
   cd apps/my-site
   # Edit hugo.toml for site settings
   # Add content to content/
   # Customize layouts/ and static/
   # Update deploy.yaml with your server hosts
   # Update VERSION
   ```

3. Register in `.github/actions/detect-changes/action.yml`

4. Commit and push to trigger deployment

## Structure

```
hugo-server/
├── VERSION
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
└── static/
    └── css/
        └── style.css
```

## Deployment

Hugo builds the site during CI, then the `public/` output is synced to your servers.

Configure target servers in `deploy.yaml`.

Required GitHub Secrets:
- `PROD_SSH_PRIVATE_KEY` - SSH private key
- `PROD_SSH_USER` - SSH username (optional, defaults to "deploy")

## Local Development

```bash
hugo server -D
```

## Build

```bash
hugo --minify
# Output is in public/
```
