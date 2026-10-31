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
                <StackPanel Grid.Column="1" Orientation="Horizontal" Spacing="6">
                    <Button Content="添加本地文件夹" Click="AddFolderPlaylist_Click" />
                    <Button Content="添加 SMB 共享" Click="AddNetworkFolderPlaylist_Click" />
                </StackPanel>
            </Grid>
            <TextBlock x:Name="FolderPlaylistStatus" Opacity="0.75" TextWrapping="Wrap" />
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
                                <TextBlock Text="{Binding FileCount, Mode=OneWay}" Opacity="0.7" />
                                <TextBlock Text="{Binding FolderPath}" Opacity="0.55" TextTrimming="CharacterEllipsis" />
                                <TextBlock Text="{Binding UpdatedAtText}" Opacity="0.55" />
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
    $cs = $cs.Replace('using System.Threading.Tasks;', 'using System.Threading.Tasks;' + $nl + 'using System.Collections.ObjectModel;' + $nl + 'using Screenbox.Models;' + $nl + 'using Windows.UI.Xaml;')
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
        FolderPlaylistStatus.Text = _folderPlaylists.Count == 0
            ? "添加本地视频文件夹，也可以在系统选择窗口中进入网络位置并选择 SMB 共享。"
            : $"已保存 {_folderPlaylists.Count} 个文件夹播放列表（本地或 SMB）";
    }

    private void ShowFolderPlaylistError(Exception exception)
    {
        FolderPlaylistStatus.Text = $"操作失败：{exception.Message}。如果文件夹权限已失效，请移除后重新添加。";
    }

    private async void AddFolderPlaylist_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var added = await _folderPlaylistService.AddFolderFromPickerAsync();
            if (added is not null)
                FolderPlaylistStatus.Text = $"已添加：{added.Name}（{added.Files.Count} 个视频）";
            RefreshFolderPlaylistItems();
        }
        catch (Exception exception) { ShowFolderPlaylistError(exception); }
    }

    private async void AddNetworkFolderPlaylist_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var added = await _folderPlaylistService.AddNetworkFolderFromPickerAsync();
            if (added is not null)
                FolderPlaylistStatus.Text = $"已添加网络共享：{added.Name}（{added.Files.Count} 个视频）";
            RefreshFolderPlaylistItems();
        }
        catch (Exception exception) { ShowFolderPlaylistError(exception); }
    }

    private async void FolderPlaylistPlay_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (sender is Button button && button.Tag is string id)
            {
                await _folderPlaylistService.PlayAsync(id);
                FolderPlaylistStatus.Text = "已将文件夹中的视频交给播放队列。";
            }
        }
        catch (Exception exception) { ShowFolderPlaylistError(exception); }
    }

    private async void FolderPlaylistRefresh_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (sender is Button button && button.Tag is string id)
            {
                await _folderPlaylistService.RefreshAsync(id);
                RefreshFolderPlaylistItems();
            }
        }
        catch (Exception exception) { ShowFolderPlaylistError(exception); }
    }

    private async void FolderPlaylistRemove_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (sender is Button button && button.Tag is string id)
            {
                await _folderPlaylistService.RemoveAsync(id);
                RefreshFolderPlaylistItems();
            }
        }
        catch (Exception exception) { ShowFolderPlaylistError(exception); }
    }
'@
    $cs = $cs.Replace('    private void SelectDeselectAllKeyboardAccelerator_OnInvoked', $handlers + $nl + '    private void SelectDeselectAllKeyboardAccelerator_OnInvoked')
    Set-Content -Path $csPath -Value $cs -Encoding UTF8
}
Write-Host 'Mosuan folder playlist page integration applied.'
