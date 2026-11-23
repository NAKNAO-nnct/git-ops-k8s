$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found in PATH.'
}

$secureSecret = Read-Host 'GitHub OAuth client secret' -AsSecureString
if ($secureSecret.Length -eq 0) {
    throw 'GitHub OAuth client secret cannot be empty.'
}

$pointer = [IntPtr]::Zero
$clientSecret = $null
$encodedSecret = $null
try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
    $clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    $encodedSecret = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($clientSecret))
    $manifest = @{
        apiVersion = 'v1'
        kind = 'Secret'
        metadata = @{
            name = 'argocd-github-sso'
            namespace = 'argocd'
            labels = @{
                'app.kubernetes.io/part-of' = 'argocd'
            }
        }
        type = 'Opaque'
        data = @{
            'dex.github.clientSecret' = $encodedSecret
        }
    } | ConvertTo-Json -Depth 5

    $manifest | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl failed to apply the GitHub OAuth Secret.'
    }
}
finally {
    if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    $secureSecret.Dispose()
    $clientSecret = $null
    $encodedSecret = $null
    $manifest = $null
}
