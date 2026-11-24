$ErrorActionPreference = 'Stop'

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl was not found in PATH.'
}

$namespace = kubectl get namespace mattermost -o name
if ($LASTEXITCODE -ne 0) {
    throw 'The mattermost namespace does not exist.'
}

$existingSecret = kubectl get secret mattermost-db -n mattermost --ignore-not-found -o name
if ($LASTEXITCODE -ne 0) {
    throw 'Could not check for an existing Mattermost database Secret.'
}
if ($existingSecret) {
    throw 'The Mattermost database Secret already exists; refusing to replace credentials.'
}

$random = [Security.Cryptography.RandomNumberGenerator]::Create()
$postgresBytes = [byte[]]::new(32)
$mattermostBytes = [byte[]]::new(32)
$postgresPassword = $null
$mattermostPassword = $null
$manifest = $null
try {
    $random.GetBytes($postgresBytes)
    $random.GetBytes($mattermostBytes)
    $postgresPassword = [BitConverter]::ToString($postgresBytes).Replace('-', '').ToLowerInvariant()
    $mattermostPassword = [BitConverter]::ToString($mattermostBytes).Replace('-', '').ToLowerInvariant()

    $manifest = @{
        apiVersion = 'v1'
        kind = 'Secret'
        metadata = @{
            name = 'mattermost-db'
            namespace = 'mattermost'
        }
        type = 'Opaque'
        stringData = @{
            POSTGRES_PASSWORD = $postgresPassword
            MATTERMOST_DB_PASSWORD = $mattermostPassword
        }
    } | ConvertTo-Json -Depth 4

    $manifest | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl failed to apply the Mattermost database Secret.'
    }
}
finally {
    $random.Dispose()
    [Array]::Clear($postgresBytes, 0, $postgresBytes.Length)
    [Array]::Clear($mattermostBytes, 0, $mattermostBytes.Length)
    $postgresPassword = $null
    $mattermostPassword = $null
    $manifest = $null
}
