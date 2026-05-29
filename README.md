# Octopus Deploy Community Step Templates — Convex

Sample project for testing the five [Octopus Deploy](https://octopus.com) community step templates for [Convex](https://convex.dev).

## Step Templates

| File | Template | What it tests |
|------|----------|---------------|
| `docs/convex-deploy.json` | Convex - Deploy | Deploys functions and schema via `npx convex deploy` |
| `docs/convex-set-environment-variables.json` | Convex - Set Environment Variables | Pushes key/value pairs to a Convex deployment's runtime env |
| `docs/convex-run-function.json` | Convex - Run Function | Invokes a Convex mutation, action, or query |
| `docs/convex-export-data.json` | Convex - Export Data | Snapshots deployment data to a ZIP file |
| `docs/convex-smoke-test-http-action.json` | Convex - Smoke Test HTTP Action | Hits an HTTP action endpoint and validates the response |

## Sample App

The `sample-app/` directory contains a minimal Convex project wired up for all five steps:

```
sample-app/
├── package.json
└── convex/
    ├── schema.ts        # tasks table
    ├── healthcheck.ts   # healthcheck:ping query  → used by Convex - Run Function
    ├── http.ts          # GET /health route        → used by Convex - Smoke Test HTTP Action
    └── migrations.ts    # migrations:seedTasks     → used by Convex - Run Function
```

## Prerequisites

- Node.js 18+
- An [Octopus Deploy](https://octopus.com) instance
- A Convex account and project — [get started](https://docs.convex.dev/get-started)
- A Convex deploy key — generate one with `npx convex deployment token --prod` and store it as a sensitive Octopus variable (e.g. `Convex.DeployKey`)

## Setup

```bash
cd sample-app
npm install
# Link to your Convex project (run once):
npx convex dev
```

## Importing Step Templates

1. In the Octopus Web Portal go to **Library → Step Templates**
2. Click **Import** in the custom step templates section
3. Paste the contents of a JSON file from `docs/` and click **Save**

## Recommended Pipeline

Use all five steps in this order for a full Convex deployment pipeline:

```
Step 1: Convex - Set Environment Variables   (sync secrets pre-deploy)
         ConvexEnvSet.DeployKey      = #{Convex.DeployKey}
         ConvexEnvSet.EnvironmentVariables = MY_VAR=#{Project.MyVar}

Step 2: Convex - Export Data                 (backup before touching prod)
         ConvexExport.DeployKey      = #{Convex.DeployKey}
         ConvexExport.CaptureAsArtifact = True

Step 3: Convex - Deploy                      (push functions + schema)
         ConvexDeploy.DeployKey      = #{Convex.DeployKey}
         ConvexDeploy.WorkingDirectory = sample-app

Step 4: Convex - Run Function                (run migrations / seed data)
         ConvexRun.DeployKey         = #{Convex.DeployKey}
         ConvexRun.FunctionPath      = migrations:seedTasks
         ConvexRun.WorkingDirectory  = sample-app

Step 5: Convex - Smoke Test HTTP Action      (verify deployment is healthy)
         ConvexSmokeTest.DeploymentUrl = https://your-deployment.convex.site
         ConvexSmokeTest.ActionPath    = /health
         ConvexSmokeTest.ResponseBodyAssertion = "status":"ok"
```

## Testing Individual Steps

### Convex - Deploy

```bash
export CONVEX_DEPLOY_KEY="your-deploy-key"
cd sample-app
npx convex deploy --yes
```

### Convex - Set Environment Variables

```bash
export CONVEX_DEPLOY_KEY="your-deploy-key"
cd sample-app
npx convex env set --prod MY_TEST_VAR hello_world
npx convex env list --prod
```

### Convex - Run Function

```bash
export CONVEX_DEPLOY_KEY="your-deploy-key"
cd sample-app
npx convex run --prod healthcheck:ping
# Expected: { status: "ok", timestamp: ... }

npx convex run --prod migrations:seedTasks
# Expected: { seeded: true, message: "Seeded 3 tasks." }
```

### Convex - Export Data

```bash
export CONVEX_DEPLOY_KEY="your-deploy-key"
cd sample-app
npx convex export --prod --path ./test-export.zip
ls -lh test-export.zip
```

### Convex - Smoke Test HTTP Action

```bash
# After deploying, find your .convex.site URL in the Convex dashboard
curl https://your-deployment.convex.site/health
# Expected: {"status":"ok"}
```

## See Also

- [Octopus Community Library](https://library.octopus.com)
- [Convex CLI docs](https://docs.convex.dev/cli)
- [Convex HTTP actions](https://docs.convex.dev/functions/http-actions)
