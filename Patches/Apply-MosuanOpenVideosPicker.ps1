$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$page = Join-Path $root 'Pages\PlayerPage.xaml'
$code = Join-Path $root 'Pages\PlayerPage.xaml.cs'
if (!(Test-Path $page) -or !(Test-Path $code)) { throw 'PlayerPage source files not found.' }

# Add a native Windows picker entry point; playback is delegated to Screenbox's
# existing OnDropAsync pipeline, preserving its supported-file and playlist behavior.
$xamlText = Get-Content -Raw -Encoding UTF8 $page
if ($xamlText -notmatch 'MosuanOpenVideosButton') {
    $rootClose = $xamlText.LastIndexOf('</Grid>')
    if ($rootClose -lt 0) { throw 'Could not locate LayoutRoot closing Grid.' }
    $button = @'
        <Button
            x:Name="MosuanOpenVideosButton"
            Grid.Row="0"
            HorizontalAlignment="Left"
            VerticalAlignment="Center"
            Margin="12,4,0,4"
            Padding="12,6"
            Content="打开视频"
            AutomationProperties.Name="打开本地视频"
            Click="MosuanOpenVideos_Click"
            Panel.ZIndex="100" />
'@
    $xamlText = $xamlText.Insert($rootClose, $button + [Environment]::NewLine + '    ')
    Set-Content -Path $page -Value $xamlText -Encoding UTF8
}

$csText = Get-Content -Raw -Encoding UTF8 $code
if ($csText -notmatch 'MosuanOpenVideos_Click') {
    if ($csText -notmatch 'using Windows\.ApplicationModel\.DataTransfer;') {
        $anchor = 'using Windows.ApplicationModel.DataTransfer;'
        if ($csText -notmatch [regex]::Escape($anchor)) {
            $anchor = 'using Windows.Foundation;'
            if (!$csText.Contains($anchor)) { throw 'Could not find a stable using insertion point.' }
            $csText = $csText.Replace($anchor, $anchor + [Environment]::NewLine + 'using Windows.ApplicationModel.DataTransfer;')
        }
    }
    if ($csText -notmatch 'using Windows\.Storage\.Pickers;') {
        $anchor = 'using Windows.System;'
        if (!$csText.Contains($anchor)) { throw 'Could not find Windows.System using anchor.' }
        $csText = $csText.Replace($anchor, $anchor + [Environment]::NewLine + 'using Windows.Storage.Pickers;')
    }

    $method = @'

    private async void MosuanOpenVideos_Click(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker
        {
            ViewMode = PickerViewMode.List,
            SuggestedStartLocation = PickerLocationId.Videos
        };
        foreach (var extension in new[] { ".mp4", ".mkv", ".mov", ".avi", ".wmv", ".m4v", ".webm", ".mpg", ".mpeg" })
        {
            picker.FileTypeFilter.Add(extension);
        }

        var files = await picker.PickMultipleFilesAsync();
        if (files is null || files.Count == 0) return;

        var package = new DataPackage();
        package.SetStorageItems(files);
        await ViewModel.OnDropAsync(package.GetView());
    }

'@
    $lastBrace = $csText.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw 'Could not find PlayerPage class closing brace.' }
    $csText = $csText.Insert($lastBrace, $method)
    Set-Content -Path $code -Value $csText -Encoding UTF8
}

Write-Host 'Mosuan native video picker patch applied.'
