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

# Mosuan custom player identity: deep-sea navy surfaces with a restrained orange accent.
# Apply to the immersive player chrome only; do not place any visual effect over the video surface.
$playerText = $playerText.Replace(
    '<Color x:Key="BackgroundAcrylicTintColor">#202020</Color>',
    '<Color x:Key="BackgroundAcrylicTintColor">#101B2B</Color>'
)
$playerText = $playerText.Replace(
    '<Color x:Key="BackgroundAcrylicTintFallbackColor">#2C2C2C</Color>',
    '<Color x:Key="BackgroundAcrylicTintFallbackColor">#101B2B</Color>'
)
$playerText = $playerText.Replace(
    '<GradientStop Offset="0" Color="{StaticResource SystemAltMediumColor}" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="0.5" Color="{StaticResource SystemAltLowColor}" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="1" Color="#00000000" />',
    '<GradientStop Offset="0" Color="#F20B1422" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="0.55" Color="#B8101B2D" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="1" Color="#00101B2B" />'
)
$playerText = $playerText.Replace(
    '<GradientStop Offset="0" Color="#00000000" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="1" Color="{StaticResource SystemAltMediumColor}" />',
    '<GradientStop Offset="0" Color="#FFFF8A32" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="0.018" Color="#FFFF8A32" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="0.035" Color="#E6101B2D" />' + [Environment]::NewLine +
    '                            <GradientStop Offset="1" Color="#F20A1220" />'
)

# Add a restrained Mosuan brand marker above the current media title.
if ($playerText -notmatch 'x:Name="MosuanBrandLabel"') {
    $brandAnchor = '                    <TextBlock' + [Environment]::NewLine + '                        x:Name="TitleBarTitleTextBlock"'
    if (!$playerText.Contains($brandAnchor)) { throw 'Could not find player title text anchor for Mosuan branding.' }
    $brand = @'
                    <TextBlock
                        x:Name="MosuanBrandLabel"
                        Margin="0,0,0,2"
                        FontSize="10"
                        FontWeight="SemiBold"
                        CharacterSpacing="180"
                        Foreground="#FFFF9A52"
                        Text="MOSUAN  /  VIDEO STUDIO" />
'@
    $playerText = $playerText.Replace($brandAnchor, $brand + $brandAnchor)
}

# Hide the large album-art backdrop. The video surface remains untouched.
if ($playerText -notmatch 'x:Name="BackgroundElement"[^>]*Visibility="Collapsed"') {
    $playerText = [regex]::Replace(
        $playerText,
        '(?s)(<Grid\s+x:Name="BackgroundElement"[^>]*)(>)',
        '$1 Visibility="Collapsed"$2',
        1
    )
}

Set-Content -Path $player -Value $playerText -Encoding UTF8
Write-Host 'Mosuan player theme patch applied.'