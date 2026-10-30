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
if (!$main.Contains('PaneBackground="#151B23"')) {
    $navAnchor = '            x:Name="NavView"'
    if (!$main.Contains($navAnchor)) { throw 'MainPage NavView anchor not found' }
    $main = $main.Replace($navAnchor, $navAnchor + [Environment]::NewLine + '            Background="#101318"' + [Environment]::NewLine + '            PaneBackground="#151B23"')
}
if (!$main.Contains('<Grid x:Name="ContentGrid" Padding="0,48,0,0" Background="#101318">')) {
    $main = $main.Replace('<Grid x:Name="ContentGrid" Padding="0,48,0,0">', '<Grid x:Name="ContentGrid" Padding="0,48,0,0" Background="#101318">')
}
Set-Content -Path $mainPath -Value $main -Encoding UTF8

# Home landing page: preserve all existing bindings and navigation behavior.
$home = Get-Content -Raw -Encoding UTF8 $homePath
if (!$home.Contains('<Grid Background="#101318">')) {
    $homeAnchor = '    <Grid>' + [Environment]::NewLine + '        <Grid.RowDefinitions>'
    if (!$home.Contains($homeAnchor)) { throw 'HomePage root Grid anchor not found' }
    $home = $home.Replace($homeAnchor, $homeAnchor.Replace('<Grid>', '<Grid Background="#101318">'))
}
if (!$home.Contains('Foreground="#F3F4F6"')) {
    $home = $home.Replace(
        '                Style="{StaticResource TitleMediumTextBlockStyle}"',
        '                Style="{StaticResource TitleMediumTextBlockStyle}"' + [Environment]::NewLine + '                FontSize="30"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#F3F4F6"'
    )
}
if (!$home.Contains('Background="#151B23"')) {
    $home = $home.Replace(
        '            x:Name="RecentSubHeaderGrid"',
        '            x:Name="RecentSubHeaderGrid"' + [Environment]::NewLine + '            Background="#151B23"'
    )
}
Set-Content -Path $homePath -Value $home -Encoding UTF8

Write-Host 'Mosuan shell UI v1 applied: unified dark canvas, navigation pane, home heading and recent section.'
