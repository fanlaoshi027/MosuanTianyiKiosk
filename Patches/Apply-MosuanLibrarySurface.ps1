$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'

function Replace-First([string]$text, [string]$old, [string]$new) {
    $index = $text.IndexOf($old)
    if ($index -lt 0) { throw "Expected XAML anchor not found: $old" }
    return $text.Substring(0, $index) + $new + $text.Substring($index + $old.Length)
}

function Set-RootCanvas([string]$relativePath) {
    $path = Join-Path $root $relativePath
    if (!(Test-Path $path)) { throw "Library surface target not found: $path" }
    $xaml = Get-Content -Raw -Encoding UTF8 $path
    if (!$xaml.Contains('<Grid Background="#101318">')) {
        $anchor = '    <Grid>'
        if (!$xaml.Contains($anchor)) { throw "Root canvas anchor not found: $relativePath" }
        $xaml = Replace-First $xaml $anchor '    <Grid Background="#101318">'
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
    $folder = Replace-First $folder $titleStyle ($titleStyle + [Environment]::NewLine + '            FontSize="28"' + [Environment]::NewLine + '            FontWeight="SemiBold"' + [Environment]::NewLine + '            Foreground="#F3F6FA"')
}
Set-Content -Path $folderPath -Value $folder -Encoding UTF8

# Network browsing header uses the same compact title treatment.
$networkPath = Join-Path $root 'Pages\NetworkPage.xaml'
$network = Get-Content -Raw -Encoding UTF8 $networkPath
$networkStyle = '<TextBlock Style="{StaticResource TitleMediumTextBlockStyle}"'
if (!$network.Contains('FontSize="28"') -and $network.Contains($networkStyle)) {
    $network = Replace-First $network $networkStyle '<TextBlock FontSize="28" FontWeight="SemiBold" Foreground="#F3F6FA" Style="{StaticResource TitleMediumTextBlockStyle}"'
}
Set-Content -Path $networkPath -Value $network -Encoding UTF8

# Settings page: make the page canvas and section hierarchy consistent with
# the Mosuan shell while retaining all original settings cards and bindings.
$settingsPath = Join-Path $root 'Pages\SettingsPage.xaml'
$settings = Get-Content -Raw -Encoding UTF8 $settingsPath
if (!$settings.Contains('Background="#101318"')) {
    $settings = Replace-First $settings '    <Grid>' '    <Grid Background="#101318">'
}
if (!$settings.Contains('Foreground="#F3F6FA"')) {
    $settings = Replace-First $settings '            <Setter Property="Margin" Value="1,28,0,8" />' ('            <Setter Property="Margin" Value="1,24,0,8" />' + [Environment]::NewLine + '            <Setter Property="Foreground" Value="#F3F6FA" />' + [Environment]::NewLine + '            <Setter Property="FontSize" Value="17" />')
}
$settingsHeader = '                Style="{StaticResource TitleMediumTextBlockStyle}"'
if (!$settings.Contains('FontSize="28"') -and $settings.Contains($settingsHeader)) {
    $settings = Replace-First $settings $settingsHeader ($settingsHeader + [Environment]::NewLine + '                FontSize="28"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#F3F6FA"')
}
$settings = Replace-First $settings 'Padding="{StaticResource ContentPagePadding}">' 'Padding="32,20,32,24">'
Set-Content -Path $settingsPath -Value $settings -Encoding UTF8

Write-Host 'Mosuan library surfaces applied: unified folder, network, video and settings page canvases.'
