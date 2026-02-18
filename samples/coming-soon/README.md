# Coming Soon Page

A static "coming soon" page deployed via SSH/rsync to traditional web servers.

## Usage

1. Copy this folder to your apps directory:
   ```bash
   cp -r samples/coming-soon apps/my-landing
   ```

2. Customize:
   ```bash
   cd apps/my-landing
   # Edit public/index.html with your content
   # Update deploy.yaml with your server hosts
   # Update VERSION
   ```

3. Register in `.github/actions/detect-changes/action.yml`

4. Commit and push to trigger deployment

## Structure

```
coming-soon/
├── VERSION
├── deploy.yaml
├── public/
│   ├── index.html
│   └── styles.css
└── README.md
```

## Deployment

This sample deploys via SSH/rsync to traditional web servers (Apache, nginx, etc.).

Configure your target servers in `deploy.yaml`:

```yaml
targets:
  prod:
    hosts:
      - web1.example.com
      - web2.example.com
    path: /var/www/coming-soon
```

Required GitHub Secrets:
- `PROD_SSH_PRIVATE_KEY` - SSH private key
- `PROD_SSH_USER` - SSH username (optional, defaults to "deploy")
