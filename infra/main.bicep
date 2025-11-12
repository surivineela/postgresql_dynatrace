targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters for Dynatrace monitoring
@description('Enable Dynatrace monitoring integration')
param enableDynatrace bool = false

@description('Dynatrace environment ID (e.g., abc12345.live.dynatrace.com)')
param dynatraceEnvironmentId string = ''

@secure()
@description('Dynatrace API token for OTLP ingestion')
param dynatraceApiToken string = ''

@description('Dynatrace Application ID for frontend RUM')
param dynatraceAppId string = 'OCTOPETS_FRONTEND'

// Database parameters
@description('PostgreSQL administrator login name')
param dbAdminLogin string = 'octopetsadmin'

@secure()
@description('PostgreSQL administrator password')
param dbAdminPassword string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'azd-service-category': 'application'
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
  }
}

module containerRegistry './core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    location: location
    tags: tags
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
}

module containerAppsEnvironment './core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    location: location
    tags: tags
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module database './core/database/postgresql-flexible.bicep' = {
  name: 'database'
  scope: rg
  params: {
    location: location
    tags: tags
    name: '${abbrs.dBforPostgreSQLServers}${resourceToken}'
    databaseName: 'octopetsdb'
    adminLogin: dbAdminLogin
    adminPassword: dbAdminPassword
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module backend './core/host/container-app.bicep' = {
  name: 'backend'
  scope: rg
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    name: '${abbrs.appContainerApps}backend-${resourceToken}'
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    imageName: 'octopets-backend:latest'
    targetPort: 8080
    env: [
      {
        name: 'ASPNETCORE_ENVIRONMENT'
        value: 'Production'
      }
      {
        name: 'ConnectionStrings__DefaultConnection'
        value: 'Host=${database.outputs.fqdn};Database=octopetsdb;Username=${dbAdminLogin};Password=${dbAdminPassword};SSL Mode=Require'
      }
      {
        name: 'Dynatrace__OtlpEndpoint'
        value: enableDynatrace ? 'https://${dynatraceEnvironmentId}/api/v2/otlp' : ''
      }
      {
        name: 'Dynatrace__ApiToken'
        secretRef: 'dynatrace-api-token'
      }
      {
        name: 'Dynatrace__ServiceName'
        value: 'octopets-backend'
      }
    ]
    secrets: enableDynatrace ? [
      {
        name: 'dynatrace-api-token'
        value: dynatraceApiToken
      }
    ] : []
  }
}

module frontend './core/host/container-app.bicep' = {
  name: 'frontend'
  scope: rg
  params: {
    location: location
    tags: union(tags, { 'azd-service-name': 'frontend' })
    name: '${abbrs.appContainerApps}frontend-${resourceToken}'
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    imageName: 'octopets-frontend:latest'
    targetPort: 80
    env: [
      {
        name: 'REACT_APP_API_URL'
        value: backend.outputs.uri
      }
      {
        name: 'REACT_APP_DYNATRACE_ENABLED'
        value: enableDynatrace ? 'true' : 'false'
      }
      {
        name: 'REACT_APP_DYNATRACE_ENV_ID'
        value: dynatraceEnvironmentId
      }
      {
        name: 'REACT_APP_DYNATRACE_APP_ID'
        value: dynatraceAppId
      }
      {
        name: 'REACT_APP_DYNATRACE_RUM_SCRIPT'
        value: enableDynatrace ? 'https://${dynatraceEnvironmentId}/api/v2/rum/scriptTag' : ''
      }
    ]
  }
}

output AZURE_LOCATION string = location
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output BACKEND_URI string = backend.outputs.uri
output FRONTEND_URI string = frontend.outputs.uri
output DATABASE_FQDN string = database.outputs.fqdn
