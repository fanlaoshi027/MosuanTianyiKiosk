$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$mainPath = Join-Path $root 'Pages\MainPage.xaml'
$homePath = Join-Path $root 'Pages\HomePage.xaml'

foreach ($path in @($mainPath, $homePath)) {
    if (!(Test-Path $path)) { throw "Required shell UI file not found: $path" }
}

# Main shell: charcoal content canvas and a slightly lighter navigation pane.
$main = Get-Content -Raw -Encoding UTF8 $mainPath
if (!$main.Contains('<Grid Background="#101318">')) {
    $mainAnchor = '    <Grid>' + [Environment]::NewLine + '        <sbuc:TitleBar'
    if (!$main.Contains($mainAnchor)) { throw 'MainPage root Grid anchor not found' }
    $main = $main.Replace($mainAnchor, $mainAnchor.Replace('<Grid>', '<Grid Background="#101318">'))
}
$navAnchor = '            x:Name="NavView"'
if (!$main.Contains($navAnchor)) { throw 'MainPage NavView anchor not found' }
# NavigationViewEx has no PaneBackground property; style its supported child/content surfaces instead.
if (!$main.Contains('OpenPaneLength="232"')) {
    $navAnchor = '            x:Name="NavView"'
    $main = $main.Replace($navAnchor, $navAnchor + [Environment]::NewLine + '            OpenPaneLength="232"' + [Environment]::NewLine + '            CompactPaneLength="64"')
}
if (!$main.Contains('<Grid x:Name="ContentGrid" Padding="0,48,0,0" Background="#101318">')) {
    $main = $main.Replace('<Grid x:Name="ContentGrid" Padding="0,48,0,0">', '<Grid x:Name="ContentGrid" Padding="0,48,0,0" Background="#101318">')
}
Set-Content -Path $mainPath -Value $main -Encoding UTF8

# Navigation pane: override the resource key consumed by NavigationView's own template.
# Avoid unsupported Background/PaneBackground properties on NavigationViewEx.
$navStylePath = Join-Path $root 'Styles\NavigationView.xaml'
if (!(Test-Path $navStylePath)) { throw "Required navigation style file not found: $navStylePath" }
$navStyles = Get-Content -Raw -Encoding UTF8 $navStylePath
$navStyles = $navStyles.Replace(
    '<StaticResource x:Key="NavigationViewDefaultPaneBackground" ResourceKey="AcrylicInAppFillColorBaseBrush" />',
    '<SolidColorBrush x:Key="NavigationViewDefaultPaneBackground" Color="#151B23" />'
)
if (!$navStyles.Contains('NavigationViewItemBackgroundSelectedPointerOver')) {
    $navStateBrushes = @'
            <SolidColorBrush x:Key="NavigationViewItemBackgroundPointerOver" Color="#202B37" />
            <SolidColorBrush x:Key="NavigationViewItemBackgroundPressed" Color="#293A49" />
            <SolidColorBrush x:Key="NavigationViewItemBackgroundSelected" Color="#1B3041" />
            <SolidColorBrush x:Key="NavigationViewItemBackgroundSelectedPointerOver" Color="#243E52" />
            <SolidColorBrush x:Key="NavigationViewItemBackgroundSelectedPressed" Color="#2C4659" />
'@
    $darkThemeAnchor = '<contract13NotPresent:StaticResource x:Key="NavigationViewExpandedPaneBackground" ResourceKey="SystemControlAcrylicWindowBrush" />'
    if (!$navStyles.Contains($darkThemeAnchor)) { throw 'NavigationView dark theme resource anchor not found' }
    $navStyles = $navStyles.Replace($darkThemeAnchor, $darkThemeAnchor + [Environment]::NewLine + $navStateBrushes)
}
Set-Content -Path $navStylePath -Value $navStyles -Encoding UTF8

# Home landing page: preserve all existing bindings and navigation behavior.
$homeXaml = Get-Content -Raw -Encoding UTF8 $homePath
if (!$homeXaml.Contains('<Grid Background="#101318">')) {
    $homeAnchor = '    <Grid>' + [Environment]::NewLine + '        <Grid.RowDefinitions>'
    if (!$homeXaml.Contains($homeAnchor)) { throw 'HomePage root Grid anchor not found' }
    $homeXaml = $homeXaml.Replace($homeAnchor, $homeAnchor.Replace('<Grid>', '<Grid Background="#101318">'))
}
if (!$homeXaml.Contains('Foreground="#F3F4F6"')) {
    $homeXaml = $homeXaml.Replace(
        '                Style="{StaticResource TitleMediumTextBlockStyle}"',
        '                Style="{StaticResource TitleMediumTextBlockStyle}"' + [Environment]::NewLine + '                FontSize="30"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#F3F4F6"'
    )
}
if (!$homeXaml.Contains('Background="#151B23"')) {
    $homeXaml = $homeXaml.Replace(
        '            x:Name="RecentSubHeaderGrid"',
        '            x:Name="RecentSubHeaderGrid"' + [Environment]::NewLine + '            Background="#151B23"'
    )
}
Set-Content -Path $homePath -Value $homeXaml -Encoding UTF8

Write-Host 'Mosuan shell UI v1 applied: unified dark canvas, navigation pane, home heading and recent section.'
