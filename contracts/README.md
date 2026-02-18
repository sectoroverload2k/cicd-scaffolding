# Contracts Directory

This directory contains **API contracts** and **event schemas** that define interfaces between services. Contracts enable parallel development - one developer implements the API while another builds the client, both working from the same spec.

## Structure

```
contracts/
├── api/                    # OpenAPI/Swagger specifications
│   ├── api.yaml            # Main API service spec
│   ├── auth.yaml           # Auth service spec
│   └── ...
│
└── events/                 # Event schemas (for async messaging)
    ├── user-created.json   # JSON Schema for user.created event
    └── ...
```

## Workflow: Contract-First Development

```
┌─────────────────────────────────────────────────────────────────┐
│  1. DESIGN PHASE                                                │
│     Backend dev creates/updates OpenAPI spec                    │
│     PR: feature/api/users-endpoint-contract                     │
│     Contains ONLY the contract, no implementation               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. CONTRACT MERGED TO DEVELOP                                  │
│     Both teams can now work in parallel                         │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
┌───────────────────────┐           ┌───────────────────────┐
│  Backend Dev          │           │  Frontend Dev         │
│                       │           │                       │
│  • Implements API     │           │  • Generates client   │
│  • Writes tests       │           │  • Builds UI          │
│  • Validates against  │           │  • Mocks responses    │
│    contract           │           │    from contract      │
│                       │           │                       │
│  PR: feature/api/     │           │  PR: feature/         │
│      users-impl       │           │      dashboard/users  │
└───────────────────────┘           └───────────────────────┘
            │                                   │
            ▼                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. BOTH MERGE (in any order)                                   │
│     Compatible because both used same contract                  │
└─────────────────────────────────────────────────────────────────┘
```

## OpenAPI Specifications

### Creating a New API Contract

```yaml
# contracts/api/users.yaml
openapi: 3.0.3
info:
  title: Users API
  version: 1.0.0
  description: User management endpoints

servers:
  - url: http://localhost:3000
    description: Local development
  - url: https://api.dev.example.com
    description: Development
  - url: https://api.staging.example.com
    description: Staging
  - url: https://api.example.com
    description: Production

paths:
  /users:
    get:
      summary: List users
      operationId: listUsers
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      required:
        - id
        - email
      properties:
        id:
          type: integer
          format: int64
        email:
          type: string
          format: email
        name:
          type: string
```

### Generating Clients

Frontend developers can generate typed API clients from contracts:

```bash
# TypeScript/JavaScript (using openapi-typescript-codegen)
npx openapi-typescript-codegen \
  --input contracts/api/users.yaml \
  --output apps/dashboard/src/api/generated \
  --client axios

# Or using openapi-generator
npx @openapitools/openapi-generator-cli generate \
  -i contracts/api/users.yaml \
  -g typescript-fetch \
  -o apps/dashboard/src/api/generated
```

### Mocking Responses

Frontend can mock API responses during development:

```bash
# Using Prism (Stoplight)
npx @stoplight/prism-cli mock contracts/api/users.yaml

# Starts mock server at http://localhost:4010
```

## Event Schemas

For async communication (message queues, event buses), use JSON Schema:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://example.com/schemas/user-created.json",
  "title": "UserCreated",
  "description": "Event emitted when a new user is created",
  "type": "object",
  "required": ["eventId", "timestamp", "data"],
  "properties": {
    "eventId": {
      "type": "string",
      "format": "uuid"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time"
    },
    "data": {
      "type": "object",
      "required": ["userId", "email"],
      "properties": {
        "userId": { "type": "integer" },
        "email": { "type": "string", "format": "email" }
      }
    }
  }
}
```

## Contract Versioning

Contracts follow semantic versioning in the `info.version` field:

| Change | Version Bump | Example |
|--------|--------------|---------|
| Add optional field | Patch | 1.0.0 → 1.0.1 |
| Add new endpoint | Minor | 1.0.1 → 1.1.0 |
| Remove/rename field | Major | 1.1.0 → 2.0.0 |
| Change field type | Major | 1.1.0 → 2.0.0 |

## CI Validation

Add contract validation to your CI pipeline:

```yaml
# In ci-pr.yml, add a job to validate contracts
validate-contracts:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    - name: Validate OpenAPI specs
      run: |
        npx @redocly/cli lint contracts/api/*.yaml

    - name: Check breaking changes
      run: |
        # Compare against main branch
        npx oasdiff breaking \
          "https://raw.githubusercontent.com/${{ github.repository }}/main/contracts/api/api.yaml" \
          contracts/api/api.yaml
```

## Best Practices

1. **Contract First** — Always create/update contract before implementation
2. **Small PRs** — Contract PR separate from implementation PR
3. **Review Contracts** — Contracts affect multiple teams, review carefully
4. **Don't Break Contracts** — Use versioning, deprecation, not removal
5. **Generate, Don't Handwrite** — Generate clients from contracts to ensure compatibility
6. **Test Against Contract** — Use contract testing tools (Pact, Dredd, Schemathesis)
