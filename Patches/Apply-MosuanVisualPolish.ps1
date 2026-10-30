$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$playerPage = Join-Path $root 'Pages\PlayerPage.xaml'
$playerControls = Join-Path $root 'Controls\PlayerControls.xaml'
foreach ($path in @($playerPage, $playerControls)) {
    if (!(Test-Path $path)) { throw "Required player UI file not found: $path" }
}

# A focused lesson-player canvas. Keep the existing visual tree, bindings,
# commands, keyboard accelerators and playback state machine untouched.
$player = Get-Content -Raw -Encoding UTF8 $playerPage

$player = $player.Replace(
    '<Color x:Key="BackgroundAcrylicTintColor">#202020</Color>',
    '<Color x:Key="BackgroundAcrylicTintColor">#101318</Color>'
)
$player = $player.Replace(
    '<Color x:Key="BackgroundAcrylicTintFallbackColor">#2C2C2C</Color>',
    '<Color x:Key="BackgroundAcrylicTintFallbackColor">#101318</Color>'
)
$player = $player.Replace(
    '<Color x:Key="BackgroundAcrylicTintColor">#FCFCFC</Color>',
    '<Color x:Key="BackgroundAcrylicTintColor">#101318</Color>'
)
$player = $player.Replace(
    '<Color x:Key="BackgroundAcrylicTintFallbackColor">#F9F9F9</Color>',
    '<Color x:Key="BackgroundAcrylicTintFallbackColor">#101318</Color>'
)
$player = [regex]::Replace(
    $player,
    '<x:Double x:Key="BackgroundAcrylicTintOpacity">[^<]+</x:Double>',
    '<x:Double x:Key="BackgroundAcrylicTintOpacity">0.96</x:Double>'
)

$titleBrush = '<SolidColorBrush x:Key="PlayerTitleBarBackgroundBrush" Color="#151B23" />'
$controlsBrush = '<SolidColorBrush x:Key="PlayerControlsBackgroundBrush" Color="#151B23" />'
$player = [regex]::Replace(
    $player,
    '(?s)<LinearGradientBrush x:Key="PlayerTitleBarBackgroundBrush".*?</LinearGradientBrush>',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $titleBrush },
    2
)
$player = [regex]::Replace(
    $player,
    '(?s)<LinearGradientBrush x:Key="PlayerControlsBackgroundBrush".*?</LinearGradientBrush>',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $controlsBrush },
    2
)

# Solid charcoal canvas, independent from video rendering and the player controls.
if ($player -notmatch '<Grid\s+x:Name="LayoutRoot"[^>]*Background="#101318"') {
    $player = [regex]::Replace(
        $player,
        '(<Grid\s+x:Name="LayoutRoot")',
        '$1 Background="#101318"',
        1
    )
}
$player = $player.Replace('<sbuc:TitleBar' + [Environment]::NewLine + '            x:Name="PlayerTitleBar"' + [Environment]::NewLine + '            MinHeight="80"',
    '<sbuc:TitleBar' + [Environment]::NewLine + '            x:Name="PlayerTitleBar"' + [Environment]::NewLine + '            MinHeight="72"')
$player = $player.Replace('Padding="6,20,6,12" />', 'Padding="18,12,18,16" />')

# Hide the decorative album-art backdrop for a distraction-free lesson canvas.
if ($player -notmatch 'x:Name="BackgroundElement"[^>]*Visibility="Collapsed"') {
    $player = [regex]::Replace(
        $player,
        '(?s)(<Grid\s+x:Name="BackgroundElement"[^>]*)(>)',
        '$1 Visibility="Collapsed"$2',
        1
    )
}
Set-Content -Path $playerPage -Value $player -Encoding UTF8

# Slightly widen the seekbar breathing room without changing its behavior.
$controls = Get-Content -Raw -Encoding UTF8 $playerControls
$controls = $controls.Replace('Margin="12,0"' + [Environment]::NewLine + '            HorizontalAlignment="Stretch"',
    'Margin="16,0"' + [Environment]::NewLine + '            HorizontalAlignment="Stretch"')
Set-Content -Path $playerControls -Value $controls -Encoding UTF8

Write-Host 'Mosuan visual polish v1 applied: charcoal canvas, solid title/control surfaces, calmer spacing.'
