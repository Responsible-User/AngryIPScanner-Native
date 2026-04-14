# Build script for Go Network Scanner (Windows)
# Usage:
#   .\build.ps1                    # Build for current architecture
#   .\build.ps1 -Arch x64         # Build for x64
#   .\build.ps1 -Arch arm64       # Build for ARM64
#   .\build.ps1 -Config Debug     # Debug build
#
# Prerequisites:
#   - Go 1.21+ with CGO support
#   - .NET 10 SDK
#   - C compiler for CGO (MinGW-w64 GCC; LLVM-MinGW recommended on arm64)

param(
    [ValidateSet("x64", "arm64")]
    [string]$Arch = "",
    [ValidateSet("Debug", "Release")]
    [string]$Config = "Release"
)

$ErrorActionPreference = "Stop"

# Auto-detect architecture if not specified
if (-not $Arch) {
    $Arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture) {
        "X64"   { "x64" }
        "Arm64" { "arm64" }
        default { "x64" }
    }
}

$goArch = switch ($Arch) {
    "x64"   { "amd64" }
    "arm64" { "arm64" }
}

Write-Host "=== Go Network Scanner Windows Build ===" -ForegroundColor Cyan
Write-Host "  Architecture: $Arch (GOARCH=$goArch)"
Write-Host "  Configuration: $Config"
Write-Host ""

$outDir = "$PSScriptRoot\GoNetworkScanner\bin\$Config\net10.0-windows"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Step 1: Build Go shared library
Write-Host "[1/2] Building libipscan.dll..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\libipscan"
try {
    $env:GOARCH = $goArch
    $env:GOOS = "windows"
    $env:CGO_ENABLED = "1"
    # Drop the DLL next to the project so .NET's Content include picks it up,
    # and also into the build output so the app is runnable immediately.
    go build -buildmode=c-shared -o "$PSScriptRoot\GoNetworkScanner\libipscan.dll"
    if ($LASTEXITCODE -ne 0) { throw "Go build failed" }
    Copy-Item "$PSScriptRoot\GoNetworkScanner\libipscan.dll" "$outDir\libipscan.dll" -Force
    Write-Host "  libipscan.dll built successfully" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 2: Build .NET WPF application
Write-Host "[2/2] Building GoNetworkScanner.exe..." -ForegroundColor Yellow
dotnet build "$PSScriptRoot\GoNetworkScanner\GoNetworkScanner.csproj" -c $Config
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Output: WindowsApp\GoNetworkScanner\bin\$Config\net10.0-windows\"
