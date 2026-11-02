$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox'
$viewModelPath = Join-Path $root 'Screenbox.Core\ViewModels\PlayerPageViewModel.cs'
if (!(Test-Path $viewModelPath)) { throw "Player page view model not found: $viewModelPath" }

$source = Get-Content -Raw -Encoding UTF8 $viewModelPath
$old = 'bool shouldBeVisible = _settingsService.PlayerAutoResize == PlayerAutoResizeOption.Always && !AudioOnly;'
$new = 'bool shouldBeVisible = !AudioOnly; // Video playback opens the full player; audio keeps the compact player.'

if ($source.Contains($new)) {
    Write-Host 'Mosuan open-player behavior already applied.'
}
elseif ($source.Contains($old)) {
    $source = $source.Replace($old, $new)
    Set-Content -Path $viewModelPath -Value $source -Encoding UTF8
    Write-Host 'Mosuan open-player behavior applied: selecting a video opens the full player.'
}
else {
    throw 'Player visibility decision anchor not found; refusing to patch an unexpected implementation.'
}
