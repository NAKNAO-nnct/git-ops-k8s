$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found in PATH.'
}

$secureTeamSlug = Read-Host 'GitHub admin team slug' -AsSecureString
if ($secureTeamSlug.Length -eq 0) {
    throw 'GitHub admin team slug cannot be empty.'
}

$pointer = [IntPtr]::Zero
$teamSlug = $null
$manifest = $null
try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureTeamSlug)
    $teamSlug = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ($teamSlug -notmatch '^[a-z0-9][a-z0-9-]*$') {
        throw 'GitHub admin team slug has an unsupported format.'
    }

    $manifest = @{
        apiVersion = 'v1'
        kind = 'ConfigMap'
        metadata = @{
            name = 'argocd-rbac-cm'
            namespace = 'argocd'
            labels = @{
                'app.kubernetes.io/name' = 'argocd-rbac-cm'
                'app.kubernetes.io/part-of' = 'argocd'
            }
        }
        data = @{
            'policy.default' = 'role:readonly'
            'policy.csv' = "g, Yamada-Factory:$teamSlug, role:admin"
            scopes = '[groups]'
        }
    } | ConvertTo-Json -Depth 5

    $manifest | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl failed to apply the GitHub admin team mapping.'
    }
}
finally {
    if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    $secureTeamSlug.Dispose()
    $teamSlug = $null
    $manifest = $null
}
