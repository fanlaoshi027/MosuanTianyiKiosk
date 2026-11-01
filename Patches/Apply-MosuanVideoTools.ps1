$ErrorActionPreference = 'Stop'

$screenbox = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$xamlPath = Join-Path $screenbox 'Pages\PlayerPage.xaml'
$codePath = Join-Path $screenbox 'Pages\PlayerPage.xaml.cs'

foreach ($path in @($xamlPath, $codePath)) {
    if (!(Test-Path $path)) { throw "Required PlayerPage file not found: $path" }
}

# Add a compact, independent video-tools flyout. Do not replace the existing player layout.
$xaml = Get-Content -Raw -Encoding UTF8 $xamlPath
if (!$xaml.Contains('x:Name="MosuanVideoToolsButton"')) {
    $button = @'
        <!-- Mosuan video tools: independent overlay, existing player layout remains intact. -->
        <Button
            x:Name="MosuanVideoToolsButton"
            Grid.Row="1"
            Grid.Column="0"
            Margin="0,0,18,0"
            Padding="14,10"
            HorizontalAlignment="Right"
            VerticalAlignment="Center"
            Background="#E6202731"
            BorderBrush="#667F8FA6"
            BorderThickness="1"
            Foreground="White"
            Content="画面工具">
            <Button.Flyout>
                <MenuFlyout>
                    <MenuFlyoutSubItem Text="画面比例">
                        <MenuFlyoutItem Text="原始画面（重置裁切）" Click="MosuanResetCrop_OnClick" />
                        <MenuFlyoutSeparator />
                        <MenuFlyoutItem Text="16:9" Tag="16:9" Click="MosuanAspectRatio_OnClick" />
                        <MenuFlyoutItem Text="4:3" Tag="4:3" Click="MosuanAspectRatio_OnClick" />
                        <MenuFlyoutItem Text="1:1" Tag="1:1" Click="MosuanAspectRatio_OnClick" />
                        <MenuFlyoutItem Text="9:16" Tag="9:16" Click="MosuanAspectRatio_OnClick" />
                        <MenuFlyoutItem Text="21:9" Tag="21:9" Click="MosuanAspectRatio_OnClick" />
                    </MenuFlyoutSubItem>
                    <MenuFlyoutSeparator />
                    <MenuFlyoutItem Text="自由框选裁切" Click="MosuanBeginFreeCrop_OnClick" />
                    <MenuFlyoutItem Text="重置裁切" Click="MosuanResetCrop_OnClick" />
                </MenuFlyout>
            </Button.Flyout>
        </Button>
'@
    $anchor = '<VisualStateManager.VisualStateGroups>'
    $insertAt = $xaml.LastIndexOf($anchor, [StringComparison]::Ordinal)
    if ($insertAt -lt 0) { throw 'PlayerPage VisualStateManager anchor not found' }
    $xaml = $xaml.Insert($insertAt, $button + [Environment]::NewLine)
}

# A transparent Canvas above the video receives one drag gesture and shows its selection rectangle.
if (!$xaml.Contains('x:Name="MosuanCropOverlay"')) {
    $overlay = @'
        <Canvas
            x:Name="MosuanCropOverlay"
            Grid.Row="0"
            Grid.RowSpan="3"
            Grid.Column="0"
            Margin="0,52,0,84"
            Panel.ZIndex="100"
            Background="#01000000"
            Visibility="Collapsed"
            PointerPressed="MosuanCropOverlay_OnPointerPressed"
            PointerMoved="MosuanCropOverlay_OnPointerMoved"
            PointerReleased="MosuanCropOverlay_OnPointerReleased"
            PointerCanceled="MosuanCropOverlay_OnPointerCanceled">
            <Rectangle
                x:Name="MosuanCropSelection"
                Fill="#22FF8A00"
                Stroke="#FFFF8A00"
                StrokeThickness="2"
                IsHitTestVisible="False"
                Visibility="Collapsed" />
        </Canvas>
'@
    $anchor = '</controls:PlayerElement>'
    $insertAt = $xaml.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($insertAt -lt 0) { throw 'PlayerElement closing tag not found for crop overlay' }
    $insertAt += $anchor.Length
    $xaml = $xaml.Insert($insertAt, [Environment]::NewLine + $overlay)
}
Set-Content -Path $xamlPath -Value $xaml -Encoding UTF8

# Route tools through the existing messaging pipeline and implement drag-to-select crop.
$code = Get-Content -Raw -Encoding UTF8 $codePath
if (!$code.Contains('using CommunityToolkit.Mvvm.Messaging;')) {
    $anchor = 'using CommunityToolkit.Diagnostics;'
    if (!$code.Contains($anchor)) { throw 'PlayerPage using anchor not found' }
    $code = $code.Replace($anchor, $anchor + [Environment]::NewLine + 'using CommunityToolkit.Mvvm.Messaging;')
}
if (!$code.Contains('using Screenbox.Core.Messages;')) {
    $anchor = 'using Screenbox.Core.Enums;'
    if (!$code.Contains($anchor)) { throw 'PlayerPage Core using anchor not found' }
    $code = $code.Replace($anchor, $anchor + [Environment]::NewLine + 'using Screenbox.Core.Messages;')
}
if (!$code.Contains('private bool _mosuanCropPointerCaptured;')) {
    $anchor = '    private bool _startup;'
    if (!$code.Contains($anchor)) { throw 'PlayerPage startup field anchor not found' }
    $code = $code.Replace($anchor, $anchor + [Environment]::NewLine + '    private bool _mosuanCropPointerCaptured;' + [Environment]::NewLine + '    private Point _mosuanCropStart;')
}

if (!$code.Contains('MosuanBeginFreeCrop_OnClick')) {
    $handlers = @'

    private void MosuanBeginFreeCrop_OnClick(object sender, RoutedEventArgs e)
    {
        MosuanCropSelection.Visibility = Visibility.Collapsed;
        MosuanCropOverlay.Visibility = Visibility.Visible;
        ViewModel.ControlsHidden = true;
    }

    private void MosuanCropOverlay_OnPointerPressed(object sender, PointerRoutedEventArgs e)
    {
        _mosuanCropStart = e.GetCurrentPoint(MosuanCropOverlay).Position;
        _mosuanCropPointerCaptured = MosuanCropOverlay.CapturePointer(e.Pointer);
        Canvas.SetLeft(MosuanCropSelection, _mosuanCropStart.X);
        Canvas.SetTop(MosuanCropSelection, _mosuanCropStart.Y);
        MosuanCropSelection.Width = 0;
        MosuanCropSelection.Height = 0;
        MosuanCropSelection.Visibility = Visibility.Visible;
        e.Handled = true;
    }

    private void MosuanCropOverlay_OnPointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanCropPointerCaptured) return;
        Point current = e.GetCurrentPoint(MosuanCropOverlay).Position;
        double left = Math.Max(0, Math.Min(_mosuanCropStart.X, current.X));
        double top = Math.Max(0, Math.Min(_mosuanCropStart.Y, current.Y));
        double right = Math.Min(MosuanCropOverlay.ActualWidth, Math.Max(_mosuanCropStart.X, current.X));
        double bottom = Math.Min(MosuanCropOverlay.ActualHeight, Math.Max(_mosuanCropStart.Y, current.Y));
        Canvas.SetLeft(MosuanCropSelection, left);
        Canvas.SetTop(MosuanCropSelection, top);
        MosuanCropSelection.Width = Math.Max(0, right - left);
        MosuanCropSelection.Height = Math.Max(0, bottom - top);
        e.Handled = true;
    }

    private void MosuanCropOverlay_OnPointerReleased(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanCropPointerCaptured) return;
        _mosuanCropPointerCaptured = false;
        MosuanCropOverlay.ReleasePointerCapture(e.Pointer);

        double width = MosuanCropOverlay.ActualWidth;
        double height = MosuanCropOverlay.ActualHeight;
        double left = Canvas.GetLeft(MosuanCropSelection);
        double top = Canvas.GetTop(MosuanCropSelection);
        double cropWidth = MosuanCropSelection.Width;
        double cropHeight = MosuanCropSelection.Height;

        MosuanCropOverlay.Visibility = Visibility.Collapsed;
        if (width <= 0 || height <= 0 || cropWidth < 24 || cropHeight < 24)
        {
            ViewModel.ControlsHidden = false;
            return;
        }

        double x = Math.Max(0, Math.Min(1, left / width));
        double y = Math.Max(0, Math.Min(1, top / height));
        double w = Math.Max(0, Math.Min(1 - x, cropWidth / width));
        double h = Math.Max(0, Math.Min(1 - y, cropHeight / height));
        if (w > 0 && h > 0)
            WeakReferenceMessenger.Default.Send(new ChangeNormalizedCropMessage(new Rect(x, y, w, h)));

        ViewModel.ControlsHidden = false;
        e.Handled = true;
    }

    private void MosuanCropOverlay_OnPointerCanceled(object sender, PointerRoutedEventArgs e)
    {
        _mosuanCropPointerCaptured = false;
        MosuanCropOverlay.Visibility = Visibility.Collapsed;
        MosuanCropSelection.Visibility = Visibility.Collapsed;
        ViewModel.ControlsHidden = false;
    }
'@
    $lastBrace = $code.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw 'PlayerPage class closing brace not found' }
    $code = $code.Insert($lastBrace, $handlers + [Environment]::NewLine)
}
if (!$code.Contains('MosuanAspectRatio_OnClick')) {
    $handlers = @'

    private void MosuanAspectRatio_OnClick(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { Tag: string ratio }) return;

        string[] parts = ratio.Split(':');
        if (parts.Length != 2
            || !double.TryParse(parts[0], NumberStyles.Float, CultureInfo.InvariantCulture, out double width)
            || !double.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out double height)
            || width <= 0
            || height <= 0)
        {
            return;
        }

        WeakReferenceMessenger.Default.Send(new ChangeAspectRatioMessage(new Size(width, height)));
    }

    private void MosuanResetCrop_OnClick(object sender, RoutedEventArgs e)
    {
        WeakReferenceMessenger.Default.Send(new ChangeAspectRatioMessage(new Size(0, 0)));
    }
'@
    $lastBrace = $code.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw 'PlayerPage class closing brace not found for aspect handlers' }
    $code = $code.Insert($lastBrace, $handlers + [Environment]::NewLine)
}
Set-Content -Path $codePath -Value $code -Encoding UTF8

Write-Host 'Mosuan video tools v2 applied: aspect presets, reset, and drag-to-select free crop.'
