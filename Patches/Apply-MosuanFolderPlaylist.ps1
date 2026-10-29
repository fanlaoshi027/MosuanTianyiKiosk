$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$page = Join-Path $root 'Pages\PlayerPage.xaml'
$code = Join-Path $root 'Pages\PlayerPage.xaml.cs'
if (!(Test-Path $page) -or !(Test-Path $code)) { throw 'PlayerPage source files not found.' }

# FolderPicker is the UWP-supported way to grant access to local folders and SMB shares.
$xaml = Get-Content -Raw -Encoding UTF8 $page
if ($xaml -notmatch 'MosuanOpenFolderButton') {
    $anchor = '(?s)(<Button\s+x:Name="MosuanOpenVideosButton".*?</Button>)'
    if ($xaml -notmatch $anchor) { throw 'MosuanOpenVideosButton anchor not found.' }
    $button = @'
        <Button
            x:Name="MosuanOpenFolderButton"
            Grid.Row="0"
            HorizontalAlignment="Left"
            VerticalAlignment="Center"
            Margin="148,4,0,4"
            Padding="12,6"
            Content="文件夹 / SMB"
            AutomationProperties.Name="打开文件夹或局域网 SMB 共享"
            ToolTipService.ToolTip="选择本地文件夹或局域网共享文件夹，自动建立文件夹播放列表"
            Click="MosuanOpenFolder_Click" />
'@
    $xaml = [regex]::Replace($xaml, $anchor, '$1' + [Environment]::NewLine + $button, 1)
    Set-Content -Path $page -Value $xaml -Encoding UTF8
}

$cs = Get-Content -Raw -Encoding UTF8 $code
if ($cs -notmatch 'MosuanOpenFolder_Click') {
    if ($cs -notmatch 'using Windows\.Storage\.Pickers;') {
        $anchor = 'using Windows.System;'
        if (!$cs.Contains($anchor)) { throw 'Could not find using insertion point.' }
        $cs = $cs.Replace($anchor, $anchor + [Environment]::NewLine + 'using Windows.Storage;' + [Environment]::NewLine + 'using Windows.Storage.Pickers;')
    }
    if ($cs -notmatch 'using Windows\.ApplicationModel\.DataTransfer;') {
        $anchor = 'using Windows.Foundation;'
        if (!$cs.Contains($anchor)) { throw 'Could not find Windows.Foundation using.' }
        $cs = $cs.Replace($anchor, $anchor + [Environment]::NewLine + 'using Windows.ApplicationModel.DataTransfer;')
    }
    if ($cs -notmatch 'using System\.Linq;') {
        $anchor = 'using System;'
        if (!$cs.Contains($anchor)) { throw 'Could not find System using.' }
        $cs = $cs.Replace($anchor, $anchor + [Environment]::NewLine + 'using System.Linq;')
    }
    $method = @'

    private async void MosuanOpenFolder_Click(object sender, RoutedEventArgs e)
    {
        var picker = new FolderPicker
        {
            ViewMode = PickerViewMode.List,
            SuggestedStartLocation = PickerLocationId.VideosLibrary
        };
        picker.FileTypeFilter.Add("*");

        // Windows handles SMB authentication in the system picker. Mosuan never
        // asks for or stores network credentials.
        StorageFolder? folder = await picker.PickSingleFolderAsync();
        if (folder is null) return;

        try
        {
            Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList
                .AddOrReplace("MosuanFolderPlaylist", folder);

            var files = await folder.GetFilesAsync();
            var videoFiles = files
                .Where(file => IsMosuanVideoFile(file.FileType))
                .OrderBy(file => file.Name, StringComparer.OrdinalIgnoreCase)
                .ToList();

            if (videoFiles.Count == 0)
            {
                var emptyDialog = new ContentDialog
                {
                    Title = "文件夹中没有视频",
                    Content = $"“{folder.Name}”中没有找到支持的视频文件。",
                    CloseButtonText = "知道了",
                    XamlRoot = LayoutRoot.XamlRoot
                };
                await emptyDialog.ShowAsync();
                return;
            }

            var data = new DataPackage();
            data.SetStorageItems(videoFiles);
            await ViewModel.OnDropAsync(data.GetView());
        }
        catch (Exception ex)
        {
            var errorDialog = new ContentDialog
            {
                Title = "无法读取文件夹",
                Content = $"读取“{folder.Name}”失败。请检查 SMB 共享权限、网络连接或 Windows 登录状态。\n\n{ex.Message}",
                CloseButtonText = "确定",
                XamlRoot = LayoutRoot.XamlRoot
            };
            await errorDialog.ShowAsync();
        }
    }

    private static bool IsMosuanVideoFile(string extension)
    {
        switch (extension.ToLowerInvariant())
        {
            case ".mp4":
            case ".mkv":
            case ".mov":
            case ".avi":
            case ".wmv":
            case ".m4v":
            case ".webm":
            case ".mpg":
            case ".mpeg":
            case ".ts":
                return true;
            default:
                return false;
        }
    }

'@
    $idx = $cs.LastIndexOf('}')
    if ($idx -lt 0) { throw 'PlayerPage class closing brace not found.' }
    $cs = $cs.Insert($idx, $method)
    Set-Content -Path $code -Value $cs -Encoding UTF8
}
Write-Host 'Mosuan folder playlist and SMB picker patch applied.'
