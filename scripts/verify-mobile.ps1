$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $root 'apps\mobile'
$flutter = Join-Path $PSScriptRoot 'flutter.ps1'

Push-Location $mobile
try {
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $flutter test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $flutter build web --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $flutter build apk --debug
    exit $LASTEXITCODE
} finally {
    Pop-Location
}

