$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox'
$app = Join-Path $root 'Screenbox\App.xaml.cs'
$player = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'

if (!(Test-Path $app)) { throw "Screenbox App.xaml.cs not found: $app" }
if (!(Test-Path $player)) { throw "Screenbox PlayerPage.xaml not found: $player" }

$appText = Get-Content -Raw -Encoding UTF8 $app
$darkLine = '        RequestedTheme = ApplicationTheme.Dark;'
if ($appText -notmatch 'RequestedTheme\s*=\s*ApplicationTheme\.Dark') {
    $needle = "        InitializeComponent();"
    if (!$appText.Contains($needle)) { throw 'InitializeComponent() anchor not found in App.xaml.cs' }
    $appText = $appText.Replace($needle, "$needle`r`n`r`n$darkLine")
    Set-Content -Path $app -Value $appText -Encoding UTF8
}

$playerText = Get-Content -Raw -Encoding UTF8 $player
$playerText = $playerText.Replace('TintColor="#202020"', 'TintColor="#0B0D10"')
$playerText = $playerText.Replace('FallbackColor="#2C2C2C"', 'FallbackColor="#101318"')
$playerText = $playerText.Replace('TintOpacity="0.5"', 'TintOpacity="0.72"')

# Keep the non-video area clean and dark instead of showing album-art wallpaper.
if ($playerText -notmatch 'x:Name="MosuanPlayerBackground"') {
    $anchor = '<Grid\n        x:Name="LayoutRoot"'
    $playerText = $playerText.Replace($anchor, '<Grid\n        x:Name="MosuanPlayerBackground"\n        Background="#090A0C">\n        <Grid\n            x:Name="LayoutRoot"')
    # Close the wrapper immediately before the final Page closing tag.
    $last = $playerText.LastIndexOf('</Grid>')
    if ($last -gt 0) {
        $playerText = $playerText.Substring(0, $last) + '</Grid>`r`n</Grid>' + $playerText.Substring($last + 7)
    }
}

Set-Content -Path $player -Value $playerText -Encoding UTF8
Write-Host 'Mosuan player theme patch applied.'