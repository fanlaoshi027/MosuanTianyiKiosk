$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot '..\Screenbox'
$page=Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'
$pageCs=Join-Path $root 'Screenbox\Pages\PlayerPage.xaml.cs'
if (!(Test-Path $page) -or !(Test-Path $pageCs)) { throw 'PlayerPage files not found' }

$xaml=Get-Content -Raw -Encoding UTF8 $page

# Remove panels injected by earlier revisions. Keep this patch idempotent.
$xaml=[regex]::Replace($xaml,'(?s)\s*<!-- Mosuan playlist/favorites panel.*?<\/Grid>\s*','\n')
$xaml=[regex]::Replace($xaml,'(?s)\s*<!-- Mosuan file browser:.*?<Grid x:Name="MosuanFileBrowserPanel".*?<\/Grid>\s*','\n')

# Normalize explicit Grid.Children blocks to ordinary child elements. This avoids
# duplicate Children assignment when previous patches have already touched the root Grid.
$xaml=$xaml.Replace('<Grid.Children>','').Replace('</Grid.Children>','')

$playlist=@'
        <!-- Mosuan playlist/favorites panel: outside the video surface. -->
        <Grid x:Name="MosuanPlaylistPanel" Grid.Row="3" Margin="0,8,0,0" MinHeight="170" Background="#FF151515">
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
        <!-- Mosuan file browser: outside the video surface. -->
        <Grid x:Name="MosuanFileBrowserPanel" Grid.Row="4" Margin="0,8,0,0" MinHeight="230" Background="#FF111111">
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

# Add two Auto rows to the root LayoutRoot so these panels live below the existing player area.
$rowDef='(<Grid.RowDefinitions>\s*)(?<rows>.*?)(\s*</Grid.RowDefinitions>)'
$m=[regex]::Match($xaml,$rowDef,[Text.RegularExpressions.RegexOptions]::Singleline)
if(!$m.Success){throw 'Root Grid.RowDefinitions not found'}
$existing=$m.Groups['rows'].Value
if($existing -notmatch 'MosuanExtraRows'){
    $newRows=$existing+"`r`n        <!-- MosuanExtraRows -->`r`n        <RowDefinition Height=\"Auto\" />`r`n        <RowDefinition Height=\"Auto\" />"
    $xaml=$xaml.Remove($m.Groups['rows'].Index,$m.Groups['rows'].Length).Insert($m.Groups['rows'].Index,$newRows)
}

# Insert immediately before the closing tag of LayoutRoot.
$rootClose=[regex]::Match($xaml,'(?s)(<Grid\s+x:Name="LayoutRoot".*?)(</Grid>\s*</Page>)')
if(!$rootClose.Success){throw 'LayoutRoot closing tag not found'}
$xaml=$xaml.Insert($rootClose.Groups[2].Index,$playlist+$browser)
Set-Content -Path $page -Value $xaml -Encoding UTF8

Write-Host 'Mosuan file browser UI v3 applied.'