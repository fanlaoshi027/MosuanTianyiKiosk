$ErrorActionPreference = 'Stop'
$controlsPath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Controls\PlayerControls.xaml'
if (!(Test-Path $controlsPath)) { throw "Player controls file not found: $controlsPath" }

$xaml = Get-Content -Raw -Encoding UTF8 $controlsPath

# Give the seek area more breathing room while retaining its existing behavior.
$xaml = $xaml.Replace('Margin="16,0"', 'Margin="16,0,16,8"')

# Separate the two control groups visually without changing their commands,
# bindings, visibility states, or keyboard accelerators.
$primary = '<Grid Grid.Row="1" Grid.Column="0">'
if (!$xaml.Contains($primary)) { throw 'Primary control group anchor not found' }
$xaml = $xaml.Replace($primary, '<Grid Grid.Row="1" Grid.Column="0" Margin="4,0,8,2">')

$secondary = '            Grid.Row="1"' + [Environment]::NewLine + '            Grid.Column="1"' + [Environment]::NewLine + '            HorizontalAlignment="Right"'
if (!$xaml.Contains($secondary)) { throw 'Secondary control group anchor not found' }
$xaml = $xaml.Replace(
    $secondary,
    '            Grid.Row="1"' + [Environment]::NewLine + '            Grid.Column="1"' + [Environment]::NewLine + '            Margin="8,0,4,2"' + [Environment]::NewLine + '            HorizontalAlignment="Right"'
)

Set-Content -Path $controlsPath -Value $xaml -Encoding UTF8
Write-Host 'Mosuan player control bar polish applied.'
