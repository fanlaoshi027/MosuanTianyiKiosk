$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot '..\Screenbox'
$page=Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'
$pageCs=Join-Path $root 'Screenbox\Pages\PlayerPage.xaml.cs'
if (!(Test-Path $page) -or !(Test-Path $pageCs)) { throw 'PlayerPage files not found' }

# This patch is intentionally injected after Screenbox checkout. The browser is
# a thin UI over MosuanFileBrowser, so local and UNC/SMB paths use the same model.
$xaml=Get-Content -Raw -Encoding UTF8 $page
if ($xaml -notmatch 'MosuanFileBrowserPanel') {
$panel=@'

        <!-- Mosuan file browser: below the video/control area. -->
        <Grid x:Name="MosuanFileBrowserPanel" Grid.Row="5" Margin="0,8,0,0" MinHeight="230" Background="#FF111111">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel Orientation="Horizontal" Spacing="8" Margin="12,8,12,6">
                <TextBlock Text="文件" FontSize="18" FontWeight="SemiBold" VerticalAlignment="Center"/>
                <Button Content="本地" Click="MosuanBrowseLocal_Click"/>
                <Button Content="SMB / 网络" Click="MosuanBrowseNetwork_Click"/>
                <Button Content="加入播放列表" Click="MosuanAddSelectedToPlaylist_Click"/>
                <Button Content="收藏当前文件夹" Click="MosuanFavoriteCurrentFolder_Click"/>
            </StackPanel>
            <Grid Grid.Row="1" Margin="12,0,12,6">
                <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <Button Content="↑" Click="MosuanFileUp_Click" Margin="0,0,6,0"/>
                <TextBox x:Name="MosuanFilePathBox" Grid.Column="1" PlaceholderText="输入本地路径或 \\服务器\\共享" KeyDown="MosuanFilePath_KeyDown"/>
                <Button Content="打开" Grid.Column="2" Click="MosuanFilePathOpen_Click" Margin="6,0,0,0"/>
            </Grid>
            <ListView x:Name="MosuanFileList" Grid.Row="2" Margin="12,0,12,10" DoubleTapped="MosuanFileList_DoubleTapped" SelectionMode="Single">
                <ListView.ItemTemplate>
                    <DataTemplate>
                        <Grid Padding="8,5">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <TextBlock Text="{Binding Icon}" FontSize="18"/>
                            <TextBlock Text="{Binding Name}" Grid.Column="1" VerticalAlignment="Center"/>
                            <TextBlock Text="{Binding TypeText}" Grid.Column="2" Opacity="0.55"/>
                        </Grid>
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>
        </Grid>
'@
$needle='</Grid>'
$pos=$xaml.LastIndexOf($needle)
if($pos -lt 0){throw 'PlayerPage root Grid not found'}
$xaml=$xaml.Insert($pos,$panel)
Set-Content -Path $page -Value $xaml -Encoding UTF8
}

$cs=Get-Content -Raw -Encoding UTF8 $pageCs
if($cs -notmatch 'MosuanFileBrowser'){
if($cs -notmatch 'using Screenbox.Models;'){$cs=$cs.Replace('using System;',"using System;`r`nusing Screenbox.Models;")}
$code=@'

    private string _mosuanBrowserPath = Environment.GetFolderPath(Environment.SpecialFolder.MyVideos);

    private void MosuanRefreshFileBrowser()
    {
        var items = MosuanFileBrowser.Enumerate(_mosuanBrowserPath)
            .Select(x => new { x.Name, x.Path, x.IsFolder, Icon = x.IsFolder ? "📁" : "🎬", TypeText = x.IsFolder ? "文件夹" : "视频" })
            .ToList();
        MosuanFileList.ItemsSource = items;
        MosuanFilePathBox.Text = _mosuanBrowserPath;
    }

    private void MosuanOpenBrowserPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !System.IO.Directory.Exists(path)) return;
        _mosuanBrowserPath = path;
        MosuanRefreshFileBrowser();
    }

    private void MosuanBrowseLocal_Click(object sender, RoutedEventArgs e) => MosuanOpenBrowserPath(Environment.GetFolderPath(Environment.SpecialFolder.MyVideos));

    private void MosuanBrowseNetwork_Click(object sender, RoutedEventArgs e)
    {
        var path = MosuanFilePathBox.Text?.Trim();
        if (!string.IsNullOrWhiteSpace(path) && path.StartsWith("\\\\")) MosuanOpenBrowserPath(path);
    }

    private void MosuanFilePathOpen_Click(object sender, RoutedEventArgs e) => MosuanOpenBrowserPath(MosuanFilePathBox.Text?.Trim() ?? "");

    private void MosuanFilePath_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == Windows.System.VirtualKey.Enter) MosuanFilePathOpen_Click(sender, e);
    }

    private void MosuanFileUp_Click(object sender, RoutedEventArgs e)
    {
        var parent = System.IO.Directory.GetParent(_mosuanBrowserPath)?.FullName;
        if (!string.IsNullOrWhiteSpace(parent)) MosuanOpenBrowserPath(parent);
    }

    private async void MosuanFileList_DoubleTapped(object sender, DoubleTappedRoutedEventArgs e)
    {
        if (MosuanFileList.SelectedItem is null) return;
        var item = MosuanFileList.SelectedItem;
        var path = (string)item.GetType().GetProperty("Path")!.GetValue(item)!;
        var isFolder = (bool)item.GetType().GetProperty("IsFolder")!.GetValue(item)!;
        if (isFolder) MosuanOpenBrowserPath(path);
        else
        {
            _mosuanPlaylistStore.AddPlaylist(System.IO.Path.GetFileName(path), path);
            await _mosuanPlaylistStore.SaveAsync();
            MosuanRefreshPlaylistUi();
            await OpenMediaFile(path);
        }
    }

    private async void MosuanAddSelectedToPlaylist_Click(object sender, RoutedEventArgs e)
    {
        if (MosuanFileList.SelectedItem is null) return;
        var item = MosuanFileList.SelectedItem;
        var path = (string)item.GetType().GetProperty("Path")!.GetValue(item)!;
        var isFolder = (bool)item.GetType().GetProperty("IsFolder")!.GetValue(item)!;
        if (!isFolder)
        {
            _mosuanPlaylistStore.AddPlaylist(System.IO.Path.GetFileName(path), path);
            await _mosuanPlaylistStore.SaveAsync();
            MosuanRefreshPlaylistUi();
        }
    }

    private async void MosuanFavoriteCurrentFolder_Click(object sender, RoutedEventArgs e)
    {
        _mosuanPlaylistStore.AddFavoriteFolder(System.IO.Path.GetFileName(_mosuanBrowserPath), _mosuanBrowserPath);
        await _mosuanPlaylistStore.SaveAsync();
        MosuanRefreshPlaylistUi();
    }

'@
$anchor='    private void OnLoaded'
$idx=$cs.IndexOf($anchor)
if($idx -lt 0){$idx=$cs.IndexOf('    private async void OnLoaded')}
if($idx -lt 0){throw 'PlayerPage OnLoaded anchor not found'}
$cs=$cs.Insert($idx,$code)
Set-Content -Path $pageCs -Value $cs -Encoding UTF8
}
Write-Host 'Mosuan file browser UI patch applied.'