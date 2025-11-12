# 🚀 Quick Deployment with Azure Developer CLI (azd)

This guide simplifies the deployment of Octopets to Azure Container Apps using a single command.

## Prerequisites

1. **Azure Developer CLI (azd)**: [Install azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
2. **Azure CLI**: [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
3. **Docker Desktop**: [Install Docker](https://www.docker.com/products/docker-desktop/)
4. **Azure Subscription**: Active Azure subscription

## One-Command Deployment

### Basic Deployment (Without Dynatrace)

```bash
# Login to Azure
azd auth login

# Deploy everything with one command
azd up
```

That's it! 🎉 The `azd up` command will:
1. ✅ Prompt for configuration (subscription, location, database password)
2. ✅ Provision all Azure resources (Container Apps, PostgreSQL, Monitoring)
3. ✅ Build Docker images for frontend and backend
4. ✅ Push images to Azure Container Registry
5. ✅ Deploy containers to Azure Container Apps
6. ✅ Display the application URL

### Deployment with Dynatrace Monitoring

If you want to enable Dynatrace monitoring:

```bash
# Set Dynatrace configuration
azd env set ENABLE_DYNATRACE true
azd env set DYNATRACE_ENVIRONMENT_ID "your-env-id.apps.dynatrace.com"
azd env set DYNATRACE_API_TOKEN "dt0c01.XXXXXXXX"
azd env set DYNATRACE_APP_ID "OCTOPETS_FRONTEND"

# Deploy
azd up
```

## What Gets Deployed?

### Azure Resources Created

| Resource | Purpose | SKU/Tier |
|----------|---------|----------|
| **Container Apps Environment** | Hosts frontend & backend | Consumption |
| **Frontend Container App** | React web application | 0.5 CPU, 1GB RAM |
| **Backend Container App** | .NET API service | 0.5 CPU, 1GB RAM |
| **PostgreSQL Flexible Server** | Database | Standard_B1ms |
| **Container Registry** | Docker images | Basic |
| **Log Analytics Workspace** | Logs & monitoring | PerGB2018 |
| **Application Insights** | Telemetry | Web |

### Monitoring Features

- **Backend Monitoring**: OpenTelemetry → Dynatrace OTLP (optional)
- **Frontend Monitoring**: Dynatrace Real User Monitoring (optional)
- **Database Monitoring**: PostgreSQL logs → Log Analytics
- **Application Logs**: Container Apps logs → Log Analytics

## Common Commands

```bash
# View deployed application
azd show

# View environment variables
azd env get-values

# Deploy infrastructure only
azd provision

# Deploy code only (skip infrastructure)
azd deploy

# View application logs
az containerapp logs show --name <app-name> --resource-group <rg-name> --follow

# Tear down everything
azd down
```

## Configuration

### Required Parameters (Prompted during `azd up`)

- **AZURE_SUBSCRIPTION_ID**: Your Azure subscription
- **AZURE_LOCATION**: Azure region (default: swedencentral)
- **DB_ADMIN_PASSWORD**: PostgreSQL administrator password (secure)

### Optional Dynatrace Parameters

Set these before running `azd up` to enable monitoring:

```bash
azd env set ENABLE_DYNATRACE true
azd env set DYNATRACE_ENVIRONMENT_ID "abc12345.apps.dynatrace.com"
azd env set DYNATRACE_API_TOKEN "dt0c01.YOUR_API_TOKEN"
azd env set DYNATRACE_APP_ID "OCTOPETS_FRONTEND"
```

## Environment File

You can also edit `.azure/octopets-prod/.env` directly:

```env
AZURE_ENV_NAME="octopets-prod"
AZURE_LOCATION="swedencentral"
AZURE_SUBSCRIPTION_ID="your-subscription-id"

DB_ADMIN_LOGIN="octopetsadmin"
DB_ADMIN_PASSWORD="YourSecurePassword123!"

# Optional: Enable Dynatrace
ENABLE_DYNATRACE="true"
DYNATRACE_ENVIRONMENT_ID="abc12345.apps.dynatrace.com"
DYNATRACE_API_TOKEN="dt0c01.XXXXXXXX"
DYNATRACE_APP_ID="OCTOPETS_FRONTEND"
```

## Troubleshooting

### Docker Not Running
```bash
# Start Docker Desktop first
# Then retry: azd up
```

### Permission Issues
```bash
# Re-authenticate
azd auth login
az login
```

### View Deployment Logs
```bash
# Check provision logs
azd provision --debug

# Check Azure deployment
az deployment group list --resource-group rg-octopets-prod
```

### Database Connection Issues
```bash
# Verify firewall rules allow Azure services
az postgres flexible-server firewall-rule list \
  --resource-group rg-octopets-prod \
  --name <postgres-server-name>
```

## Updating the Application

After making code changes:

```bash
# Redeploy just the code (faster)
azd deploy

# Or full redeploy
azd up
```

## Cost Estimation

Approximate monthly costs (pay-as-you-go):

- Container Apps (2 apps): ~$30-50/month
- PostgreSQL Burstable: ~$15-20/month
- Container Registry (Basic): ~$5/month
- Log Analytics: ~$5-15/month (depends on usage)

**Total**: ~$55-90/month

## Security Best Practices

✅ Database password stored as azd environment secret  
✅ Dynatrace API token stored as Container App secret  
✅ Container Registry uses admin credentials (managed)  
✅ PostgreSQL requires SSL connections  
✅ Container Apps use HTTPS ingress  

## Next Steps

1. **View your application**: Check the URL printed by `azd up`
2. **Monitor logs**: Use Azure Portal or `az containerapp logs`
3. **Check Dynatrace**: View traces at `https://{your-env-id}.apps.dynatrace.com`
4. **Query database logs**: Use Log Analytics workspace

## Comparison: Before vs After

### Before (Manual Deployment)
```bash
# 1. Create resource group
az group create ...

# 2. Deploy infrastructure
az deployment group create ...

# 3. Build backend image
cd backend
docker build ...
docker push ...

# 4. Build frontend image
cd frontend
docker build ...
docker push ...

# 5. Update container apps
az containerapp update ...

# 6. Configure secrets
az containerapp secret set ...

# Total: ~15-20 commands, 30+ minutes
```

### After (azd)
```bash
azd up

# Total: 1 command, ~5-10 minutes
```

## Learn More

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Dynatrace OpenTelemetry Integration](https://www.dynatrace.com/support/help/extend-dynatrace/opentelemetry)
