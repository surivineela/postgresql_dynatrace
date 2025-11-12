# Infrastructure Deployment

## Quick Start

### 1. Create Local Parameters File

Copy the template and add your secrets:

```powershell
Copy-Item main.parameters.json main.parameters.local.json
```

### 2. Add Your Dynatrace Token

Edit `main.parameters.local.json` and add your token:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "dynatraceApiToken": {
      "value": "dt0c01.YOUR-ACTUAL-TOKEN-HERE"
    }
  }
}
```

**Note:** `*.local.json` files are gitignored and won't be committed.

### 3. Deploy

Use the deployment script:

```powershell
# From repository root
.\deploy-with-monitoring.ps1 `
  -DynatraceApiToken "dt0c01.YOUR-TOKEN" `
  -DbAdminPassword "YourSecurePassword123!"
```

Or deploy infrastructure directly:

```powershell
az deployment group create `
  --resource-group octopets-prod-rg `
  --template-file infrastructure/main.bicep `
  --parameters infrastructure/main.parameters.local.json `
  --parameters dbAdminPassword='YourPassword123!'
```

## Getting Dynatrace Credentials

1. Log into your Dynatrace environment: `https://{your-env-id}.apps.dynatrace.com`
2. Go to **Settings** → **Integration** → **Dynatrace API**
3. Generate an API token with these scopes:
   - `openTelemetryTrace.ingest`
   - `metrics.ingest`
   - `logs.ingest`
4. Copy the token (starts with `dt0c01.`)

## Security Best Practices

- ✅ Never commit `*.local.json` files
- ✅ Use Azure Key Vault for production secrets
- ✅ Rotate tokens regularly
- ✅ Use environment variables in CI/CD pipelines
