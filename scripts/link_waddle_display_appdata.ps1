# Creates .local/waddle-display-appdata -> OS application-support dir for waddle_display.
# VS Code/Cursor do not expand ${env:...} in multi-root workspace folder paths.
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$LinkPath = Join-Path $RepoRoot '.local\waddle-display-appdata'
$TargetPath = Join-Path $env:APPDATA 'com.waddleview\waddle_display'

if (-not (Test-Path $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Write-Host "Created display data directory: $TargetPath"
}

$LocalDir = Split-Path -Parent $LinkPath
if (-not (Test-Path $LocalDir)) {
    New-Item -ItemType Directory -Path $LocalDir -Force | Out-Null
}

if (Test-Path $LinkPath) {
    $item = Get-Item -LiteralPath $LinkPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "Junction already exists: $LinkPath -> $($item.Target)"
        exit 0
    }
    throw "Refusing to overwrite non-junction path: $LinkPath"
}

New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
Write-Host "Linked $LinkPath -> $TargetPath"
