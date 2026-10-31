$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$path = Join-Path $root 'Pages\PlaylistsPage.xaml'
if (!(Test-Path $path)) { throw "Required playlists page not found: $path" }

$xaml = Get-Content -Raw -Encoding UTF8 $path

# Establish the same charcoal canvas used by the player and home page.
if (!$xaml.Contains('<Grid Background="#101318">')) {
    $xaml = $xaml.Replace("    <Grid>" + [Environment]::NewLine + "        <Grid.RowDefinitions>", "    <Grid Background=""#101318"">" + [Environment]::NewLine + "        <Grid.RowDefinitions>")
}

# Localize visible playlist-page labels without changing commands or data bindings.
$xaml = $xaml.Replace('Text="{x:Bind strings:Resources.Playlists}"', 'Text="播放列表"')
$xaml = $xaml.Replace('Text="{x:Bind strings:Resources.NewPlaylist}"', 'Text="新建列表"')
$xaml = $xaml.Replace('Text="{x:Bind strings:Resources.Multiselect}"', 'Text="多选"')

# A more spacious title row and compact secondary action row.
$xaml = $xaml.Replace(
    'Padding="{StaticResource ContentPagePadding}">',
    'Padding="32,20,32,16">'
)
$xaml = $xaml.Replace(
    'Margin="{StaticResource TopMediumMargin}"',
    'Margin="0,8,0,0"'
)

# Keep the playlist cards visually separated from the page background.
if (!$xaml.Contains('Background="#151B23"')) {
    $xaml = $xaml.Replace(
        '            x:Name="SubHeaderGrid"',
        '            x:Name="SubHeaderGrid"' + [Environment]::NewLine + '            Background="#151B23"'
    )
}

Set-Content -Path $path -Value $xaml -Encoding UTF8
Write-Host 'Mosuan playlist layout applied: charcoal canvas, localized labels and refined spacing.'
