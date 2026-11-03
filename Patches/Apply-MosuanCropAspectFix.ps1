$ErrorActionPreference = 'Stop'
$nl = [Environment]::NewLine

function Replace-CSharpMethod([string]$Source, [string]$Signature, [string]$Replacement) {
    $start = $Source.IndexOf($Signature, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "C# method anchor not found: $Signature" }
    $open = $Source.IndexOf('{', $start)
    if ($open -lt 0) { throw "C# method body not found: $Signature" }
    $depth = 0
    $inString = $false
    $verbatim = $false
    $escaped = $false
    for ($i = $open; $i -lt $Source.Length; $i++) {
        $ch = $Source[$i]
        if ($inString) {
            if ($verbatim) {
                if ($ch -eq '"' -and $i + 1 -lt $Source.Length -and $Source[$i + 1] -eq '"') { $i++; continue }
                if ($ch -eq '"') { $inString = $false; $verbatim = $false }
            } elseif ($escaped) { $escaped = $false }
            elseif ($ch -eq '\') { $escaped = $true }
            elseif ($ch -eq '"') { $inString = $false }
            continue
        }
        if ($ch -eq '"') {
            $inString = $true
            $verbatim = ($i -gt 0 -and $Source[$i - 1] -eq '@')
            continue
        }
        if ($ch -eq '{') { $depth++ }
        elseif ($ch -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $Source.Substring(0, $start) + $Replacement + $Source.Substring($i + 1)
            }
        }
    }
    throw "Unbalanced C# method body: $Signature"
}

$screenbox = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$core = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.Core'
$pagePath = Join-Path $screenbox 'Pages\PlayerPage.xaml.cs'
$xamlPath = Join-Path $screenbox 'Pages\PlayerPage.xaml'
$viewModelPath = Join-Path $core 'ViewModels\PlayerElementViewModel.cs'
foreach ($path in @($pagePath, $xamlPath, $viewModelPath)) {
    if (!(Test-Path $path)) { throw "Required crop file not found: $path" }
}

# The overlay selection is now expressed as percentages of the actual video image,
# not percentages of the whole PlayerPage/VideoView rectangle.
$page = Get-Content -Raw -Encoding UTF8 $pagePath
if (!$page.Contains('private Rect MosuanGetVideoContentRect()')) {
    $anchor = '    private bool _startup;'
    if (!$page.Contains($anchor)) { throw 'PlayerPage field insertion anchor not found' }
    $fields = @'
    private bool _mosuanCropPointerCaptured;
    private bool _mosuanCropHasSelection;
    private int _mosuanCropDragMode;
    private Point _mosuanCropPointerStart;
    private Rect _mosuanCropStartRect;
    private Rect _mosuanCropViewportRect = new(0, 0, 1, 1);

'@
    if (!$page.Contains('private bool _mosuanCropPointerCaptured;')) {
        $page = $page.Replace($anchor, $anchor + $nl + $fields)
    }
    $helpers = @'

    private Rect MosuanGetVideoContentRect()
    {
        double viewWidth = MosuanCropOverlay.ActualWidth;
        double viewHeight = MosuanCropOverlay.ActualHeight;
        int naturalWidth = VideoView.ViewModel.CurrentNaturalVideoWidth;
        int naturalHeight = VideoView.ViewModel.CurrentNaturalVideoHeight;
        if (viewWidth <= 0 || viewHeight <= 0 || naturalWidth <= 0 || naturalHeight <= 0)
        {
            return new Rect(0, 0, viewWidth, viewHeight);
        }

        Rect source = VideoView.ViewModel.CurrentNormalizedSourceRect;
        double sourceWidth = naturalWidth * source.Width;
        double sourceHeight = naturalHeight * source.Height;
        if (sourceWidth <= 0 || sourceHeight <= 0) return new Rect(0, 0, viewWidth, viewHeight);

        double scale = Math.Min(viewWidth / sourceWidth, viewHeight / sourceHeight);
        double imageWidth = sourceWidth * scale;
        double imageHeight = sourceHeight * scale;
        return new Rect((viewWidth - imageWidth) / 2, (viewHeight - imageHeight) / 2, imageWidth, imageHeight);
    }

    private static Point MosuanClampToRect(Point point, Rect bounds)
    {
        return new Point(
            Math.Max(bounds.Left, Math.Min(bounds.Right, point.X)),
            Math.Max(bounds.Top, Math.Min(bounds.Bottom, point.Y)));
    }

    private void MosuanDrawCropSelection()
    {
        Rect bounds = MosuanGetVideoContentRect();
        Canvas.SetLeft(MosuanCropSelection, bounds.X + _mosuanCropViewportRect.X * bounds.Width);
        Canvas.SetTop(MosuanCropSelection, bounds.Y + _mosuanCropViewportRect.Y * bounds.Height);
        MosuanCropSelection.Width = _mosuanCropViewportRect.Width * bounds.Width;
        MosuanCropSelection.Height = _mosuanCropViewportRect.Height * bounds.Height;
        MosuanCropSelection.Visibility = Visibility.Visible;
        MosuanUpdateCropHandles();
    }
'@
    $lastBrace = $page.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw 'PlayerPage class closing brace not found for crop helpers' }
    $page = $page.Insert($lastBrace, $helpers + $nl)
}

$begin = @'
    private void MosuanBeginFreeCrop_OnClick(object sender, RoutedEventArgs e)
    {
        Rect bounds = MosuanGetVideoContentRect();
        if (bounds.Width < 2 || bounds.Height < 2) return;

        if (_mosuanCropHasSelection)
            MosuanDrawCropSelection();
        else
        {
            MosuanCropSelection.Visibility = Visibility.Collapsed;
            MosuanSetCropHandlesVisible(false);
        }

        MosuanCropOverlay.Opacity = 1;
        MosuanCropOverlay.IsHitTestVisible = true;
        ViewModel.ControlsHidden = true;
    }
'@
$page = Replace-CSharpMethod $page 'private void MosuanBeginFreeCrop_OnClick(' $begin

$pressed = @'
    private void MosuanCropOverlay_OnPointerPressed(object sender, PointerRoutedEventArgs e)
    {
        Rect bounds = MosuanGetVideoContentRect();
        Point current = MosuanClampToRect(e.GetCurrentPoint(MosuanCropOverlay).Position, bounds);
        double left = Canvas.GetLeft(MosuanCropSelection);
        double top = Canvas.GetTop(MosuanCropSelection);
        double right = left + MosuanCropSelection.Width;
        double bottom = top + MosuanCropSelection.Height;
        bool inside = _mosuanCropHasSelection
            && MosuanCropSelection.Visibility == Visibility.Visible
            && current.X >= left - 18 && current.X <= right + 18
            && current.Y >= top - 18 && current.Y <= bottom + 18;

        _mosuanCropDragMode = 0;
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
            else _mosuanCropDragMode = 1;
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
'@
$page = Replace-CSharpMethod $page 'private void MosuanCropOverlay_OnPointerPressed(' $pressed

$moved = @'
    private void MosuanCropOverlay_OnPointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanCropPointerCaptured) return;

        Rect bounds = MosuanGetVideoContentRect();
        Point current = MosuanClampToRect(e.GetCurrentPoint(MosuanCropOverlay).Position, bounds);
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
            left = Math.Max(bounds.Left, Math.Min(_mosuanCropPointerStart.X, current.X));
            top = Math.Max(bounds.Top, Math.Min(_mosuanCropPointerStart.Y, current.Y));
            right = Math.Min(bounds.Right, right);
            bottom = Math.Min(bounds.Bottom, bottom);
            width = Math.Max(0, right - left);
            height = Math.Max(0, bottom - top);
        }
        else if (_mosuanCropDragMode == 1)
        {
            width = _mosuanCropStartRect.Width;
            height = _mosuanCropStartRect.Height;
            left = Math.Max(bounds.Left, Math.Min(bounds.Right - width, _mosuanCropStartRect.X + dx));
            top = Math.Max(bounds.Top, Math.Min(bounds.Bottom - height, _mosuanCropStartRect.Y + dy));
        }
        else
        {
            left = _mosuanCropStartRect.X;
            top = _mosuanCropStartRect.Y;
            double right = left + _mosuanCropStartRect.Width;
            double bottom = top + _mosuanCropStartRect.Height;

            if ((_mosuanCropDragMode & 2) != 0) left = Math.Max(bounds.Left, Math.Min(right - 24, left + dx));
            if ((_mosuanCropDragMode & 4) != 0) right = Math.Min(bounds.Right, Math.Max(left + 24, right + dx));
            if ((_mosuanCropDragMode & 8) != 0) top = Math.Max(bounds.Top, Math.Min(bottom - 24, top + dy));
            if ((_mosuanCropDragMode & 16) != 0) bottom = Math.Min(bounds.Bottom, Math.Max(top + 24, bottom + dy));

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
'@
$page = Replace-CSharpMethod $page 'private void MosuanCropOverlay_OnPointerMoved(' $moved

$released = @'
    private void MosuanCropOverlay_OnPointerReleased(object sender, PointerRoutedEventArgs e)
    {
        if (!_mosuanCropPointerCaptured) return;
        _mosuanCropPointerCaptured = false;
        MosuanCropOverlay.ReleasePointerCapture(e.Pointer);

        Rect bounds = MosuanGetVideoContentRect();
        double left = Canvas.GetLeft(MosuanCropSelection);
        double top = Canvas.GetTop(MosuanCropSelection);
        double cropWidth = MosuanCropSelection.Width;
        double cropHeight = MosuanCropSelection.Height;

        MosuanCropOverlay.Opacity = 0;
        MosuanCropOverlay.IsHitTestVisible = false;
        if (bounds.Width > 0 && bounds.Height > 0 && cropWidth >= 24 && cropHeight >= 24)
        {
            // Persist percentages relative to the visible video image, never the window.
            _mosuanCropViewportRect = new Rect(
                Math.Clamp((left - bounds.Left) / bounds.Width, 0, 1),
                Math.Clamp((top - bounds.Top) / bounds.Height, 0, 1),
                Math.Clamp(cropWidth / bounds.Width, 0, 1),
                Math.Clamp(cropHeight / bounds.Height, 0, 1));
            WeakReferenceMessenger.Default.Send(new ChangeNormalizedCropMessage(_mosuanCropViewportRect));
            // VLC now displays the selected source rectangle as the new full frame.
            // The next crop gesture therefore starts fresh against that current frame.
            _mosuanCropViewportRect = new Rect(0, 0, 1, 1);
            _mosuanCropHasSelection = false;
        }

        ViewModel.ControlsHidden = false;
        e.Handled = true;
    }
'@
$page = Replace-CSharpMethod $page 'private void MosuanCropOverlay_OnPointerReleased(' $released

$cancelled = @'
    private void MosuanCropOverlay_OnPointerCanceled(object sender, PointerRoutedEventArgs e)
    {
        if (_mosuanCropPointerCaptured)
            MosuanCropOverlay.ReleasePointerCapture(e.Pointer);
        _mosuanCropPointerCaptured = false;
        MosuanCropOverlay.Opacity = 0;
        MosuanCropOverlay.IsHitTestVisible = false;
        if (_mosuanCropHasSelection)
            MosuanDrawCropSelection();
        ViewModel.ControlsHidden = false;
    }
'@
$page = Replace-CSharpMethod $page 'private void MosuanCropOverlay_OnPointerCanceled(' $cancelled
Set-Content -Path $pagePath -Value $page -Encoding UTF8

# The message now carries image-relative percentages. Compose them directly with
# the current normalized source rectangle; do not infer percentages from window size.
$vm = Get-Content -Raw -Encoding UTF8 $viewModelPath
if (!$vm.Contains('VlcMediaPlayer? VlcMediaPlayer')) {
    $anchor = '    public MediaPlayer? VlcPlayer =>'
    $index = $vm.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($index -lt 0) { throw 'PlayerElementViewModel VlcPlayer property anchor not found' }
    $vm = $vm.Insert($index, '    private VlcMediaPlayer? VlcMediaPlayer => _playerContext.MediaPlayer as VlcMediaPlayer;' + [Environment]::NewLine)
}
if (!$vm.Contains('CurrentNormalizedSourceRect')) {
    $anchor = '    public MediaPlayer? VlcPlayer =>'
    $index = $vm.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($index -lt 0) { throw 'PlayerElementViewModel VlcPlayer property anchor not found' }
    $lineEnd = $vm.IndexOf([Environment]::NewLine, $index)
    if ($lineEnd -lt 0) { throw 'PlayerElementViewModel VlcPlayer property line end not found' }
    $property = [Environment]::NewLine + '    public Rect CurrentNormalizedSourceRect => VlcMediaPlayer?.NormalizedSourceRect ?? new Rect(0, 0, 1, 1);' + [Environment]::NewLine + '    public uint CurrentNaturalVideoWidth => VlcMediaPlayer?.NaturalVideoWidth ?? 0u;' + [Environment]::NewLine + '    public uint CurrentNaturalVideoHeight => VlcMediaPlayer?.NaturalVideoHeight ?? 0u;'
    $vm = $vm.Insert($lineEnd, $property)
}
$receive = @'
    public void Receive(ChangeNormalizedCropMessage message)
    {
        if (VlcMediaPlayer is null) return;

        Rect selection = message.Value;
        if (double.IsNaN(selection.X) || double.IsNaN(selection.Y)
            || double.IsNaN(selection.Width) || double.IsNaN(selection.Height)
            || double.IsInfinity(selection.X) || double.IsInfinity(selection.Y)
            || double.IsInfinity(selection.Width) || double.IsInfinity(selection.Height)
            || selection.X < 0 || selection.Y < 0 || selection.Width <= 0 || selection.Height <= 0
            || selection.X + selection.Width > 1.000001 || selection.Y + selection.Height > 1.000001)
        {
            return;
        }

        Rect current = VlcMediaPlayer.NormalizedSourceRect;
        double x = current.X + selection.X * current.Width;
        double y = current.Y + selection.Y * current.Height;
        double width = selection.Width * current.Width;
        double height = selection.Height * current.Height;

        _mosuanHasManualCrop = true;
        VlcMediaPlayer.NormalizedSourceRect = new Rect(x, y, width, height);
    }
'@
$vm = Replace-CSharpMethod $vm 'public void Receive(ChangeNormalizedCropMessage message)' $receive
Set-Content -Path $viewModelPath -Value $vm -Encoding UTF8

Write-Host 'Mosuan crop aspect fix applied: selection and crop coordinates are image-relative percentages, independent of window size.'
