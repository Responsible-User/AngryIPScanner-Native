# Tag the HEAD commit and publish the Windows release to GitHub.
# Run this after: gh auth login --hostname github.com --web

$ErrorActionPreference = "Stop"
$tag      = "v1.0.0-win-alpha"
$title    = "v1.0.0-win-alpha - Windows alpha (untested)"
$repo     = "Responsible-User/GoNetworkScanner"
$repoRoot = "C:\Users\JacobBraun.AzureAD\AngryIPScanner-Native"
$notes    = "$repoRoot\WindowsApp\RELEASE_NOTES.md"

Push-Location $repoRoot
try {
    # Annotated tag on current HEAD
    & 'C:\Program Files\Git\bin\git.exe' tag -a $tag -m "Windows 1.0.0 alpha"
    & 'C:\Program Files\Git\bin\git.exe' push origin $tag

    # Create release with all four artifacts
    $assets = @(
        "$repoRoot\WindowsApp\release\GoNetworkScanner-1.0.0-win-x64.zip",
        "$repoRoot\WindowsApp\release\GoNetworkScanner-1.0.0-win-arm64.zip",
        "$repoRoot\WindowsApp\release\GoNetworkScanner-Setup-1.0.0-win-x64.exe",
        "$repoRoot\WindowsApp\release\GoNetworkScanner-Setup-1.0.0-win-arm64.exe"
    )

    gh release create $tag `
        --repo $repo `
        --title $title `
        --notes-file $notes `
        --prerelease `
        $assets
} finally {
    Pop-Location
}
