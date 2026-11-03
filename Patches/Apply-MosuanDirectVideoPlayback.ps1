$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.Core'
$path = Join-Path $root 'ViewModels\PlayerPageViewModel.cs'
if (!(Test-Path $path)) { throw "Player view model not found: $path" }

$source = Get-Content -Raw -Encoding UTF8 $path
$old = 'bool shouldBeVisible = _settingsService.PlayerAutoResize == PlayerAutoResizeOption.Always && !AudioOnly;'
$new = 'bool shouldBeVisible = !AudioOnly || _settingsService.PlayerAutoResize == PlayerAutoResizeOption.Always;'

if (!$source.Contains($new) -and !$source.Contains('bool shouldBeVisible = !AudioOnly;')) {
    if (!$source.Contains($old)) { throw 'Direct video playback anchor not found in PlayerPageViewModel.' }
    $source = $source.Replace($old, $new)
}

Set-Content -Path $path -Value $source -Encoding UTF8
Write-Host 'Mosuan direct video playback applied: selecting a video opens the full player view instead of the bottom mini-player.'
