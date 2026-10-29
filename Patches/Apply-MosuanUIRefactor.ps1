$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox'
$mainPage = Join-Path $root 'Screenbox\Pages\MainPage.xaml'
$playerPage = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'

foreach ($path in @($mainPage, $playerPage)) {
    if (!(Test-Path $path)) { throw "Required Screenbox UI file not found: $path" }
}

# Main navigation: retain Screenbox navigation tags and handlers, only localize labels.
$main = Get-Content -Raw -Encoding UTF8 $mainPage
$labels = [ordered]@{
    '<TextBlock x:Name="HomeNavItemText" Text="{x:Bind strings:Resources.Home}" />' = '<TextBlock x:Name="HomeNavItemText" Text="首页" />'
    '<TextBlock x:Name="MusicNavItemText" Text="{x:Bind strings:Resources.MusicLibrary}" />' = '<TextBlock x:Name="MusicNavItemText" Text="音乐" />'
    '<TextBlock x:Name="VideosNavItemText" Text="{x:Bind strings:Resources.VideoLibrary}" />' = '<TextBlock x:Name="VideosNavItemText" Text="视频" />'
    '<TextBlock x:Name="NetworkNavItemText" Text="{x:Bind strings:Resources.Network}" />' = '<TextBlock x:Name="NetworkNavItemText" Text="网络文件" />'
    '<TextBlock x:Name="PlayQueueNavItemText" Text="{x:Bind strings:Resources.PlayQueue}" />' = '<TextBlock x:Name="PlayQueueNavItemText" Text="播放队列" />'
    '<TextBlock x:Name="PlaylistsNavItemText" Text="{x:Bind strings:Resources.Playlists}" />' = '<TextBlock x:Name="PlaylistsNavItemText" Text="收藏夹" />'
    '<TextBlock x:Name="SettingsNavItemText" Text="{x:Bind strings:Resources.Settings}" />' = '<TextBlock x:Name="SettingsNavItemText" Text="设置" />'
}
foreach ($entry in $labels.GetEnumerator()) {
    if ($main.Contains($entry.Key)) {
        $main = $main.Replace($entry.Key, $entry.Value)
    } elseif (!$main.Contains($entry.Value)) {
        throw "Navigation label anchor not found: $($entry.Key)"
    }
}
Set-Content -Path $mainPage -Value $main -Encoding UTF8

# Player canvas: deep charcoal background, with no album-art wallpaper behind lesson video.
$player = Get-Content -Raw -Encoding UTF8 $playerPage
$player = $player.Replace('<Color x:Key="BackgroundAcrylicTintColor">#202020</Color>', '<Color x:Key="BackgroundAcrylicTintColor">#101318</Color>')
$player = $player.Replace('<Color x:Key="BackgroundAcrylicTintFallbackColor">#2C2C2C</Color>', '<Color x:Key="BackgroundAcrylicTintFallbackColor">#101318</Color>')
$player = $player.Replace('<x:Double x:Key="BackgroundAcrylicTintOpacity">0.5</x:Double>', '<x:Double x:Key="BackgroundAcrylicTintOpacity">0.82</x:Double>')
if ($player -notmatch 'x:Name="BackgroundElement"[^>]*Visibility="Collapsed"') {
    $player = [regex]::Replace(
        $player,
        '(?s)(<Grid\s+x:Name="BackgroundElement"[^>]*)(>)',
        '$1 Visibility="Collapsed"$2',
        1
    )
}
Set-Content -Path $playerPage -Value $player -Encoding UTF8

Write-Host 'Mosuan UI refactor v1 applied: Chinese navigation and focused dark player canvas.'
