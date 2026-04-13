# Build script for Angry IP Scanner (Windows)
# Usage:
#   .\build.ps1                    # Build for current architecture
#   .\build.ps1 -Arch x64         # Build for x64
#   .\build.ps1 -Arch arm64       # Build for ARM64
#   .\build.ps1 -Config Debug     # Debug build
#
# Prerequisites:
#   - Go 1.21+ with CGO support
#   - .NET 10 SDK
#   - C compiler for CGO (MinGW-w64 GCC recommended)

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

Write-Host "=== Angry IP Scanner Windows Build ===" -ForegroundColor Cyan
Write-Host "  Architecture: $Arch (GOARCH=$goArch)"
Write-Host "  Configuration: $Config"
Write-Host ""

# Step 1: Build Go shared library
Write-Host "[1/2] Building libipscan.dll..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\libipscan"
try {
    $env:GOARCH = $goArch
    $env:GOOS = "windows"
    $env:CGO_ENABLED = "1"
    go build -buildmode=c-shared -o "$PSScriptRoot\AngryIPScanner\libipscan.dll"
    if ($LASTEXITCODE -ne 0) { throw "Go build failed" }
    Write-Host "  libipscan.dll built successfully" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 2: Build .NET WPF application
Write-Host "[2/2] Building AngryIPScanner.exe..." -ForegroundColor Yellow
dotnet build "$PSScriptRoot\AngryIPScanner\AngryIPScanner.csproj" -c $Config
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Output: WindowsApp\AngryIPScanner\bin\$Config\net10.0-windows\"
