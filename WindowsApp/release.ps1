# Release build script for Go Network Scanner (Windows)
#
# Produces four release artifacts, two per architecture:
#
#   release/GoNetworkScanner-<version>-win-x64.zip       (portable, ~5 MB, needs .NET 10)
#   release/GoNetworkScanner-<version>-win-arm64.zip     (portable, ~5 MB, needs .NET 10)
#   release/GoNetworkScanner-Setup-<version>-win-x64.exe  (installer, handles .NET)
#   release/GoNetworkScanner-Setup-<version>-win-arm64.exe
#
# Both the portable zip and the installer ship the same framework-dependent
# build. End users without .NET 10 can either:
#   - install the runtime themselves (portable zip), or
#   - run the installer which prompts them to download it.
#
# Prerequisites:
#   - Go 1.21+ with CGO
#   - .NET 10 SDK
#   - LLVM-MinGW cross-compilers on PATH (aarch64 + x86_64)
#   - Inno Setup 6 (ISCC.exe) -- installed via: winget install JRSoftware.InnoSetup

param(
    [string]$Config = "Release",
    [string[]]$Arches = @("x64", "arm64"),
    [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"

$version    = "1.0.0"
$projectDir = "$PSScriptRoot\GoNetworkScanner"
$releaseDir = "$PSScriptRoot\release"
$csproj     = "$projectDir\GoNetworkScanner.csproj"
$libDir     = "$PSScriptRoot\..\libipscan"
$issFile    = "$PSScriptRoot\installer.iss"

# Locate ISCC.exe
$iscc = $null
foreach ($candidate in @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)) {
    if (Test-Path $candidate) { $iscc = $candidate; break }
}
if (-not $SkipInstaller -and -not $iscc) {
    Write-Warning "ISCC.exe not found. Install Inno Setup: winget install JRSoftware.InnoSetup"
    Write-Warning "Skipping installer build -- pass -SkipInstaller to silence this."
    $SkipInstaller = $true
}

Write-Host ""
Write-Host "=== Go Network Scanner Release Build ===" -ForegroundColor Cyan
Write-Host "  Version:   $version"
Write-Host "  Config:    $Config"
Write-Host "  Arches:    $($Arches -join ', ')"
Write-Host "  Installer: $(if ($SkipInstaller) { 'skipped' } else { $iscc })"
Write-Host ""

if (Test-Path $releaseDir) { Remove-Item -Recurse -Force $releaseDir }
New-Item -ItemType Directory -Path $releaseDir | Out-Null

foreach ($arch in $Arches) {
    Write-Host ""
    Write-Host "=== [$arch] ===" -ForegroundColor Cyan

    $goArch = if ($arch -eq "x64") { "amd64" } else { "arm64" }
    $cgoCC  = if ($arch -eq "x64") { "x86_64-w64-mingw32-gcc" } else { "aarch64-w64-mingw32-gcc" }

    # --- Step 1: Cross-compile Go DLL ----------------------------------------
    Write-Host "[1/4] Building libipscan.dll (GOARCH=$goArch)..." -ForegroundColor Yellow
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

    # --- Step 2: Publish framework-dependent build ---------------------------
    $stageDir = "$releaseDir\fxdep-win-$arch"
    Write-Host "[2/4] Publishing framework-dependent build -> $stageDir..." -ForegroundColor Yellow
    dotnet publish $csproj `
        -c $Config `
        -r "win-$arch" `
        --self-contained false `
        -p:DebugType=None `
        -p:DebugSymbols=false `
        -o $stageDir `
        --nologo `
        -v minimal
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $arch" }

    # Ensure libipscan.dll is co-located with the exe
    if (-not (Test-Path "$stageDir\libipscan.dll")) {
        Copy-Item "$projectDir\libipscan.dll" "$stageDir\libipscan.dll" -Force
    }

    # --- Step 3: Portable zip (for users who already have .NET 10) -----------
    $zipPath = "$releaseDir\GoNetworkScanner-$version-win-$arch.zip"
    Write-Host "[3/4] Packaging portable zip: $(Split-Path $zipPath -Leaf)..." -ForegroundColor Yellow
    if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
    Compress-Archive -Path "$stageDir\*" -DestinationPath $zipPath
    $zipMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Host ("      OK: {0} MB" -f $zipMB) -ForegroundColor Green

    # --- Step 4: Installer (Inno Setup) --------------------------------------
    if ($SkipInstaller) {
        Write-Host "[4/4] Installer skipped" -ForegroundColor DarkGray
        continue
    }

    Write-Host "[4/4] Building installer with Inno Setup..." -ForegroundColor Yellow
    & $iscc `
        "/DAppVersion=$version" `
        "/DArch=$arch" `
        "/Q" `
        $issFile
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed for $arch" }

    $installerPath = "$releaseDir\GoNetworkScanner-Setup-$version-win-$arch.exe"
    if (Test-Path $installerPath) {
        $installerMB = [math]::Round((Get-Item $installerPath).Length / 1MB, 1)
        Write-Host ("      OK: {0} MB" -f $installerMB) -ForegroundColor Green
    }
}

# --- Summary -----------------------------------------------------------------
Write-Host ""
Write-Host "=== Release complete ===" -ForegroundColor Green
Get-ChildItem $releaseDir -File | Sort-Object Name | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 2)
    Write-Host ("  {0,-55} {1,7} MB" -f $_.Name, $mb)
}
