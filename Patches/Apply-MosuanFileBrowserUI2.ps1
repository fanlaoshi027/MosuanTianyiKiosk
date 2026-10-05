$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot '..\Screenbox'
$page=Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'
$pageCs=Join-Path $root 'Screenbox\Pages\PlayerPage.xaml.cs'
if (!(Test-Path $page) -or !(Test-Path $pageCs)) { throw 'PlayerPage files not found' }

$xaml=Get-Content -Raw -Encoding UTF8 $page

# Remove the previous Mosuan panels regardless of where the earlier patch inserted them.
$xaml=[regex]::Replace($xaml,'(?s)\s*<!-- Mosuan playlist/favorites panel.*?<\/Grid>\s*','\n')
$xaml=[regex]::Replace($xaml,'(?s)\s*<!-- Mosuan file browser: below the video/control area\. -->.*?<Grid x:Name="MosuanFileBrowserPanel".*?<\/Grid>\s*','\n')

$playlist=@'
        <!-- Mosuan playlist/favorites panel: outside video, below playback controls. -->
        <Grid x:Name="MosuanPlaylistPanel" Grid.Row="4" Margin="0,8,0,0" MinHeight="170" Background="#FF151515">
            <Grid.ColumnDefinitions><ColumnDefinition Width="2*"/><ColumnDefinition Width="1.2*"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Margin="12,8,8,8">
                <TextBlock Text="播放列表" FontSize="18" FontWeight="SemiBold"/>
                <ListView x:Name="MosuanPlaylistList" Margin="0,6,0,0" SelectionChanged="MosuanPlaylist_SelectionChanged"/>
                <Button Content="清空播放列表" Click="MosuanPlaylistClear_Click" Margin="0,6,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Margin="8,8,12,8">
                <TextBlock Text="收藏文件夹" FontSize="18" FontWeight="SemiBold"/>
                <ListView x:Name="MosuanFavoritesList" Margin="0,6,0,0" SelectionChanged="MosuanFavorite_SelectionChanged"/>
                <Button Content="添加当前文件夹" Click="MosuanFavoriteAdd_Click" Margin="0,6,0,0"/>
            </StackPanel>
        </Grid>
'@

$browser=@'
        <!-- Mosuan file browser: below video, playback controls, playlist and favorites. -->
        <Grid x:Name="MosuanFileBrowserPanel" Grid.Row="5" Margin="0,8,0,0" MinHeight="230" Background="#FF111111">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
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

# Screenbox uses an explicit Grid.Children collection. Insert our controls into it,
# rather than adding a second implicit Children collection to the same Grid.
if ($xaml -match '(?s)<Grid\.Children>') {
    $pos=$xaml.IndexOf('</Grid.Children>')
    if ($pos -lt 0) { throw 'Grid.Children closing tag not found' }
    $xaml=$xaml.Insert($pos,$playlist+$browser)
} else {
    throw 'Expected Screenbox PlayerPage Grid.Children collection not found'
}
Set-Content -Path $page -Value $xaml -Encoding UTF8

# C# handlers/data layer are already injected by the earlier patches; do not duplicate them.
Write-Host 'Mosuan file browser UI v2 applied using Grid.Children.'