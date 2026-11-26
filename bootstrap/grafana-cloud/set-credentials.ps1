$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found in PATH.'
}

$context = kubectl config current-context
if ($LASTEXITCODE -ne 0 -or -not $context) {
    throw 'A current kubectl context is required.'
}
Write-Host "Using Kubernetes context: $context"

$namespace = kubectl get namespace monitoring --ignore-not-found -o name
if ($LASTEXITCODE -ne 0) {
    throw 'Could not check for the monitoring namespace.'
}
if (-not $namespace) {
    kubectl create namespace monitoring
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl failed to create the monitoring namespace.'
    }
}

$existingSecret = kubectl get secret grafana-cloud-credentials -n monitoring --ignore-not-found -o name
if ($LASTEXITCODE -ne 0) {
    throw 'Could not check for an existing Grafana Cloud credentials Secret.'
}
if ($existingSecret) {
    throw 'The Grafana Cloud credentials Secret already exists; refusing to replace it.'
}

$secureToken = Read-Host 'Grafana Cloud access policy token (metrics:read, set:alloy-data-write)' -AsSecureString
if ($secureToken.Length -eq 0) {
    $secureToken.Dispose()
    throw 'Grafana Cloud access policy token cannot be empty.'
}

$pointer = [IntPtr]::Zero
$token = $null
$encodedToken = $null
$manifest = $null
try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    $encodedToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($token))
    $manifest = @{
        apiVersion = 'v1'
        kind = 'Secret'
        metadata = @{
            name = 'grafana-cloud-credentials'
            namespace = 'monitoring'
        }
        type = 'Opaque'
        data = @{
            username = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('1210959'))
            password = $encodedToken
        }
    } | ConvertTo-Json -Depth 4

    $manifest | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl failed to apply the Grafana Cloud credentials Secret.'
    }
}
finally {
    if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    $secureToken.Dispose()
    $token = $null
    $encodedToken = $null
    $manifest = $null
}
