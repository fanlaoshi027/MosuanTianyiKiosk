$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$xamlPath = Join-Path $root 'Pages\PlaylistsPage.xaml'
$csPath = Join-Path $root 'Pages\PlaylistsPage.xaml.cs'
$nl = [Environment]::NewLine

$xaml = Get-Content -Raw $xamlPath
if ($xaml -notmatch 'FolderPlaylistList') {
    $xaml = $xaml.Replace('<RowDefinition Height="*" />', '<RowDefinition Height="Auto" />' + $nl + '            <RowDefinition Height="*" />')
    $xaml = $xaml.Replace('Grid.Row="2"', 'Grid.Row="3"')
    $panel = @'
        <StackPanel Grid.Row="2" Margin="{StaticResource ContentPagePadding}" Spacing="8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>
                <TextBlock Text="文件夹播放列表" FontSize="18" FontWeight="SemiBold" VerticalAlignment="Center" />
                <Button Grid.Column="1" Content="添加文件夹" Click="AddFolderPlaylist_Click" />
            </Grid>
            <ListView x:Name="FolderPlaylistList" MaxHeight="168" SelectionMode="None">
                <ListView.ItemTemplate>
                    <DataTemplate>
                        <Grid Padding="8,4">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*" />
                                <ColumnDefinition Width="Auto" />
                            </Grid.ColumnDefinitions>
                            <StackPanel VerticalAlignment="Center" Spacing="2">
                                <TextBlock Text="{Binding Name}" FontWeight="SemiBold" />
                                <TextBlock Text="{Binding Files.Count}" Opacity="0.7" />
                            </StackPanel>
                            <StackPanel Grid.Column="1" Orientation="Horizontal" Spacing="4">
                                <Button Content="播放" Tag="{Binding Id}" Click="FolderPlaylistPlay_Click" />
                                <Button Content="刷新" Tag="{Binding Id}" Click="FolderPlaylistRefresh_Click" />
                                <Button Content="移除" Tag="{Binding Id}" Click="FolderPlaylistRemove_Click" />
                            </StackPanel>
                        </Grid>
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>
        </StackPanel>
'@
    $anchor = '        <GridView' + $nl
    if (-not $xaml.Contains($anchor)) { throw 'Could not locate PlaylistsGridView insertion point.' }
    $xaml = $xaml.Replace($anchor, $panel + $nl + $anchor)
    Set-Content -Path $xamlPath -Value $xaml -Encoding UTF8
}

$cs = Get-Content -Raw $csPath
if ($cs -notmatch 'MosuanFolderPlaylistService') {
    $cs = $cs.Replace('using System.Threading.Tasks;', 'using System.Threading.Tasks;' + $nl + 'using System.Collections.ObjectModel;' + $nl + 'using Mosuan.Models;' + $nl + 'using Windows.UI.Xaml;')
    $cs = $cs.Replace('    private readonly SelectDeselectAllCommand _selectionCommand;', '    private readonly SelectDeselectAllCommand _selectionCommand;' + $nl + '    private readonly MosuanFolderPlaylistService _folderPlaylistService = new();' + $nl + '    private readonly ObservableCollection<MosuanFolderPlaylist> _folderPlaylists = new();')
    $cs = $cs.Replace('        _selectionCommand = new SelectDeselectAllCommand();', '        _selectionCommand = new SelectDeselectAllCommand();' + $nl + '        FolderPlaylistList.ItemsSource = _folderPlaylists;' + $nl + '        Loaded += PlaylistsPage_Loaded;')
    $handlers = @'

    private async void PlaylistsPage_Loaded(object sender, RoutedEventArgs e)
    {
        await _folderPlaylistService.LoadAsync();
        RefreshFolderPlaylistItems();
    }

    private void RefreshFolderPlaylistItems()
    {
        _folderPlaylists.Clear();
        foreach (var item in _folderPlaylistService.State.Playlists)
            _folderPlaylists.Add(item);
    }

    private async void AddFolderPlaylist_Click(object sender, RoutedEventArgs e)
    {
        await _folderPlaylistService.AddFolderFromPickerAsync();
        RefreshFolderPlaylistItems();
    }

    private async void FolderPlaylistPlay_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is string id)
            await _folderPlaylistService.PlayAsync(id);
    }

    private async void FolderPlaylistRefresh_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is string id)
        {
            await _folderPlaylistService.RefreshAsync(id);
            RefreshFolderPlaylistItems();
        }
    }

    private async void FolderPlaylistRemove_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is string id)
        {
            await _folderPlaylistService.RemoveAsync(id);
            RefreshFolderPlaylistItems();
        }
    }
'@
    $cs = $cs.Replace('    private void SelectDeselectAllKeyboardAccelerator_OnInvoked', $handlers + $nl + '    private void SelectDeselectAllKeyboardAccelerator_OnInvoked')
    Set-Content -Path $csPath -Value $cs -Encoding UTF8
}
Write-Host 'Mosuan folder playlist page integration applied.'
