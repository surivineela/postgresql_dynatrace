param([Parameter(Mandatory)][string]$Image)

$ErrorActionPreference = 'Stop'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$network = "octopets-test-$suffix"
$database = "octopets-db-$suffix"
$collector = "octopets-otel-$suffix"
$backend = "octopets-api-$suffix"
$previousPassword = $env:POSTGRES_PASSWORD
$previousConnection = $env:ConnectionStrings__octopetsdb
$env:POSTGRES_PASSWORD = [Guid]::NewGuid().ToString('N')
$env:ConnectionStrings__octopetsdb = "Host=$database;Database=octopets;Username=postgres;Password=$env:POSTGRES_PASSWORD"

function Invoke-Docker {
    & docker @args
    if ($LASTEXITCODE -ne 0) { throw "Docker operation failed: $($args[0])" }
}

function Get-ReadyResponse([string]$Uri, [int]$ExpectedStatus) {
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        try {
            $remainingSeconds = [Math]::Max(1, [int]($deadline - [DateTime]::UtcNow).TotalSeconds)
            $response = Invoke-WebRequest $Uri -SkipHttpErrorCheck -TimeoutSec ([Math]::Min(45, $remainingSeconds))
            if ($response.StatusCode -eq $ExpectedStatus) { return $response }
        }
        catch [System.Net.Http.HttpRequestException] { }
        catch [System.Threading.Tasks.TaskCanceledException] { }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Endpoint did not return expected HTTP $ExpectedStatus"
}

try {
    $null = Invoke-Docker network create $network
    $null = Invoke-Docker run -d --name $database --network $network -e POSTGRES_PASSWORD -e POSTGRES_DB=octopets postgres:16-alpine
    $config = (Resolve-Path "$PSScriptRoot/telemetry-collector.yaml").Path
    $null = Invoke-Docker run -d --name $collector --network $network --mount "type=bind,source=$config,target=/etc/otelcol-contrib/config.yaml,readonly" otel/opentelemetry-collector-contrib:0.145.0
    $null = Invoke-Docker run -d --name $backend --network $network -p '127.0.0.1::8080' `
        -e ASPNETCORE_ENVIRONMENT=Production -e ConnectionStrings__octopetsdb `
        -e "OTEL_EXPORTER_OTLP_ENDPOINT=http://${collector}:4317" -e OTEL_EXPORTER_OTLP_PROTOCOL=grpc `
        -e OTEL_SERVICE_NAME=octopets-telemetry-test $Image
    $container = Invoke-Docker inspect $backend | ConvertFrom-Json
    $port = $container[0].NetworkSettings.Ports.'8080/tcp'[0].HostPort
    $url = "http://127.0.0.1:$port"
    $null = Get-ReadyResponse "$url/health/ready" 200
    $null = Get-ReadyResponse "$url/api/listings" 200
    $null = Invoke-WebRequest "$url/api/listings?secret=test-query-must-not-be-logged" -TimeoutSec 10
    $null = Invoke-WebRequest "$url/health" -TimeoutSec 10
    $null = Invoke-WebRequest "$url/not-a-route-private-marker" -SkipHttpErrorCheck -TimeoutSec 10

    $logs = Invoke-Docker logs $backend 2>&1 | Out-String
    $requestLogs = @($logs -split "`n" | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { }
    } | Where-Object Category -eq 'Octopets.Backend.Requests')
    if (!($requestLogs | Where-Object { $_.State.StatusCode -eq 200 -and $_.State.Route -like '*listings*' })) {
        throw 'Missing structured successful listings request log'
    }
    if (!($requestLogs | Where-Object { $_.State.StatusCode -eq 404 -and $_.State.Route -eq '(unmatched)' })) {
        throw 'Unmatched request was not safely logged as 404'
    }
    if ($requestLogs | Where-Object { $_.State.Route -like '/health*' }) { throw 'Health probe was logged' }
    $serializedRequests = $requestLogs | ConvertTo-Json -Depth 10
    if ($serializedRequests -match 'test-query-must-not-be-logged|not-a-route-private-marker|Password=') {
        throw 'Request log leaked a raw URL or credential'
    }
    if ($requestLogs | Where-Object { $_.State.TraceId -notmatch '^[a-f0-9]{32}$' }) {
        throw 'Request log is missing a correlated W3C trace ID'
    }

    # Graceful shutdown flushes trace batches before inspecting collector output.
    $null = Invoke-Docker stop --time 20 $backend
    $null = Invoke-Docker stop --time 20 $collector
    $traceLogs = Invoke-Docker logs $collector 2>&1 | Out-String
    if ($traceLogs -notmatch 'Npgsql') { throw 'No PostgreSQL tracing scope reached the OTLP collector' }
    if ($traceLogs -notmatch 'Trace ID') { throw 'No actual trace reached the OTLP collector' }

    $null = Invoke-Docker stop $database
    $null = Invoke-Docker start $backend
    $container = Invoke-Docker inspect $backend | ConvertFrom-Json
    $port = $container[0].NetworkSettings.Ports.'8080/tcp'[0].HostPort
    $url = "http://127.0.0.1:$port"
    $response = Get-ReadyResponse "$url/health/ready" 503
    if ($response.Content -match 'Password=|Host=|Exception|StackTrace') {
        throw 'Unavailable readiness response leaked internal connection details'
    }
    Write-Output 'PASS: listings 200; structured status/duration/trace ID; safe unmatched 404; no probe/raw URL/credential logs; Npgsql spans exported; unavailable DB readiness 503.'
}
finally {
    foreach ($containerName in @($backend, $collector, $database)) {
        $null = docker rm -f $containerName 2>$null
    }
    $null = docker network rm $network 2>$null
    $env:POSTGRES_PASSWORD = $previousPassword
    $env:ConnectionStrings__octopetsdb = $previousConnection
}