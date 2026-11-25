$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found in PATH.'
}

$namespace = kubectl get namespace cert-manager -o name
if ($LASTEXITCODE -ne 0 -or -not $namespace) {
    throw 'The cert-manager namespace does not exist. Sync the cert-manager Application first.'
}

$existingSecret = kubectl get secret cloudflare-api-token -n cert-manager --ignore-not-found -o name
if ($LASTEXITCODE -ne 0) {
    throw 'Could not check for an existing Cloudflare API token Secret.'
}
if ($existingSecret) {
    throw 'The Cloudflare API token Secret already exists; refusing to replace it.'
}

$secureToken = Read-Host 'Cloudflare API token' -AsSecureString
if ($secureToken.Length -eq 0) {
    $secureToken.Dispose()
    throw 'Cloudflare API token cannot be empty.'
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
            name = 'cloudflare-api-token'
            namespace = 'cert-manager'
        }
        type = 'Opaque'
        data = @{
            'api-token' = $encodedToken
        }
    } | ConvertTo-Json -Depth 4

    $manifest | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl failed to apply the Cloudflare API token Secret.'
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
