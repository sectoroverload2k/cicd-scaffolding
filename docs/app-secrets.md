# Injecting application secrets at deploy time

The reusable `_deploy-service.yml` workflow renders
`k8s/overlays/<env>/secret.yaml` with `envsubst` just before applying it, so
your secret template can reference `${VARS}` that are filled from GitHub secrets
at deploy time. Nothing secret is ever committed to git.

## Supported variables

`_deploy-service.yml` substitutes this allowlist (any not provided resolve to
empty):

| Variable | Reusable-workflow secret |
|----------|--------------------------|
| `${MYSQL_PASSWORD}` | `MYSQL_PASSWORD` |
| `${JWT_SECRET}` | `JWT_SECRET` |
| `${DB_PASS}` | `DB_PASS` |
| `${PG_PASS}` | `PG_PASS` |
| `${ANTHROPIC_API_KEY}` | `ANTHROPIC_API_KEY` |
| `${GOOGLE_CLIENT_ID}` | `GOOGLE_CLIENT_ID` |
| `${GOOGLE_CLIENT_SECRET}` | `GOOGLE_CLIENT_SECRET` |
| `${VOYAGE_API_KEY}` | `VOYAGE_API_KEY` |

The `envsubst` call uses an explicit allowlist, so literal `$` characters in
your manifests are left untouched.

## 1. Secret template (committed, no real values)

```yaml
# services/myapp/k8s/overlays/prod/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-env
type: Opaque
stringData:
  .env: |
    JWT_SECRET=${JWT_SECRET}
    ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    PG_PASS=${PG_PASS}
```

## 2. Pass the secrets from your `cd-*.yml`

In the `deploy-kubernetes` job that calls `_deploy-service.yml`, map your
prefixed environment secrets to the workflow's secret inputs:

```yaml
  deploy-kubernetes:
    uses: ./.github/workflows/_deploy-service.yml
    with:
      service: ${{ matrix.service }}
      service-path: ${{ matrix.path }}
      environment: prod
      image-tag: ${{ needs.build.outputs.version }}
    secrets:
      KUBECONFIG: ${{ secrets.PROD_KUBECONFIG }}
      JWT_SECRET: ${{ secrets.PROD_JWT_SECRET }}
      DB_PASS: ${{ secrets.PROD_DB_PASSWORD }}
      PG_PASS: ${{ secrets.PROD_PG_PASSWORD }}
      ANTHROPIC_API_KEY: ${{ secrets.PROD_ANTHROPIC_API_KEY }}
      GOOGLE_CLIENT_ID: ${{ secrets.PROD_GOOGLE_CLIENT_ID }}
      GOOGLE_CLIENT_SECRET: ${{ secrets.PROD_GOOGLE_CLIENT_SECRET }}
      VOYAGE_API_KEY: ${{ secrets.PROD_VOYAGE_API_KEY }}
```

Repeat with the `DEV_`/`STAGING_` prefixes in `cd-develop.yml` /
`cd-staging.yml`.
