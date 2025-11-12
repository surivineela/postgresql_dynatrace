# Azure Developer CLI Deployment Script
# This script automates the deployment of Octopets using azd

Write-Host "🚀 Octopets Deployment with Azure Developer CLI" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check azd
try {
    $azdVersion = azd version 2>&1 | Select-String -Pattern "azd version"
    Write-Host "✅ Azure Developer CLI: $azdVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure Developer CLI not found. Please install: https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd" -ForegroundColor Red
    exit 1
}

# Check Azure CLI
try {
    $azVersion = az version --query '\"azure-cli\"' -o tsv
    Write-Host "✅ Azure CLI: $azVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI not found. Please install: https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Red
    exit 1
}

# Check Docker
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker not found or not running. Please install Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All prerequisites met! ✅" -ForegroundColor Green
Write-Host ""

# Prompt for deployment type
Write-Host "Select deployment type:" -ForegroundColor Cyan
Write-Host "1. Basic deployment (without Dynatrace monitoring)"
Write-Host "2. Full deployment (with Dynatrace monitoring)"
Write-Host ""
$deployType = Read-Host "Enter choice (1 or 2)"

if ($deployType -eq "2") {
    Write-Host ""
    Write-Host "Dynatrace Configuration" -ForegroundColor Cyan
    Write-Host "You'll need the following from your Dynatrace environment:" -ForegroundColor Yellow
    Write-Host "1. Environment ID (e.g., abc12345.apps.dynatrace.com)"
    Write-Host "2. API Token with 'openTelemetryTrace.ingest' permission"
    Write-Host "3. Application ID for RUM (e.g., OCTOPETS_FRONTEND)"
    Write-Host ""
    
    $dynatraceEnvId = Read-Host "Enter Dynatrace Environment ID"
    $dynatraceToken = Read-Host "Enter Dynatrace API Token" -AsSecureString
    $dynatraceTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($dynatraceToken))
    $dynatraceAppId = Read-Host "Enter Dynatrace Application ID (default: OCTOPETS_FRONTEND)"
    
    if ([string]::IsNullOrWhiteSpace($dynatraceAppId)) {
        $dynatraceAppId = "OCTOPETS_FRONTEND"
    }
    
    # Set environment variables
    azd env set ENABLE_DYNATRACE true
    azd env set DYNATRACE_ENVIRONMENT_ID $dynatraceEnvId
    azd env set DYNATRACE_API_TOKEN $dynatraceTokenPlain
    azd env set DYNATRACE_APP_ID $dynatraceAppId
    
    Write-Host "✅ Dynatrace configuration set" -ForegroundColor Green
}

Write-Host ""
Write-Host "Starting deployment..." -ForegroundColor Cyan
Write-Host "This will:"
Write-Host "  1. Provision Azure resources (Container Apps, PostgreSQL, etc.)"
Write-Host "  2. Build Docker images for frontend and backend"
Write-Host "  3. Push images to Azure Container Registry"
Write-Host "  4. Deploy containers to Azure Container Apps"
Write-Host ""
Write-Host "This may take 10-15 minutes..." -ForegroundColor Yellow
Write-Host ""

# Run azd up
azd up

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. View your application: azd show"
    Write-Host "2. Check logs: az containerapp logs show --name <app-name> --resource-group <rg-name> --follow"
    if ($deployType -eq "2") {
        Write-Host "3. View Dynatrace monitoring: https://$dynatraceEnvId"
    }
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed. Check the logs above for details." -ForegroundColor Red
    Write-Host "For troubleshooting, see: AZD_DEPLOYMENT_GUIDE.md" -ForegroundColor Yellow
    exit 1
}
