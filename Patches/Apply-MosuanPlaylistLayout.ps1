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

# Give the page title a clear hierarchy while retaining the existing TextBlock style.
$xaml = $xaml.Replace(
    '                Style="{StaticResource TitleMediumTextBlockStyle}"' + [Environment]::NewLine + '                Text="播放列表"',
    '                Style="{StaticResource TitleMediumTextBlockStyle}"' + [Environment]::NewLine + '                FontSize="28"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#F3F4F6"' + [Environment]::NewLine + '                Text="播放列表"'
)

# Treat the page header and action row as two coordinated surfaces.
if (!$xaml.Contains('x:Name="HeaderGrid"' + [Environment]::NewLine + '            Grid.Row="0"' + [Environment]::NewLine + '            Background="#151B23"')) {
    $xaml = $xaml.Replace(
        '            x:Name="HeaderGrid"' + [Environment]::NewLine + '            Grid.Row="0"',
        '            x:Name="HeaderGrid"' + [Environment]::NewLine + '            Grid.Row="0"' + [Environment]::NewLine + '            Background="#151B23"'
    )
}
if (!$xaml.Contains('x:Name="SubHeaderGrid"' + [Environment]::NewLine + '            Grid.Row="1"' + [Environment]::NewLine + '            Background="#151B23"')) {
    $xaml = $xaml.Replace(
        '            x:Name="SubHeaderGrid"' + [Environment]::NewLine + '            Grid.Row="1"',
        '            x:Name="SubHeaderGrid"' + [Environment]::NewLine + '            Grid.Row="1"' + [Environment]::NewLine + '            Background="#151B23"'
    )
}

# Keep the hierarchy consistent across title, actions and playlist content.
$xaml = $xaml.Replace('Margin="{StaticResource BottomMediumMargin}"', 'Margin="0,0,0,8"')
$xaml = $xaml.Replace('Margin="0,0,0,8"' + [Environment]::NewLine + '            Padding="{StaticResource ContentPagePadding}"', 'Margin="0,0,0,8"' + [Environment]::NewLine + '            Padding="32,20,32,16"')
$xaml = $xaml.Replace('            Padding="{StaticResource ContentPagePadding}">', '            Padding="32,12,32,12">')
$xaml = $xaml.Replace('Margin="{StaticResource TopMediumMargin}"', 'Margin="0,16,0,0"')

Set-Content -Path $path -Value $xaml -Encoding UTF8
Write-Host 'Mosuan playlist layout applied: charcoal canvas, localized labels and refined spacing.'
