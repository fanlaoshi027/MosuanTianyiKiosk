$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox'
$page = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'
$pageCs = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml.cs'
if (!(Test-Path $page) -or !(Test-Path $pageCs)) { throw 'PlayerPage files not found' }

# Keep the first implementation deliberately self-contained: a local playlist and
# favorite-folder model stored as JSON in ApplicationData. No video files are copied.
$dataCs = Join-Path $root 'Screenbox\Models\MosuanPlaylistStore.cs'
New-Item -ItemType Directory -Force -Path (Split-Path $dataCs) | Out-Null
@'
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Windows.Storage;

namespace Screenbox.Models;

public sealed class MosuanPlaylistItem
{
    public string Name { get; set; } = "";
    public string Path { get; set; } = "";
}

public sealed class MosuanFavoriteFolder
{
    public string Name { get; set; } = "";
    public string Path { get; set; } = "";
}

public sealed class MosuanPlaylistState
{
    public List<MosuanPlaylistItem> Playlist { get; set; } = new();
    public List<MosuanFavoriteFolder> Favorites { get; set; } = new();
}

public sealed class MosuanPlaylistStore
{
    private const string FileName = "mosuan-playlist.json";
    public MosuanPlaylistState State { get; private set; } = new();

    private async Task<StorageFile> GetFileAsync()
    {
        return await ApplicationData.Current.LocalFolder.CreateFileAsync(
            FileName, CreationCollisionOption.OpenIfExists);
    }

    public async Task LoadAsync()
    {
        try
        {
            var file = await GetFileAsync();
            var json = await FileIO.ReadTextAsync(file);
            State = JsonSerializer.Deserialize<MosuanPlaylistState>(json) ?? new();
        }
        catch
        {
            State = new();
        }
    }

    public async Task SaveAsync()
    {
        var file = await GetFileAsync();
        await FileIO.WriteTextAsync(file, JsonSerializer.Serialize(State, new JsonSerializerOptions { WriteIndented = true }));
    }

    public void AddPlaylist(string name, string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return;
        if (State.Playlist.Any(x => string.Equals(x.Path, path, StringComparison.OrdinalIgnoreCase))) return;
        State.Playlist.Add(new MosuanPlaylistItem { Name = name, Path = path });
    }

    public void RemovePlaylist(string path) => State.Playlist.RemoveAll(x => string.Equals(x.Path, path, StringComparison.OrdinalIgnoreCase));

    public void AddFavoriteFolder(string name, string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return;
        if (State.Favorites.Any(x => string.Equals(x.Path, path, StringComparison.OrdinalIgnoreCase))) return;
        State.Favorites.Add(new MosuanFavoriteFolder { Name = name, Path = path });
    }

    public void RemoveFavoriteFolder(string path) => State.Favorites.RemoveAll(x => string.Equals(x.Path, path, StringComparison.OrdinalIgnoreCase));
}
'@ | Set-Content -Encoding UTF8 $dataCs

$xaml = Get-Content -Raw -Encoding UTF8 $page
if ($xaml -notmatch 'MosuanPlaylistPanel') {
    $panel = @'

        <!-- Mosuan playlist/favorites panel. It is below the video/control area. -->
        <Grid x:Name="MosuanPlaylistPanel" Grid.Row="4" Margin="0,8,0,0" MinHeight="170" Background="#FF151515">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2*" />
                <ColumnDefinition Width="1.2*" />
            </Grid.ColumnDefinitions>
            <Grid Grid.Column="0" Margin="12,8,8,8">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <StackPanel Orientation="Horizontal" Spacing="8">
                    <TextBlock Text="播放列表" FontSize="18" FontWeight="SemiBold" />
                    <Button Content="清空" Click="MosuanPlaylistClear_Click" />
                </StackPanel>
                <ListView x:Name="MosuanPlaylistList" Grid.Row="1" Margin="0,6,0,0" SelectionChanged="MosuanPlaylist_SelectionChanged" />
            </Grid>
            <Grid Grid.Column="1" Margin="8,8,12,8">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <StackPanel Orientation="Horizontal" Spacing="8">
                    <TextBlock Text="收藏文件夹" FontSize="18" FontWeight="SemiBold" />
                    <Button Content="添加当前目录" Click="MosuanFavoriteAdd_Click" />
                </StackPanel>
                <ListView x:Name="MosuanFavoritesList" Grid.Row="1" Margin="0,6,0,0" SelectionChanged="MosuanFavorite_SelectionChanged" />
            </Grid>
        </Grid>
'@
    $needle = '</Grid>'
    $pos = $xaml.LastIndexOf($needle)
    if ($pos -lt 0) { throw 'PlayerPage closing Grid not found' }
    $xaml = $xaml.Insert($pos, $panel)
    Set-Content -Path $page -Value $xaml -Encoding UTF8
}

$cs = Get-Content -Raw -Encoding UTF8 $pageCs
if ($cs -notmatch 'MosuanPlaylistStore') {
    if ($cs -notmatch 'using Screenbox.Models;') { $cs = $cs.Replace('using System;', "using System;`r`nusing Screenbox.Models;") }
    $fields = @'

    private readonly MosuanPlaylistStore _mosuanPlaylistStore = new();

    private async Task MosuanLoadPlaylistAsync()
    {
        await _mosuanPlaylistStore.LoadAsync();
        MosuanRefreshPlaylistUi();
    }

    private void MosuanRefreshPlaylistUi()
    {
        if (MosuanPlaylistList is not null)
            MosuanPlaylistList.ItemsSource = _mosuanPlaylistStore.State.Playlist.Select(x => x.Name).ToList();
        if (MosuanFavoritesList is not null)
            MosuanFavoritesList.ItemsSource = _mosuanPlaylistStore.State.Favorites.Select(x => x.Name).ToList();
    }

    private async void MosuanPlaylistClear_Click(object sender, RoutedEventArgs e)
    {
        _mosuanPlaylistStore.State.Playlist.Clear();
        await _mosuanPlaylistStore.SaveAsync();
        MosuanRefreshPlaylistUi();
    }

    private async void MosuanFavoriteAdd_Click(object sender, RoutedEventArgs e)
    {
        var current = VideoView?.ViewModel?.CurrentMedia?.Path;
        if (string.IsNullOrWhiteSpace(current)) return;
        var directory = System.IO.Path.GetDirectoryName(current);
        if (string.IsNullOrWhiteSpace(directory)) return;
        _mosuanPlaylistStore.AddFavoriteFolder(System.IO.Path.GetFileName(directory), directory);
        await _mosuanPlaylistStore.SaveAsync();
        MosuanRefreshPlaylistUi();
    }

    private void MosuanPlaylist_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var index = MosuanPlaylistList.SelectedIndex;
        if (index < 0 || index >= _mosuanPlaylistStore.State.Playlist.Count) return;
        var path = _mosuanPlaylistStore.State.Playlist[index].Path;
        if (!string.IsNullOrWhiteSpace(path)) _ = OpenMediaFile(path);
    }

    private void MosuanFavorite_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var index = MosuanFavoritesList.SelectedIndex;
        if (index < 0 || index >= _mosuanPlaylistStore.State.Favorites.Count) return;
        // Folder browsing is intentionally kept separate from playback; the next
        // iteration will enumerate SMB/local children into the playlist.
    }

'@
    $idx = $cs.IndexOf('    private void OnLoaded')
    if ($idx -lt 0) { $idx = $cs.IndexOf('    private async void OnLoaded') }
    if ($idx -lt 0) { throw 'PlayerPage OnLoaded anchor not found' }
    $cs = $cs.Insert($idx, $fields)
    Set-Content -Path $pageCs -Value $cs -Encoding UTF8
}

Write-Host 'Mosuan playlist/favorites patch applied.'