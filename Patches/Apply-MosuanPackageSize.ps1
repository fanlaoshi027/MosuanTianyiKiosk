$ErrorActionPreference = 'Stop'

$projectPath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Screenbox.csproj'
if (!(Test-Path $projectPath)) { throw "Screenbox project not found: $projectPath" }

$project = Get-Content -Raw -Encoding UTF8 $projectPath

# The target is Windows 10 x64. Do not create an x86/ARM64 MSIX bundle.
$bundlePattern = '<AppxBundle>\s*Always\s*</AppxBundle>'
if ($project -match $bundlePattern) {
    $project = [regex]::Replace($project, $bundlePattern, '<AppxBundle>Never</AppxBundle>', 1)
} elseif ($project -notmatch '<AppxBundle>\s*Never\s*</AppxBundle>') {
    throw 'AppxBundle property anchor not found; refusing to guess.'
}

$platformPattern = '<AppxBundlePlatforms>.*?</AppxBundlePlatforms>'
if ($project -match $platformPattern) {
    $project = [regex]::Replace($project, $platformPattern, '<AppxBundlePlatforms>x64</AppxBundlePlatforms>', 1)
} else {
    $project = $project.Replace(
        '<AppxBundle>Never</AppxBundle>',
        '<AppxBundle>Never</AppxBundle>' + [Environment]::NewLine + '    <AppxBundlePlatforms>x64</AppxBundlePlatforms>'
    )
}

# Keep release AOT and omit optional test/install artifacts from the package build.
if ($project -notmatch '<PublishAot>\s*true\s*</PublishAot>') {
    throw 'PublishAot is not enabled; check project configuration before changing package settings.'
}
$project = [regex]::Replace($project, '<GenerateTestArtifacts>\s*True\s*</GenerateTestArtifacts>', '<GenerateTestArtifacts>False</GenerateTestArtifacts>', 1)

Set-Content -Path $projectPath -Value $project -Encoding UTF8
Write-Host 'Mosuan package size profile applied: x64 only, no multi-architecture MSIX bundle, Release AOT retained.'
