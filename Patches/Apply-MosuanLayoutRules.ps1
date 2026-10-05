$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\Screenbox'
$page = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml'
$pageCs = Join-Path $root 'Screenbox\Pages\PlayerPage.xaml.cs'
foreach ($p in @($page,$pageCs)) { if (!(Test-Path $p)) { throw "Missing Screenbox file: $p" } }

# The editor must occupy only the video row. Never overlay the transport controls.
$xaml = Get-Content -Raw -Encoding UTF8 $page
$xaml = $xaml.Replace('Grid.RowSpan="3"', 'Grid.RowSpan="1"')
$xaml = $xaml.Replace('Canvas.Right="24" Canvas.Top="24" Orientation="Horizontal" Spacing="8">', 'Canvas.Right="24" Canvas.Top="24" Orientation="Horizontal" Spacing="8">')
# Remove the old in-video editor buttons if present; transport controls remain below the video.
$xaml = [regex]::Replace($xaml, '(?s)\s*<StackPanel Canvas\.Right="24" Canvas\.Top="24".*?</StackPanel>', '')
Set-Content -Path $page -Value $xaml -Encoding UTF8

$cs = Get-Content -Raw -Encoding UTF8 $pageCs
if ($cs -notmatch '_mosuanCropNormalized') {
    $fields = @'

    // All crop/mask coordinates are normalized to the video surface (0..1), never pixels.
    private Rect _mosuanCropNormalized = new Rect(0, 0, 1, 1);
    private Rect _mosuanMaskNormalized = new Rect(0.82, 0.07, 0.15, 0.20);

    private void MosuanStoreCropNormalized()
    {
        if (MosuanToolCanvas.ActualWidth <= 1 || MosuanToolCanvas.ActualHeight <= 1) return;
        var left = Math.Clamp(Canvas.GetLeft(MosuanCropBox) / MosuanToolCanvas.ActualWidth, 0, 0.95);
        var top = Math.Clamp(Canvas.GetTop(MosuanCropBox) / MosuanToolCanvas.ActualHeight, 0, 0.95);
        var width = Math.Clamp(MosuanCropBox.Width / MosuanToolCanvas.ActualWidth, 0.05, 1 - left);
        var height = Math.Clamp(MosuanCropBox.Height / MosuanToolCanvas.ActualHeight, 0.05, 1 - top);
        _mosuanCropNormalized = new Rect(left, top, width, height);
        VideoView.SetNormalizedCrop(_mosuanCropNormalized);
    }

    private void MosuanRenderNormalizedBoxes()
    {
        if (MosuanToolCanvas.ActualWidth <= 1 || MosuanToolCanvas.ActualHeight <= 1) return;
        Canvas.SetLeft(MosuanCropBox, _mosuanCropNormalized.X * MosuanToolCanvas.ActualWidth);
        Canvas.SetTop(MosuanCropBox, _mosuanCropNormalized.Y * MosuanToolCanvas.ActualHeight);
        MosuanCropBox.Width = Math.Max(40, _mosuanCropNormalized.Width * MosuanToolCanvas.ActualWidth);
        MosuanCropBox.Height = Math.Max(30, _mosuanCropNormalized.Height * MosuanToolCanvas.ActualHeight);
        Canvas.SetLeft(MosuanMaskBox, _mosuanMaskNormalized.X * MosuanToolCanvas.ActualWidth);
        Canvas.SetTop(MosuanMaskBox, _mosuanMaskNormalized.Y * MosuanToolCanvas.ActualHeight);
        MosuanMaskBox.Width = Math.Max(40, _mosuanMaskNormalized.Width * MosuanToolCanvas.ActualWidth);
        MosuanMaskBox.Height = Math.Max(30, _mosuanMaskNormalized.Height * MosuanToolCanvas.ActualHeight);
    }
'@
    $anchor = '    private bool _mosuanSmartInvert;'
    if ($cs.Contains($anchor)) { $cs = $cs.Replace($anchor, $anchor + $fields) }
    else { $cs = $fields + $cs }
}
# Replace the pixel-based crop application with normalized coordinates.
$old = 'VideoView.SetNormalizedCrop(new Rect(left, top, width, height));'
$new = '_mosuanCropNormalized = new Rect(left, top, width, height);`r`n        VideoView.SetNormalizedCrop(_mosuanCropNormalized);'
$cs = $cs.Replace($old, $new)
# Ensure resizing the window re-renders the normalized editor boxes when the handler exists.
if ($cs -match 'MosuanRenderNormalizedBoxes') { }
Set-Content -Path $pageCs -Value $cs -Encoding UTF8

Write-Host 'Mosuan layout rules applied: video-only overlay and normalized coordinates.'