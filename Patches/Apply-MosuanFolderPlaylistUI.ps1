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
                                <Button Content="打开目录" Tag="{Binding Id}" Click="FolderPlaylistOpenFolder_Click" />
                                <Button Content="重命名" Tag="{Binding Id}" Click="FolderPlaylistRename_Click" />
                                <Button Content="上移" Tag="{Binding Id}" Click="FolderPlaylistMoveUp_Click" />
                                <Button Content="下移" Tag="{Binding Id}" Click="FolderPlaylistMoveDown_Click" />
                                <Button Content="刷新" Tag="{Binding Id}" Click="FolderPlaylistRefresh_Click" />
                                <Button Content="重新授权" Tag="{Binding Id}" Click="FolderPlaylistReauthorize_Click" />
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
    $cs = $cs.Replace('using System.Threading.Tasks;', 'using System.Threading.Tasks;' + $nl + 'using System.Collections.ObjectModel;' + $nl + 'using Screenbox.Models;' + $nl + 'using Windows.UI.Xaml;' + $nl + 'using Windows.UI.Xaml.Controls;')
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
        var detail = exception.Message;
        var cause = exception;
        while (cause.InnerException is not null)
            cause = cause.InnerException;

        if (cause is UnauthorizedAccessException)
        {
            FolderPlaylistStatus.Text = $"没有访问权限：{detail}。请检查 Windows 共享权限和账号凭据，然后点击“重新授权”。原有播放列表不会被删除。";
            return;
        }

        if (cause is System.IO.IOException)
        {
            FolderPlaylistStatus.Text = $"文件夹暂时不可访问：{detail}。如果这是 SMB 共享，请先确认电脑已连接同一网络、共享主机在线且共享路径可打开，再点击“刷新”或“重新授权”。";
            return;
        }

        FolderPlaylistStatus.Text = $"操作失败：{detail}。如果这是网络共享，请检查网络连接；如果访问权限失效，可点击“重新授权”。";
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

    private async void FolderPlaylistOpenFolder_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is string id)
        {
            try
            {
                var opened = await _folderPlaylistService.OpenFolderAsync(id);
                FolderPlaylistStatus.Text = opened
                    ? "已打开对应文件夹。"
                    : "Windows 暂时无法打开该文件夹，请检查访问权限。";
            }
            catch (Exception exception) { ShowFolderPlaylistError(exception); }
        }
    }

    private async void FolderPlaylistRename_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button || button.Tag is not string id) return;
        var playlist = _folderPlaylistService.Find(id);
        if (playlist is null) return;

        var nameInput = new TextBox
        {
            Text = playlist.Name,
            PlaceholderText = "输入播放列表名称",
            MinWidth = 280
        };
        var dialog = new ContentDialog
        {
            Title = "重命名播放列表",
            Content = nameInput,
            PrimaryButtonText = "保存",
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Primary
        };

        try
        {
            var result = await dialog.ShowAsync();
            if (result != ContentDialogResult.Primary) return;
            if (await _folderPlaylistService.RenameAsync(id, nameInput.Text))
            {
                RefreshFolderPlaylistItems();
                FolderPlaylistStatus.Text = "播放列表名称已保存。";
            }
        }
        catch (Exception exception) { ShowFolderPlaylistError(exception); }
    }

    private async void FolderPlaylistMoveUp_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is string id)
        {
            try
            {
                if (await _folderPlaylistService.MoveAsync(id, -1))
                    RefreshFolderPlaylistItems();
            }
            catch (Exception exception) { ShowFolderPlaylistError(exception); }
        }
    }

    private async void FolderPlaylistMoveDown_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is string id)
        {
            try
            {
                if (await _folderPlaylistService.MoveAsync(id, 1))
                    RefreshFolderPlaylistItems();
            }
            catch (Exception exception) { ShowFolderPlaylistError(exception); }
        }
    }

    private async void FolderPlaylistRefresh_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (sender is Button button && button.Tag is string id)
            {
                await _folderPlaylistService.RefreshAsync(id);
                RefreshFolderPlaylistItems();
                FolderPlaylistStatus.Text = "刷新完成，文件列表已更新。";
            }
        }
        catch (Exception exception) { ShowFolderPlaylistError(exception); }
    }

    private async void FolderPlaylistReauthorize_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (sender is Button button && button.Tag is string id)
            {
                var restored = await _folderPlaylistService.ReauthorizeAsync(id);
                if (restored)
                {
                    RefreshFolderPlaylistItems();
                    FolderPlaylistStatus.Text = "文件夹访问权限已更新，播放列表已恢复。";
                }
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
