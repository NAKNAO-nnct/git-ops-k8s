$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found in PATH.'
}

$secureToken = Read-Host 'Cloudflare Tunnel token' -AsSecureString
if ($secureToken.Length -eq 0) {
    throw 'Tunnel token cannot be empty.'
}

$pointer = [IntPtr]::Zero
$token = $null
$encodedToken = $null
try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    $encodedToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($token))
    $manifest = @{
        apiVersion = 'v1'
        kind = 'Secret'
        metadata = @{
            name = 'cloudflared'
            namespace = 'cloudflare-tunnel'
        }
        type = 'Opaque'
        data = @{
            TUNNEL_TOKEN = $encodedToken
        }
    } | ConvertTo-Json -Depth 4

    $manifest | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl failed to apply the Cloudflare Tunnel Secret.'
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
