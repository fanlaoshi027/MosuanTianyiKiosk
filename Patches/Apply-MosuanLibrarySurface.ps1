$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'

function Set-RootCanvas([string]$relativePath) {
    $path = Join-Path $root $relativePath
    if (!(Test-Path $path)) { throw "Library surface target not found: $path" }
    $xaml = Get-Content -Raw -Encoding UTF8 $path
    if (!$xaml.Contains('<Grid Background="#101318">')) {
        $anchor = '    <Grid>'
        if (!$xaml.Contains($anchor)) { throw "Root canvas anchor not found: $relativePath" }
        $xaml = $xaml.Replace($anchor, '    <Grid Background="#101318">', 1)
    }
    Set-Content -Path $path -Value $xaml -Encoding UTF8
}

# Unify the browsing canvas so nested folder and video pages no longer fall
# back to the stock light/translucent page surface.
Set-RootCanvas 'Pages\FolderListViewPage.xaml'
Set-RootCanvas 'Pages\FolderViewPage.xaml'
Set-RootCanvas 'Pages\NetworkPage.xaml'
Set-RootCanvas 'Pages\AllVideosPage.xaml'
Set-RootCanvas 'Pages\VideosPage.xaml'

# Folder details: strengthen the title hierarchy without changing navigation,
# breadcrumbs, item templates, or selection behavior.
$folderPath = Join-Path $root 'Pages\FolderViewPage.xaml'
$folder = Get-Content -Raw -Encoding UTF8 $folderPath
$titleStyle = '            Style="{StaticResource TitleMediumTextBlockStyle}"'
if (!$folder.Contains('FontSize="28"') -and $folder.Contains($titleStyle)) {
    $folder = $folder.Replace($titleStyle, $titleStyle + [Environment]::NewLine + '            FontSize="28"' + [Environment]::NewLine + '            FontWeight="SemiBold"' + [Environment]::NewLine + '            Foreground="#F3F6FA"', 1)
}
Set-Content -Path $folderPath -Value $folder -Encoding UTF8

# Network browsing header uses the same compact title treatment.
$networkPath = Join-Path $root 'Pages\NetworkPage.xaml'
$network = Get-Content -Raw -Encoding UTF8 $networkPath
$networkStyle = '<TextBlock Style="{StaticResource TitleMediumTextBlockStyle}"'
if (!$network.Contains('FontSize="28"') -and $network.Contains($networkStyle)) {
    $network = $network.Replace($networkStyle, '<TextBlock FontSize="28" FontWeight="SemiBold" Foreground="#F3F6FA" Style="{StaticResource TitleMediumTextBlockStyle}"', 1)
}
Set-Content -Path $networkPath -Value $network -Encoding UTF8

# Settings page: make the page canvas and section hierarchy consistent with
# the Mosuan shell while retaining all original settings cards and bindings.
$settingsPath = Join-Path $root 'Pages\SettingsPage.xaml'
$settings = Get-Content -Raw -Encoding UTF8 $settingsPath
if (!$settings.Contains('Background="#101318"')) {
    $settings = $settings.Replace('    <Grid>', '    <Grid Background="#101318">', 1)
}
if (!$settings.Contains('Foreground="#F3F6FA"')) {
    $settings = $settings.Replace(
        '            <Setter Property="Margin" Value="1,28,0,8" />',
        '            <Setter Property="Margin" Value="1,24,0,8" />' + [Environment]::NewLine + '            <Setter Property="Foreground" Value="#F3F6FA" />' + [Environment]::NewLine + '            <Setter Property="FontSize" Value="17" />',
        1
    )
}
$settingsHeader = '                Style="{StaticResource TitleMediumTextBlockStyle}"'
if (!$settings.Contains('FontSize="28"') -and $settings.Contains($settingsHeader)) {
    $settings = $settings.Replace($settingsHeader, $settingsHeader + [Environment]::NewLine + '                FontSize="28"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#F3F6FA"', 1)
}
$settings = $settings.Replace('Padding="{StaticResource ContentPagePadding}">', 'Padding="32,20,32,24">', 1)
Set-Content -Path $settingsPath -Value $settings -Encoding UTF8

Write-Host 'Mosuan library surfaces applied: unified folder, network, video and settings page canvases.'
