$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox'
$page = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'
$pageCs = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml.cs'
$elementCs = Join-Path $root 'Screenbox\Controls\PlayerElement.xaml.cs'
$vmCs = Join-Path $root 'Screenbox.Core\ViewModels\PlayerElementViewModel.cs'

foreach ($p in @($page,$pageCs,$elementCs,$vmCs)) { if (!(Test-Path $p)) { throw "Missing Screenbox file: $p" } }

# Expose the existing normalized VLC crop API to the page. Screenbox already has
# NormalizedSourceRect in its playback abstraction, so this patch reuses it.
$vm = Get-Content -Raw -Encoding UTF8 $vmCs
if ($vm -notmatch 'public Rect NormalizedSourceRect\s*\{') {
    $anchor = '    public void Initialize(string[] swapChainOptions)'
    $insert = @'
    public Rect NormalizedSourceRect
    {
        get => VlcMediaPlayer?.NormalizedSourceRect ?? new Rect(0, 0, 1, 1);
        set
        {
            if (VlcMediaPlayer is not null)
                VlcMediaPlayer.NormalizedSourceRect = value;
        }
    }

'@
    if (!$vm.Contains($anchor)) { throw 'PlayerElementViewModel Initialize anchor not found' }
    $vm = $vm.Replace($anchor, $insert + $anchor)
    Set-Content -Path $vmCs -Value $vm -Encoding UTF8
}

$element = Get-Content -Raw -Encoding UTF8 $elementCs
if ($element -notmatch 'SetNormalizedCrop') {
    if ($element -notmatch 'using Windows.Foundation;') {
        $element = $element.Replace('using Windows.UI.Input;', 'using Windows.Foundation;`r`nusing Windows.UI.Input;')
    }
    $anchor = '    public PlayerElement()'
    $insert = @'
    public void SetNormalizedCrop(Rect rect) => ViewModel.NormalizedSourceRect = rect;

    public void ResetNormalizedCrop() => ViewModel.NormalizedSourceRect = new Rect(0, 0, 1, 1);

'@
    if (!$element.Contains($anchor)) { throw 'PlayerElement constructor anchor not found' }
    $element = $element.Replace($anchor, $insert + $anchor)
    Set-Content -Path $elementCs -Value $element -Encoding UTF8
}

# Add the browser-like crop/mask overlay above the VLC surface.
$xaml = Get-Content -Raw -Encoding UTF8 $page
if ($xaml -notmatch 'x:Name="MosuanToolsOverlay"') {
    $overlay = @'

        <!-- Mosuan: browser-style crop and face masking overlay -->
        <Grid
            x:Name="MosuanToolsOverlay"
            Grid.Row="0"
            Grid.RowSpan="3"
            Grid.Column="0"
            Background="Transparent"
            Visibility="Collapsed">
            <Canvas x:Name="MosuanToolCanvas" Background="Transparent">
                <Border
                    x:Name="MosuanCropBox"
                    Canvas.Left="120"
                    Canvas.Top="80"
                    Width="720"
                    Height="400"
                    BorderBrush="#FF8A00"
                    BorderThickness="2"
                    Background="#18000000"
                    PointerPressed="MosuanCropBox_PointerPressed"
                    PointerMoved="MosuanCropBox_PointerMoved"
                    PointerReleased="MosuanCropBox_PointerReleased">
                    <Grid>
                        <Border Width="14" Height="14" HorizontalAlignment="Left" VerticalAlignment="Top" Background="#FF8A00" />
                        <Border Width="14" Height="14" HorizontalAlignment="Right" VerticalAlignment="Top" Background="#FF8A00" />
                        <Border Width="14" Height="14" HorizontalAlignment="Left" VerticalAlignment="Bottom" Background="#FF8A00" />
                        <Border Width="14" Height="14" HorizontalAlignment="Right" VerticalAlignment="Bottom" Background="#FF8A00" />
                    </Grid>
                </Border>

                <Border
                    x:Name="MosuanMaskBox"
                    Canvas.Left="820"
                    Canvas.Top="90"
                    Width="180"
                    Height="120"
                    BorderBrush="#FF404040"
                    BorderThickness="2"
                    Background="#F0000000"
                    Visibility="Collapsed"
                    PointerPressed="MosuanMaskBox_PointerPressed"
                    PointerMoved="MosuanMaskBox_PointerMoved"
                    PointerReleased="MosuanMaskBox_PointerReleased">
                    <TextBlock Text="头像遮盖" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="White" />
                </Border>

                <StackPanel Canvas.Right="24" Canvas.Top="24" Orientation="Horizontal" Spacing="8">
                    <Button Content="裁切" Click="MosuanCropToggle_Click" />
                    <Button Content="遮盖" Click="MosuanMaskToggle_Click" />
                    <Button Content="重置" Click="MosuanReset_Click" />
                </StackPanel>
            </Canvas>
        </Grid>
'@
    $needle = "</Grid>`r`n</Page>"
    if (!$xaml.Contains($needle)) { $needle = "</Grid>`n</Page>" }
    if (!$xaml.Contains($needle)) { throw 'PlayerPage closing Grid/Page anchor not found' }
    $xaml = $xaml.Replace($needle, $overlay + "`r`n</Grid>`r`n</Page>")
    Set-Content -Path $page -Value $xaml -Encoding UTF8
}

# Add shortcut and drag handlers to PlayerPage.
$cs = Get-Content -Raw -Encoding UTF8 $pageCs
if ($cs -notmatch 'MosuanCropBox_PointerPressed') {
    $fields = @'

    private bool _mosuanCropMode;
    private bool _mosuanMaskMode;
    private bool _mosuanCropDragging;
    private bool _mosuanMaskDragging;
    private Point _mosuanDragStart;
    private double _mosuanStartLeft;
    private double _mosuanStartTop;
    private bool _mosuanSmartInvert;
'@
    $anchor = '    private bool _startup;'
    if (!$cs.Contains($anchor)) { throw 'PlayerPage startup field anchor not found' }
    $cs = $cs.Replace($anchor, $anchor + $fields)

    $handlers = @'

    private void MosuanShowTools(bool show)
    {
        MosuanToolsOverlay.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        if (!show)
        {
            _mosuanCropMode = false;
            _mosuanMaskMode = false;
            MosuanMaskBox.Visibility = Visibility.Collapsed;
        }
    }

    private void MosuanCropToggle_Click(object sender, RoutedEventArgs e)
    {
        _mosuanCropMode = !_mosuanCropMode;
        _mosuanMaskMode = false;
        MosuanMaskBox.Visibility = Visibility.Collapsed;
        MosuanShowTools(true);
    }

    private void MosuanMaskToggle_Click(object sender, RoutedEventArgs e)
    {
        _mosuanMaskMode = !_mosuanMaskMode;
        _mosuanCropMode = false;
        MosuanMaskBox.Visibility = _mosuanMaskMode ? Visibility.Visible : Visibility.Collapsed;
        MosuanShowTools(true);
    }

    private void MosuanReset_Click(object sender, RoutedEventArgs e)
    {
        VideoView.ResetNormalizedCrop();
        MosuanCropBox.Width = Math.Max(200, MosuanToolCanvas.ActualWidth * 0.70);
        MosuanCropBox.Height = Math.Max(120, MosuanToolCanvas.ActualHeight * 0.70);
        Canvas.SetLeft(MosuanCropBox, Math.Max(0, (MosuanToolCanvas.ActualWidth - MosuanCropBox.Width) / 2));
        Canvas.SetTop(MosuanCropBox, Math.Max(0, (MosuanToolCanvas.ActualHeight - MosuanCropBox.Height) / 2));
    }

    private void MosuanCropBox_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanCropMode) return;
        _mosuanCropDragging = true;
        _mosuanDragStart = e.GetCurrentPoint(MosuanToolCanvas).Position;
        _mosuanStartLeft = Canvas.GetLeft(MosuanCropBox);
        _mosuanStartTop = Canvas.GetTop(MosuanCropBox);
        MosuanCropBox.CapturePointer(e.Pointer);
        e.Handled = true;
    }

    private void MosuanCropBox_PointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanCropDragging) return;
        var p = e.GetCurrentPoint(MosuanToolCanvas).Position;
        double left = Math.Max(0, Math.Min(MosuanToolCanvas.ActualWidth - MosuanCropBox.Width, _mosuanStartLeft + p.X - _mosuanDragStart.X));
        double top = Math.Max(0, Math.Min(MosuanToolCanvas.ActualHeight - MosuanCropBox.Height, _mosuanStartTop + p.Y - _mosuanDragStart.Y));
        Canvas.SetLeft(MosuanCropBox, left);
        Canvas.SetTop(MosuanCropBox, top);
        MosuanApplyCrop();
    }

    private void MosuanCropBox_PointerReleased(object sender, PointerRoutedEventArgs e)
    {
        _mosuanCropDragging = false;
        MosuanCropBox.ReleasePointerCapture(e.Pointer);
        MosuanApplyCrop();
    }

    private void MosuanApplyCrop()
    {
        if (MosuanToolCanvas.ActualWidth <= 1 || MosuanToolCanvas.ActualHeight <= 1) return;
        double left = Math.Clamp(Canvas.GetLeft(MosuanCropBox) / MosuanToolCanvas.ActualWidth, 0, 0.95);
        double top = Math.Clamp(Canvas.GetTop(MosuanCropBox) / MosuanToolCanvas.ActualHeight, 0, 0.95);
        double width = Math.Clamp(MosuanCropBox.Width / MosuanToolCanvas.ActualWidth, 0.05, 1 - left);
        double height = Math.Clamp(MosuanCropBox.Height / MosuanToolCanvas.ActualHeight, 0.05, 1 - top);
        VideoView.SetNormalizedCrop(new Rect(left, top, width, height));
    }

    private void MosuanMaskBox_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanMaskMode) return;
        _mosuanMaskDragging = true;
        _mosuanDragStart = e.GetCurrentPoint(MosuanToolCanvas).Position;
        _mosuanStartLeft = Canvas.GetLeft(MosuanMaskBox);
        _mosuanStartTop = Canvas.GetTop(MosuanMaskBox);
        MosuanMaskBox.CapturePointer(e.Pointer);
        e.Handled = true;
    }

    private void MosuanMaskBox_PointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanMaskDragging) return;
        var p = e.GetCurrentPoint(MosuanToolCanvas).Position;
        double left = Math.Max(0, Math.Min(MosuanToolCanvas.ActualWidth - MosuanMaskBox.Width, _mosuanStartLeft + p.X - _mosuanDragStart.X));
        double top = Math.Max(0, Math.Min(MosuanToolCanvas.ActualHeight - MosuanMaskBox.Height, _mosuanStartTop + p.Y - _mosuanDragStart.Y));
        Canvas.SetLeft(MosuanMaskBox, left);
        Canvas.SetTop(MosuanMaskBox, top);
    }

    private void MosuanMaskBox_PointerReleased(object sender, PointerRoutedEventArgs e)
    {
        _mosuanMaskDragging = false;
        MosuanMaskBox.ReleasePointerCapture(e.Pointer);
    }

'@
    $anchor = '    private void Mosuan'
    # Insert before first existing method whose name starts with Mosuan, or before OnLoaded.
    $idx = $cs.IndexOf('    private void OnLoaded')
    if ($idx -lt 0) { $idx = $cs.IndexOf('    private async void OnLoaded') }
    if ($idx -lt 0) { throw 'PlayerPage OnLoaded anchor not found' }
    $cs = $cs.Insert($idx, $handlers)

    # Hook keyboard shortcuts into the existing preview key handler.
    $keyAnchor = '    private void LayoutRoot_OnPreviewKeyDown(object sender, KeyRoutedEventArgs e)'
    $keyCode = @'
    private void MosuanHandleShortcut(VirtualKey key, KeyRoutedEventArgs e)
    {
        if (key == VirtualKey.C)
        {
            _mosuanCropMode = !_mosuanCropMode;
            _mosuanMaskMode = false;
            MosuanMaskBox.Visibility = Visibility.Collapsed;
            MosuanShowTools(true);
            e.Handled = true;
        }
        else if (key == VirtualKey.M)
        {
            _mosuanMaskMode = !_mosuanMaskMode;
            _mosuanCropMode = false;
            MosuanMaskBox.Visibility = _mosuanMaskMode ? Visibility.Visible : Visibility.Collapsed;
            MosuanShowTools(true);
            e.Handled = true;
        }
        else if (key == VirtualKey.R)
        {
            MosuanReset_Click(this, new RoutedEventArgs());
            e.Handled = true;
        }
    }

'@
    if (!$cs.Contains('MosuanHandleShortcut')) {
        $idx = $cs.IndexOf($keyAnchor)
        if ($idx -lt 0) { throw 'LayoutRoot_OnPreviewKeyDown anchor not found' }
        $cs = $cs.Insert($idx, $keyCode)
    }
    if ($cs -match [regex]::Escape($keyAnchor)) {
        $sig = $keyAnchor + "`r`n    {"
        $replacement = $keyAnchor + "`r`n    {`r`n        MosuanHandleShortcut(e.Key, e);`r`n        if (e.Handled) return;"
        if ($cs.Contains($sig) -and $cs -notmatch 'MosuanHandleShortcut\(e\.Key, e\);') {
            $cs = $cs.Replace($sig, $replacement)
        }
    }
    Set-Content -Path $pageCs -Value $cs -Encoding UTF8
}

Write-Host 'Mosuan crop/mask feature patch applied.'