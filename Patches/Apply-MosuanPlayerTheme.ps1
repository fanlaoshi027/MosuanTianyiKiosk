$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox'
$app = Join-Path $root 'Screenbox\App.xaml.cs'
$player = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'

if (!(Test-Path $app)) { throw "Screenbox App.xaml.cs not found: $app" }
if (!(Test-Path $player)) { throw "Screenbox PlayerPage.xaml not found: $player" }

# Force the application chrome into a consistent dark theme.
$appText = Get-Content -Raw -Encoding UTF8 $app
if ($appText -notmatch 'RequestedTheme\s*=\s*ApplicationTheme\.Dark') {
    $needle = '        InitializeComponent();'
    if (!$appText.Contains($needle)) { throw 'InitializeComponent() anchor not found in App.xaml.cs' }
    $appText = $appText.Replace($needle, "$needle`r`n`r`n        RequestedTheme = ApplicationTheme.Dark;")
    Set-Content -Path $app -Value $appText -Encoding UTF8
}

# Make the player backdrop darker and prevent album-art wallpaper from competing with video.
$playerText = Get-Content -Raw -Encoding UTF8 $player
$playerText = $playerText.Replace('FallbackColor="#2C2C2C"', 'FallbackColor="#101318"')
$playerText = $playerText.Replace('TintColor="#202020"', 'TintColor="#0B0D10"')
$playerText = $playerText.Replace('TintOpacity="0.5"', 'TintOpacity="0.72"')

if ($playerText -notmatch 'x:Name="MosuanPlayerBackgroundMarker"') {
    $playerText = $playerText.Replace('x:Name="LayoutRoot"', 'x:Name="LayoutRoot"\n        x:Name="MosuanPlayerBackgroundMarker"')
}

# Hide the large album-art backdrop. The video surface remains untouched.
$playerText = [regex]::Replace(
    $playerText,
    '(?s)(<Grid\s+x:Name="BackgroundElement"[^>]*)(>)',
    '$1 Visibility="Collapsed"$2',
    1
)

Set-Content -Path $player -Value $playerText -Encoding UTF8
Write-Host 'Mosuan player theme patch applied.'