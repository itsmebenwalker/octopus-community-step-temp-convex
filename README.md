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

---

## Setup

### 1. Prerequisites

- **Node.js 18+** — check with `node --version`
- **An Octopus Deploy instance** — [sign up](https://octopus.com/start) or use an existing server
- **A Convex account** — [sign up free at convex.dev](https://dashboard.convex.dev)

### 2. Clone and install

```bash
git clone https://github.com/itsmebenwalker/octopus-community-step-temp-convex.git
cd octopus-community-step-temp-convex/sample-app
npm install
```

### 3. Create a Convex project

If you don't already have a Convex project:

1. Go to [dashboard.convex.dev](https://dashboard.convex.dev) and sign in
2. Click **New project**, give it a name (e.g. `octopus-test`)
3. Run `npx convex dev` from `sample-app/` — this links the local project to your Convex deployment and generates the `convex/_generated/` files

```bash
cd sample-app
npx convex dev
# Follow the prompts to log in and select your project
# Press Ctrl+C once it's linked — you don't need it running
```

After this you'll have a `convex.json` in `sample-app/` pointing at your deployment.

### 4. Get your deploy key

The Octopus steps authenticate to Convex using a deploy key (not your login credentials).

1. In the [Convex dashboard](https://dashboard.convex.dev), open your project
2. Go to **Settings → URL & Deploy Key**
3. Copy the **Deploy key** value — it starts with `prod:`

Or generate one from the CLI:

```bash
npx convex deployment token --prod
```

Keep this value — you'll need it in step 6.

### 5. Find your deployment URL

On the same **Settings → URL & Deploy Key** page, copy the **HTTP Actions URL** — it looks like:

```
https://happy-animal-123.convex.site
```

You'll need this for the Smoke Test step.

### 6. Add variables in Octopus

In your Octopus project, go to **Variables** and add:

| Variable name | Value | Type |
|---|---|---|
| `Convex.DeployKey` | The deploy key from step 4 | **Sensitive** |
| `Convex.DeploymentUrl` | Your `.convex.site` URL from step 5 | Text |

### 7. Import the step templates

Repeat for each of the five JSON files in `docs/`:

1. In the Octopus Web Portal go to **Library → Step Templates**
2. Click **Import** (top right of the custom templates section)
3. Open one of the JSON files, copy all the contents, paste into the import dialog
4. Click **Save**

The template will appear in the step picker when you add steps to a deployment process.

### 8. Set up the deployment process

In your Octopus project, go to **Deployments → Process → Add Step** and add the five steps in this order:

**Step 1 — Convex - Set Environment Variables**

| Parameter | Value |
|---|---|
| Deploy Key | `#{Convex.DeployKey}` |
| Deployment Type | `prod` |
| Environment Variables | `MY_TEST_VAR=hello_from_octopus` |

**Step 2 — Convex - Export Data** *(pre-deploy backup)*

| Parameter | Value |
|---|---|
| Deploy Key | `#{Convex.DeployKey}` |
| Deployment Type | `prod` |
| Capture as Artifact | `True` |

**Step 3 — Convex - Deploy**

| Parameter | Value |
|---|---|
| Deploy Key | `#{Convex.DeployKey}` |
| Deployment Type | `prod` |
| Working Directory | `sample-app` |

**Step 4 — Convex - Run Function** *(post-deploy seed)*

| Parameter | Value |
|---|---|
| Deploy Key | `#{Convex.DeployKey}` |
| Function Path | `migrations:seedTasks` |
| Deployment Type | `prod` |
| Working Directory | `sample-app` |

**Step 5 — Convex - Smoke Test HTTP Action**

| Parameter | Value |
|---|---|
| Deployment URL | `#{Convex.DeploymentUrl}` |
| Action Path | `/health` |
| Expected Status Code | `200` |
| Response Body Assertion | `"status":"ok"` |

### 9. Create a release and deploy

1. Go to **Deployments → Releases → Create Release**
2. Click **Deploy** to your target environment
3. Watch the task log — each step should print a success message
4. After the run, check the **Artifacts** tab for the export ZIP from Step 2

---

## Testing Steps Locally

You can verify each step's underlying CLI commands work before wiring them into Octopus.

### Convex - Deploy

```bash
export CONVEX_DEPLOY_KEY="prod:your-key-here"
cd sample-app
npx convex deploy --yes
# Look for: "Convex deployment completed successfully."
```

### Convex - Set Environment Variables

```bash
export CONVEX_DEPLOY_KEY="prod:your-key-here"
cd sample-app
npx convex env set --prod MY_TEST_VAR hello_world
npx convex env list --prod
# MY_TEST_VAR should appear in the list
```

### Convex - Run Function

```bash
export CONVEX_DEPLOY_KEY="prod:your-key-here"
cd sample-app
# Health check query
npx convex run --prod healthcheck:ping
# Expected: { status: "ok", timestamp: 1234567890 }

# Seed mutation (idempotent — safe to run multiple times)
npx convex run --prod migrations:seedTasks
# Expected: { seeded: true, message: "Seeded 3 tasks." }
# Second run: { seeded: false, message: "Tasks already exist, skipping seed." }
```

### Convex - Export Data

```bash
export CONVEX_DEPLOY_KEY="prod:your-key-here"
cd sample-app
npx convex export --prod --path ./test-export.zip
ls -lh test-export.zip
# Should show a non-zero size ZIP
```

### Convex - Smoke Test HTTP Action

```bash
# Replace with your actual .convex.site URL
curl -s https://happy-animal-123.convex.site/health
# Expected: {"status":"ok"}
```

---

## See Also

- [Octopus Community Library](https://library.octopus.com)
- [Convex CLI docs](https://docs.convex.dev/cli)
- [Convex HTTP actions](https://docs.convex.dev/functions/http-actions)
- [Convex dashboard](https://dashboard.convex.dev)
