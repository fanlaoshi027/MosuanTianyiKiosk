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
            Background="#01000000"
            Visibility="Visible"
            Opacity="0"
            IsHitTestVisible="False"
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
            <Rectangle x:Name="MosuanCropHandleTopLeft" Width="12" Height="12" Fill="#FFFF8A00" IsHitTestVisible="False" Visibility="Collapsed" />
            <Rectangle x:Name="MosuanCropHandleTopRight" Width="12" Height="12" Fill="#FFFF8A00" IsHitTestVisible="False" Visibility="Collapsed" />
            <Rectangle x:Name="MosuanCropHandleBottomLeft" Width="12" Height="12" Fill="#FFFF8A00" IsHitTestVisible="False" Visibility="Collapsed" />
            <Rectangle x:Name="MosuanCropHandleBottomRight" Width="12" Height="12" Fill="#FFFF8A00" IsHitTestVisible="False" Visibility="Collapsed" />
        </Canvas>
'@
    # PlayerElement is self-closing in the upstream XAML. Insert after its element,
    # not after a nonexistent closing tag.
    $videoStart = $xaml.IndexOf('x:Name="VideoView"', [StringComparison]::Ordinal)
    if ($videoStart -lt 0) { throw 'PlayerElement VideoView anchor not found for crop overlay' }
    $insertAt = $xaml.IndexOf('/>', $videoStart, [StringComparison]::Ordinal)
    if ($insertAt -lt 0) { throw 'PlayerElement self-closing terminator not found for crop overlay' }
    $insertAt += 2
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
    $code = $code.Replace($anchor, $anchor + [Environment]::NewLine +
        '    private bool _mosuanCropPointerCaptured;' + [Environment]::NewLine +
        '    private bool _mosuanCropHasSelection;' + [Environment]::NewLine +
        '    private int _mosuanCropDragMode;' + [Environment]::NewLine +
        '    private Point _mosuanCropStart;' + [Environment]::NewLine +
        '    private Point _mosuanCropPointerStart;' + [Environment]::NewLine +
        '    private Rect _mosuanCropStartRect;' + [Environment]::NewLine +
        '    private Rect _mosuanCropViewportRect;')
}

if (!$code.Contains('MosuanBeginFreeCrop_OnClick')) {
    $handlers = @'

    private void MosuanBeginFreeCrop_OnClick(object sender, RoutedEventArgs e)
    {
        double width = MosuanCropOverlay.ActualWidth;
        double height = MosuanCropOverlay.ActualHeight;
        if (_mosuanCropHasSelection && width > 0 && height > 0)
        {
            Canvas.SetLeft(MosuanCropSelection, _mosuanCropViewportRect.X * width);
            Canvas.SetTop(MosuanCropSelection, _mosuanCropViewportRect.Y * height);
            MosuanCropSelection.Width = _mosuanCropViewportRect.Width * width;
            MosuanCropSelection.Height = _mosuanCropViewportRect.Height * height;
            MosuanCropSelection.Visibility = Visibility.Visible;
            MosuanUpdateCropHandles();
        }
        else
        {
            MosuanCropSelection.Visibility = Visibility.Collapsed;
            MosuanSetCropHandlesVisible(false);
        }

        MosuanCropOverlay.Opacity = 1;
        MosuanCropOverlay.IsHitTestVisible = true;
        ViewModel.ControlsHidden = true;
    }

    private void MosuanCropOverlay_OnPointerPressed(object sender, PointerRoutedEventArgs e)
    {
        Point current = e.GetCurrentPoint(MosuanCropOverlay).Position;
        double left = Canvas.GetLeft(MosuanCropSelection);
        double top = Canvas.GetTop(MosuanCropSelection);
        double right = left + MosuanCropSelection.Width;
        double bottom = top + MosuanCropSelection.Height;
        bool inside = _mosuanCropHasSelection
            && MosuanCropSelection.Visibility == Visibility.Visible
            && current.X >= left - 18 && current.X <= right + 18
            && current.Y >= top - 18 && current.Y <= bottom + 18;

        _mosuanCropDragMode = 0; // New selection
        if (inside)
        {
            const double handleRadius = 18;
            bool nearLeft = Math.Abs(current.X - left) <= handleRadius;
            bool nearRight = Math.Abs(current.X - right) <= handleRadius;
            bool nearTop = Math.Abs(current.Y - top) <= handleRadius;
            bool nearBottom = Math.Abs(current.Y - bottom) <= handleRadius;
            if (nearLeft && nearTop) _mosuanCropDragMode = 2 | 8;
            else if (nearRight && nearTop) _mosuanCropDragMode = 4 | 8;
            else if (nearLeft && nearBottom) _mosuanCropDragMode = 2 | 16;
            else if (nearRight && nearBottom) _mosuanCropDragMode = 4 | 16;
            else _mosuanCropDragMode = 1; // Move
        }

        _mosuanCropPointerStart = current;
        _mosuanCropStartRect = inside
            ? new Rect(left, top, MosuanCropSelection.Width, MosuanCropSelection.Height)
            : new Rect(current.X, current.Y, 0, 0);

        if (_mosuanCropDragMode == 0)
        {
            Canvas.SetLeft(MosuanCropSelection, current.X);
            Canvas.SetTop(MosuanCropSelection, current.Y);
            MosuanCropSelection.Width = 0;
            MosuanCropSelection.Height = 0;
            MosuanCropSelection.Visibility = Visibility.Visible;
        }

        _mosuanCropPointerCaptured = MosuanCropOverlay.CapturePointer(e.Pointer);
        e.Handled = true;
    }

    private void MosuanCropOverlay_OnPointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanCropPointerCaptured) return;

        Point current = e.GetCurrentPoint(MosuanCropOverlay).Position;
        double canvasWidth = MosuanCropOverlay.ActualWidth;
        double canvasHeight = MosuanCropOverlay.ActualHeight;
        double dx = current.X - _mosuanCropPointerStart.X;
        double dy = current.Y - _mosuanCropPointerStart.Y;
        double left;
        double top;
        double width;
        double height;

        if (_mosuanCropDragMode == 0)
        {
            double right = Math.Max(_mosuanCropPointerStart.X, current.X);
            double bottom = Math.Max(_mosuanCropPointerStart.Y, current.Y);
            left = Math.Max(0, Math.Min(_mosuanCropPointerStart.X, current.X));
            top = Math.Max(0, Math.Min(_mosuanCropPointerStart.Y, current.Y));
            right = Math.Min(canvasWidth, right);
            bottom = Math.Min(canvasHeight, bottom);
            width = Math.Max(0, right - left);
            height = Math.Max(0, bottom - top);
        }
        else if (_mosuanCropDragMode == 1)
        {
            width = _mosuanCropStartRect.Width;
            height = _mosuanCropStartRect.Height;
            left = Math.Max(0, Math.Min(canvasWidth - width, _mosuanCropStartRect.X + dx));
            top = Math.Max(0, Math.Min(canvasHeight - height, _mosuanCropStartRect.Y + dy));
        }
        else
        {
            left = _mosuanCropStartRect.X;
            top = _mosuanCropStartRect.Y;
            double right = left + _mosuanCropStartRect.Width;
            double bottom = top + _mosuanCropStartRect.Height;

            if ((_mosuanCropDragMode & 2) != 0)
                left = Math.Max(0, Math.Min(right - 24, left + dx));
            if ((_mosuanCropDragMode & 4) != 0)
                right = Math.Min(canvasWidth, Math.Max(left + 24, right + dx));
            if ((_mosuanCropDragMode & 8) != 0)
                top = Math.Max(0, Math.Min(bottom - 24, top + dy));
            if ((_mosuanCropDragMode & 16) != 0)
                bottom = Math.Min(canvasHeight, Math.Max(top + 24, bottom + dy));

            width = Math.Max(0, right - left);
            height = Math.Max(0, bottom - top);
        }

        Canvas.SetLeft(MosuanCropSelection, left);
        Canvas.SetTop(MosuanCropSelection, top);
        MosuanCropSelection.Width = width;
        MosuanCropSelection.Height = height;
        MosuanUpdateCropHandles();
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

        MosuanCropOverlay.Opacity = 0;
        MosuanCropOverlay.IsHitTestVisible = false;
        if (width > 0 && height > 0 && cropWidth >= 24 && cropHeight >= 24)
        {
            _mosuanCropViewportRect = new Rect(left / width, top / height, cropWidth / width, cropHeight / height);
            _mosuanCropHasSelection = true;
            WeakReferenceMessenger.Default.Send(new ChangeNormalizedCropMessage(_mosuanCropViewportRect));
        }

        ViewModel.ControlsHidden = false;
        e.Handled = true;
    }

    private void MosuanCropOverlay_OnPointerCanceled(object sender, PointerRoutedEventArgs e)
    {
        _mosuanCropPointerCaptured = false;
        MosuanCropOverlay.Opacity = 0;
        MosuanCropOverlay.IsHitTestVisible = false;
        if (_mosuanCropHasSelection)
        {
            double width = MosuanCropOverlay.ActualWidth;
            double height = MosuanCropOverlay.ActualHeight;
            Canvas.SetLeft(MosuanCropSelection, _mosuanCropViewportRect.X * width);
            Canvas.SetTop(MosuanCropSelection, _mosuanCropViewportRect.Y * height);
            MosuanCropSelection.Width = _mosuanCropViewportRect.Width * width;
            MosuanCropSelection.Height = _mosuanCropViewportRect.Height * height;
            MosuanUpdateCropHandles();
        }
        ViewModel.ControlsHidden = false;
    }

    private void MosuanUpdateCropHandles()
    {
        double left = Canvas.GetLeft(MosuanCropSelection);
        double top = Canvas.GetTop(MosuanCropSelection);
        double right = left + MosuanCropSelection.Width;
        double bottom = top + MosuanCropSelection.Height;
        Canvas.SetLeft(MosuanCropHandleTopLeft, left - 6);
        Canvas.SetTop(MosuanCropHandleTopLeft, top - 6);
        Canvas.SetLeft(MosuanCropHandleTopRight, right - 6);
        Canvas.SetTop(MosuanCropHandleTopRight, top - 6);
        Canvas.SetLeft(MosuanCropHandleBottomLeft, left - 6);
        Canvas.SetTop(MosuanCropHandleBottomLeft, bottom - 6);
        Canvas.SetLeft(MosuanCropHandleBottomRight, right - 6);
        Canvas.SetTop(MosuanCropHandleBottomRight, bottom - 6);
        MosuanSetCropHandlesVisible(true);
    }

    private void MosuanSetCropHandlesVisible(bool visible)
    {
        Visibility state = visible ? Visibility.Visible : Visibility.Collapsed;
        MosuanCropHandleTopLeft.Visibility = state;
        MosuanCropHandleTopRight.Visibility = state;
        MosuanCropHandleBottomLeft.Visibility = state;
        MosuanCropHandleBottomRight.Visibility = state;
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
        _mosuanCropHasSelection = false;
        MosuanCropOverlay.Opacity = 0;
        MosuanCropOverlay.IsHitTestVisible = false;
        MosuanCropSelection.Visibility = Visibility.Collapsed;
        MosuanSetCropHandlesVisible(false);
        WeakReferenceMessenger.Default.Send(new ChangeAspectRatioMessage(new Size(0, 0)));
    }
'@
    $lastBrace = $code.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw 'PlayerPage class closing brace not found for aspect handlers' }
    $code = $code.Insert($lastBrace, $handlers + [Environment]::NewLine)
}
Set-Content -Path $codePath -Value $code -Encoding UTF8

Write-Host 'Mosuan video tools v2 applied: aspect presets, reset, and drag-to-select free crop.'
