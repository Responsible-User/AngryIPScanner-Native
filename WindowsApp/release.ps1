# Release build script for Go Network Scanner (Windows)
#
# Produces self-contained release zips for both arm64 and amd64:
#   release/GoNetworkScanner-<version>-win-x64.zip
#   release/GoNetworkScanner-<version>-win-arm64.zip
#
# Self-contained means users don't need to install .NET 10 --
# the runtime ships inside the zip. The trade-off is ~90 MB per arch.
#
# Prerequisites:
#   - Go 1.21+ with CGO
#   - .NET 10 SDK
#   - LLVM-MinGW (both aarch64 and x86_64 cross-compilers in PATH).
#     If you installed MartinStorsjo.LLVM-MinGW.UCRT via winget, the
#     cross-compilers live under
#     %LOCALAPPDATA%\Microsoft\WinGet\Packages\MartinStorsjo.LLVM-MinGW.*\
#     and should already be on PATH after a shell restart.

param(
    [string]$Config = "Release",
    [string[]]$Arches = @("x64", "arm64")
)

$ErrorActionPreference = "Stop"

$version    = "1.0.0"
$projectDir = "$PSScriptRoot\GoNetworkScanner"
$releaseDir = "$PSScriptRoot\release"
$csproj     = "$projectDir\GoNetworkScanner.csproj"
$libDir     = "$PSScriptRoot\..\libipscan"

Write-Host ""
Write-Host "=== Go Network Scanner Release Build ===" -ForegroundColor Cyan
Write-Host "  Version:  $version"
Write-Host "  Config:   $Config"
Write-Host "  Arches:   $($Arches -join ', ')"
Write-Host ""

if (Test-Path $releaseDir) { Remove-Item -Recurse -Force $releaseDir }
New-Item -ItemType Directory -Path $releaseDir | Out-Null

foreach ($arch in $Arches) {
    Write-Host ""
    Write-Host "=== [$arch] ===" -ForegroundColor Cyan

    $goArch = if ($arch -eq "x64") { "amd64" } else { "arm64" }
    $cgoCC  = if ($arch -eq "x64") { "x86_64-w64-mingw32-gcc" } else { "aarch64-w64-mingw32-gcc" }

    # Step 1: Cross-compile Go DLL
    Write-Host "[1/3] Building libipscan.dll (GOARCH=$goArch, CC=$cgoCC)..." -ForegroundColor Yellow
    Push-Location $libDir
    try {
        $env:GOARCH      = $goArch
        $env:GOOS        = "windows"
        $env:CGO_ENABLED = "1"
        $env:CC          = $cgoCC
        go build -buildmode=c-shared -o "$projectDir\libipscan.dll"
        if ($LASTEXITCODE -ne 0) { throw "Go build failed for $arch" }
    } finally {
        Pop-Location
    }

    # Step 2: dotnet publish (self-contained, runtime baked in)
    $stageDir = "$releaseDir\GoNetworkScanner-win-$arch"
    Write-Host "[2/3] Publishing .NET app to $stageDir..." -ForegroundColor Yellow
    dotnet publish $csproj `
        -c $Config `
        -r "win-$arch" `
        --self-contained true `
        -p:PublishReadyToRun=true `
        -p:DebugType=None `
        -p:DebugSymbols=false `
        -o $stageDir `
        --nologo `
        -v minimal
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $arch" }

    # The Content entry in the csproj copies libipscan.dll next to the exe,
    # but only if it was present when dotnet publish ran -- make sure.
    if (-not (Test-Path "$stageDir\libipscan.dll")) {
        Copy-Item "$projectDir\libipscan.dll" "$stageDir\libipscan.dll" -Force
    }

    # Step 3: zip for distribution
    $zipPath = "$releaseDir\GoNetworkScanner-$version-win-$arch.zip"
    Write-Host "[3/3] Packaging $zipPath..." -ForegroundColor Yellow
    if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
    Compress-Archive -Path "$stageDir\*" -DestinationPath $zipPath

    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Host ("  OK: {0} ({1} MB)" -f $zipPath, $zipSize) -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Release complete ===" -ForegroundColor Green
Get-ChildItem "$releaseDir\*.zip" | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 1)
    Write-Host ("  {0,-50} {1,6} MB" -f $_.Name, $mb)
}
