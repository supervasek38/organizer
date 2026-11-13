param([string]$Flutter = 'flutter', [switch]$NoPub)
$ErrorActionPreference = 'Stop'
$orgRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
Push-Location -LiteralPath (Join-Path $orgRoot 'app')
try {
    if (-not $NoPub) {
        & $Flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    }
    & $Flutter build web --release --no-pub --no-web-resources-cdn --base-href /organizer/
    if ($LASTEXITCODE -ne 0) { throw 'Build failed; site has not been replaced.' }
    $orgBuilt = Join-Path $orgRoot 'app\build\web'
    $orgHtml = Get-Content -Raw -LiteralPath (Join-Path $orgBuilt 'index.html')
    if (-not $orgHtml.Contains('<base href="/organizer/">')) { throw 'Unexpected base href.' }
    $orgSite = [IO.Path]::GetFullPath((Join-Path $orgRoot 'site'))
    if ((Split-Path -Parent $orgSite) -ne $orgRoot -or (Split-Path -Leaf $orgSite) -ne 'site') { throw 'Unsafe site path.' }
    if (Test-Path -LiteralPath $orgSite) {
        $orgEntries = @((Get-Item -LiteralPath $orgSite)) + @(Get-ChildItem -LiteralPath $orgSite -Recurse -Force)
        if ($orgEntries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Site contains a link; export stopped.' }
        Remove-Item -LiteralPath $orgSite -Recurse -Force
    }
    New-Item -ItemType Directory -Path $orgSite | Out-Null
    Get-ChildItem -LiteralPath $orgBuilt -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $orgSite -Recurse -Force }
    Write-Host 'Organizer built from app/ and exported to site/.'
} finally { Pop-Location }
