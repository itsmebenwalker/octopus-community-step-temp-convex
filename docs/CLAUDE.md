# CLAUDE.md — Convex Dev: Octopus Deploy Community Step Templates

## Overview

This spec covers the implementation and testing of five Octopus Deploy community step templates for [Convex Dev](https://docs.convex.dev). Each template is a JSON file (Apache 2.0 licensed) intended for submission to the [Octopus Community Library](https://library.octopus.com) via a PR to [OctopusDeploy/Library](https://github.com/OctopusDeploy/Library).

All five templates are script-based (`ActionType: "Octopus.Script"`) using Bash, wrapping the Convex CLI (`npx convex`). Node.js and npx must be available on the worker/agent executing the step.

---

## Files

| File | Template Name |
|------|---------------|
| `convex-deploy.json` | Convex - Deploy |
| `convex-set-environment-variables.json` | Convex - Set Environment Variables |
| `convex-run-function.json` | Convex - Run Function |
| `convex-export-data.json` | Convex - Export Data |
| `convex-smoke-test-http-action.json` | Convex - Smoke Test HTTP Action |

---

## Pre-requisites

Before importing or testing any template:

- Node.js (18+) and npx available on the Octopus worker
- A Convex project set up and authenticated (`npx convex dev` run at least once)
- A Convex deploy key — generate one with:
  ```bash
  npx convex deployment token --prod
  ```
  Store it as a **sensitive** Octopus variable (e.g. `Convex.DeployKey`)
- The Convex CLI version should be recent — templates use `npx convex@latest` style invocation

---

## Importing Templates into Octopus

1. In the Octopus Web Portal, go to **Library → Step Templates**
2. Click **Import** in the custom step templates section
3. Paste the contents of the JSON file and click **Save**
4. The template will appear alongside built-in step templates when adding steps to a deployment process

---

## Template 1: Convex - Deploy

**File:** `convex-deploy.json`

**Purpose:** Deploys Convex backend functions and schema to a target deployment using `npx convex deploy`.

### Parameters

| Parameter | Required | Notes |
|-----------|----------|-------|
| `ConvexDeploy.DeployKey` | Yes | Sensitive. Passed as `CONVEX_DEPLOY_KEY` env var |
| `ConvexDeploy.DeploymentType` | Yes | `prod`, `preview`, or `dev`. Defaults to `prod` |
| `ConvexDeploy.PreviewName` | Conditional | Required when `DeploymentType` is `preview` |
| `ConvexDeploy.WorkingDirectory` | No | Defaults to CWD if blank |
| `ConvexDeploy.CommandTimeout` | No | Defaults to 300 seconds |

### How it works

Sets `CONVEX_DEPLOY_KEY` in the environment, then calls `npx convex deploy --yes` with the appropriate deployment flag. The `--yes` flag suppresses interactive prompts, making it CI-safe.

### Testing

**Manual (local) test:**
```bash
export CONVEX_DEPLOY_KEY="your-deploy-key-here"
cd /path/to/your/convex/project
npx convex deploy --yes
```
Confirm the deployment appears in your Convex dashboard under the target deployment.

**In Octopus:**
1. Add the step to a test project's deployment process
2. Set `ConvexDeploy.DeployKey` as a sensitive project variable
3. Set `ConvexDeploy.DeploymentType` to `dev` for initial testing (avoids touching prod)
4. Run a deployment and check the task log for `Convex deployment completed successfully.`
5. Confirm functions appear updated in the Convex dashboard

**Error scenarios to verify:**
- Missing deploy key → should fail with `ERROR: ConvexDeploy.DeployKey is required.`
- Invalid deploy key → Convex CLI will return a non-zero exit code; step should fail accordingly
- `preview` type with no preview name → should fail with a clear error message
- Bad working directory → should fail with `ERROR: Could not change to directory`

---

## Template 2: Convex - Set Environment Variables

**File:** `convex-set-environment-variables.json`

**Purpose:** Pushes key/value pairs to a Convex deployment's runtime environment using `npx convex env set`. Run this before or after a deploy to sync secrets from Octopus into Convex.

### Parameters

| Parameter | Required | Notes |
|-----------|----------|-------|
| `ConvexEnvSet.DeployKey` | Yes | Sensitive |
| `ConvexEnvSet.EnvironmentVariables` | Yes | Newline-delimited `KEY=VALUE` pairs. Supports Octopus variable substitution (`#{VarName}`) |
| `ConvexEnvSet.DeploymentType` | Yes | `prod`, `preview`, or `dev`. Defaults to `prod` |
| `ConvexEnvSet.PreviewName` | Conditional | Required when type is `preview` |
| `ConvexEnvSet.WorkingDirectory` | No | Defaults to CWD |

### Format for EnvironmentVariables

```
NEXT_PUBLIC_API_URL=https://api.example.com
SENDGRID_API_KEY=#{Octopus.SendGridApiKey}
# This line is a comment and will be skipped
```

Blank lines and lines starting with `#` are ignored. Malformed entries (no `=`) log a warning and are skipped.

### How it works

Iterates over each `KEY=VALUE` pair and calls `npx convex env set [--prod|--preview-name X] KEY VALUE`. Reports a count of successes and failures; exits non-zero if any variable fails to set.

### Testing

**Manual (local) test:**
```bash
export CONVEX_DEPLOY_KEY="your-deploy-key-here"
cd /path/to/your/convex/project
npx convex env set --prod MY_TEST_VAR hello_world
# Verify with:
npx convex env list --prod
```

**In Octopus:**
1. Add the step to a deployment process (run before the Deploy step)
2. Set `ConvexEnvSet.EnvironmentVariables` to a multi-line variable value:
   ```
   MY_TEST_VAR=hello
   ANOTHER_VAR=#{Project.SomeSecret}
   ```
3. Run a deployment and check the task log — each variable should log `Setting: KEY_NAME`
4. After the run, verify in the Convex dashboard under **Settings → Environment Variables**

**Error scenarios to verify:**
- Malformed line (e.g. `NODELSIGN`) → warning logged, line skipped, step continues
- A variable that Convex rejects → that variable increments `failCount`, step exits non-zero at the end
- Empty `EnvironmentVariables` → step fails immediately with a clear error

---

## Template 3: Convex - Run Function

**File:** `convex-run-function.json`

**Purpose:** Invokes a Convex mutation, action, or query against a deployment using `npx convex run`. Use this for post-deploy migrations, data seeding, or running smoke-test queries as part of a pipeline.

### Parameters

| Parameter | Required | Notes |
|-----------|----------|-------|
| `ConvexRun.DeployKey` | Yes | Sensitive |
| `ConvexRun.FunctionPath` | Yes | Format: `module:functionName` e.g. `migrations:runV2` |
| `ConvexRun.FunctionArgs` | No | JSON object string. e.g. `{"dryRun": false}` |
| `ConvexRun.DeploymentType` | Yes | `prod`, `preview`, or `dev`. Defaults to `prod` |
| `ConvexRun.PreviewName` | Conditional | Required when type is `preview` |
| `ConvexRun.WorkingDirectory` | No | Defaults to CWD |
| `ConvexRun.CommandTimeout` | No | Defaults to 120 seconds |

### How it works

Calls `npx convex run [--prod] <functionPath> [args]`. If `FunctionArgs` is provided it is passed as a positional argument — ensure it is valid JSON. The step exits non-zero if the function fails.

### Testing

**Manual (local) test — create a simple test function first:**
```typescript
// convex/healthcheck.ts
import { query } from "./_generated/server";

export const ping = query({
  args: {},
  handler: async () => {
    return { status: "ok", timestamp: Date.now() };
  },
});
```
Then test:
```bash
export CONVEX_DEPLOY_KEY="your-deploy-key-here"
cd /path/to/your/convex/project
npx convex run --prod healthcheck:ping
# Should return: { status: "ok", timestamp: 1234567890 }
```

**Testing with args:**
```bash
npx convex run --prod migrations:runV2 '{"dryRun": true}'
```

**In Octopus:**
1. Add the step after the Deploy step in a deployment process
2. Set `ConvexRun.FunctionPath` to `healthcheck:ping` (or an equivalent function in your project)
3. Run the deployment — the task log should show the function's return value
4. For migration functions, check that the migration completed in your Convex dashboard

**Error scenarios to verify:**
- Non-existent function path → Convex CLI returns non-zero; step fails
- Invalid JSON in args → Convex CLI will reject; step fails with the CLI error output
- Timeout exceeded → `timeout` command kills the process; step exits with code 124

---

## Template 4: Convex - Export Data

**File:** `convex-export-data.json`

**Purpose:** Snapshots a Convex deployment's data to a local ZIP file using `npx convex export`. Designed to run before a production deployment as a rollback safety net. Optionally captures the file as an Octopus artifact.

### Parameters

| Parameter | Required | Notes |
|-----------|----------|-------|
| `ConvexExport.DeployKey` | Yes | Sensitive |
| `ConvexExport.OutputPath` | No | Defaults to `convex-export-{timestamp}.zip` in CWD |
| `ConvexExport.DeploymentType` | Yes | `prod`, `preview`, or `dev`. Defaults to `prod` |
| `ConvexExport.PreviewName` | Conditional | Required when type is `preview` |
| `ConvexExport.WorkingDirectory` | No | Defaults to CWD |
| `ConvexExport.CaptureAsArtifact` | No | Checkbox. Defaults to `True` |
| `ConvexExport.CommandTimeout` | No | Defaults to 600 seconds. Large datasets may need more |

### How it works

Calls `npx convex export [--prod] --path <outputPath>`. After a successful export, verifies the file exists on disk. If `CaptureAsArtifact` is enabled, emits the `##octopus[createArtifact]` service message so the ZIP appears in the Octopus deployment artifact list.

### Testing

**Manual (local) test:**
```bash
export CONVEX_DEPLOY_KEY="your-deploy-key-here"
cd /path/to/your/convex/project
npx convex export --prod --path ./test-export.zip
ls -lh test-export.zip
# Should show a non-zero size ZIP file
```

**In Octopus:**
1. Add this step **before** the Deploy step (it's a pre-deploy backup)
2. Set `ConvexExport.CaptureAsArtifact` to `True`
3. Run a deployment — check the task log for file size confirmation
4. In the deployment details, check the **Artifacts** tab — the export ZIP should appear for download
5. Unzip the export locally and verify it contains your table data

**Error scenarios to verify:**
- Missing deploy key → fails immediately
- Export path in a directory that doesn't exist → `npx convex export` will fail; step exits non-zero
- Output file not found after export command → step fails with `Export completed but output file not found`
- Timeout on a large dataset → increase `CommandTimeout` parameter

---

## Template 5: Convex - Smoke Test HTTP Action

**File:** `convex-smoke-test-http-action.json`

**Purpose:** Hits a Convex HTTP action endpoint post-deploy and validates the response status code and optionally the response body. Retries on failure with configurable delay. Use this as the final gate in a deployment process to catch unhealthy deployments before they reach users.

### Parameters

| Parameter | Required | Notes |
|-----------|----------|-------|
| `ConvexSmokeTest.DeploymentUrl` | Yes | Base URL e.g. `https://happy-animal-123.convex.site` |
| `ConvexSmokeTest.ActionPath` | Yes | e.g. `/health` or `/api/ping`. Defaults to `/health` |
| `ConvexSmokeTest.HttpMethod` | No | `GET`, `POST`, `PUT`, `DELETE`. Defaults to `GET` |
| `ConvexSmokeTest.ExpectedStatusCode` | No | Defaults to `200` |
| `ConvexSmokeTest.ResponseBodyAssertion` | No | String that must appear in response body |
| `ConvexSmokeTest.RequestBody` | No | JSON body for POST/PUT requests |
| `ConvexSmokeTest.MaxRetries` | No | Defaults to `3` |
| `ConvexSmokeTest.RetryDelay` | No | Seconds between retries. Defaults to `5` |
| `ConvexSmokeTest.CurlTimeout` | No | Per-request curl timeout. Defaults to `30` |

### How it works

Uses `curl` to hit `{DeploymentUrl}/{ActionPath}`. On each attempt, checks the HTTP status code against `ExpectedStatusCode`. If `ResponseBodyAssertion` is set, also checks that the string appears in the response body using `grep -qF`. Retries up to `MaxRetries` times with `RetryDelay` seconds between attempts. Fails the step if all attempts are exhausted.

### Required: HTTP action in your Convex project

This template requires a Convex HTTP action to be deployed. Add one to your project:

```typescript
// convex/http.ts
import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";

const http = httpRouter();

http.route({
  path: "/health",
  method: "GET",
  handler: httpAction(async () => {
    return new Response(JSON.stringify({ status: "ok" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }),
});

export default http;
```

Your Convex deployment URL (the `.convex.site` domain) is in the Convex dashboard under **Settings → URL & Deploy Key**.

### Testing

**Manual (local) test:**
```bash
# After deploying your HTTP action:
curl -s -o /tmp/body -w "%{http_code}" \
  https://happy-animal-123.convex.site/health
# Should print 200

cat /tmp/body
# Should print {"status":"ok"}
```

**In Octopus:**
1. Add this step **last** in the deployment process (after Deploy)
2. Set `ConvexSmokeTest.DeploymentUrl` to your `.convex.site` URL
3. Set `ConvexSmokeTest.ActionPath` to `/health`
4. Set `ConvexSmokeTest.ResponseBodyAssertion` to `"status":"ok"` for body validation
5. Run the deployment — the task log should confirm the test passed
6. To test failure handling: temporarily change `ExpectedStatusCode` to `999` — the step should retry 3 times and then fail

**Error scenarios to verify:**
- Wrong status code → retries up to `MaxRetries`, then fails with `Smoke test failed after N attempt(s)`
- Body assertion not found in response → retries, then fails
- Deployment URL unreachable (e.g. curl timeout) → curl exits non-zero; step retries then fails
- All attempts succeed but on the last one → step reports `Smoke test passed`

---

## Recommended Deployment Pipeline Order

For a full Convex pipeline using all five templates:

```
1. Convex - Set Environment Variables   (sync secrets pre-deploy)
2. Convex - Export Data                 (backup before touching prod)
3. Convex - Deploy                      (push functions + schema)
4. Convex - Run Function                (run migrations / seed)
5. Convex - Smoke Test HTTP Action      (verify deployment is healthy)
```

---

## Contributing to the Octopus Library

Once tested, submit via PR to [github.com/OctopusDeploy/Library](https://github.com/OctopusDeploy/Library):

1. Fork the repository
2. Copy JSON files to `/step-templates/`
3. Update `LastModifiedBy` to your GitHub username in each file
4. Update the `Id` field in each file — must be a unique GUID (not all zeros)
5. Verify naming convention matches the library style: `Noun - Verb` in sentence case
6. Submit a pull request — the Octopus team will review and merge

**Before submitting, confirm:**
- Each `Id` is a unique GUID
- `Version` starts at `1`
- Parameter `DefaultValues` are strings or `null` (not numbers or booleans)
- Scripts validate required args and exit with non-zero on failure
- Scripts produce meaningful log output throughout execution
