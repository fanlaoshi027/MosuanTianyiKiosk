$ErrorActionPreference = 'Stop'
$nl = [Environment]::NewLine

$coreRoot = Join-Path $PSScriptRoot '..\Screenbox.Core'
$messagePath = Join-Path $coreRoot 'Messages\ChangeNormalizedCropMessage.cs'
$viewModelPath = Join-Path $coreRoot 'ViewModels\PlayerElementViewModel.cs'
$vlcPlayerPath = Join-Path $coreRoot 'Playback\VlcMediaPlayer.cs'

foreach ($path in @($viewModelPath, $vlcPlayerPath)) {
    if (!(Test-Path $path)) { throw "Required crop pipeline file not found: $path" }
}

# Add a message carrying a normalized source rectangle (0..1 coordinates).
if (!(Test-Path $messagePath)) {
    @'
using CommunityToolkit.Mvvm.Messaging.Messages;
using Windows.Foundation;

namespace Screenbox.Core.Messages;

public sealed class ChangeNormalizedCropMessage : ValueChangedMessage<Rect>
{
    public ChangeNormalizedCropMessage(Rect value) : base(value)
    {
    }
}
'@ | Set-Content -Path $messagePath -Encoding UTF8
}

# Extend the existing player view-model crop pipeline.
$code = Get-Content -Raw -Encoding UTF8 $viewModelPath
if (!$code.Contains('IRecipient<ChangeNormalizedCropMessage>')) {
    $anchor = 'IRecipient<SettingsChangedMessage>'
    if (!$code.Contains($anchor)) { throw 'PlayerElementViewModel recipient declaration anchor not found' }
    $code = $code.Replace($anchor, $anchor + ',' + $nl + '    IRecipient<ChangeNormalizedCropMessage>')
}
if (!$code.Contains('Messenger.Register<ChangeNormalizedCropMessage>(this);')) {
    $anchor = 'Messenger.Register<SettingsChangedMessage>(this);'
    if (!$code.Contains($anchor)) { throw 'PlayerElementViewModel message registration anchor not found' }
    $code = $code.Replace($anchor, $anchor + $nl + '        Messenger.Register<ChangeNormalizedCropMessage>(this);')
}
if (!$code.Contains('public void Receive(ChangeNormalizedCropMessage message)')) {
    $anchor = '    public void Initialize(string[] swapChainOptions)'
    if (!$code.Contains($anchor)) { throw 'PlayerElementViewModel Initialize anchor not found' }
    $handler = @'
    public void Receive(ChangeNormalizedCropMessage message)
    {
        if (VlcMediaPlayer is null) return;

        Rect rect = message.Value;
        if (double.IsNaN(rect.X) || double.IsNaN(rect.Y)
            || double.IsNaN(rect.Width) || double.IsNaN(rect.Height)
            || double.IsInfinity(rect.X) || double.IsInfinity(rect.Y)
            || double.IsInfinity(rect.Width) || double.IsInfinity(rect.Height)
            || rect.X < 0 || rect.Y < 0 || rect.Width <= 0 || rect.Height <= 0
            || rect.X + rect.Width > 1 || rect.Y + rect.Height > 1)
        {
            return;
        }

        VlcMediaPlayer.NormalizedSourceRect = rect;
    }

'@
    $code = $code.Replace($anchor, $handler + $anchor)
}
Set-Content -Path $viewModelPath -Value $code -Encoding UTF8

# The upstream normalized-rectangle setter previously applied only width:height,
# silently discarding X/Y. Use LibVLC's crop-window geometry so free crop can move.
$vlcCode = Get-Content -Raw -Encoding UTF8 $vlcPlayerPath
$oldCrop = @'
                // Use crop ratio to avoid conflict with subtitle rendering
                double newWidth = value.Width * NaturalVideoWidth;
                double newHeight = value.Height * NaturalVideoHeight;
                VlcPlayer.CropGeometry = $"{newWidth:F0}:{newHeight:F0}";
'@
$newCrop = @'
                // Apply the complete normalized crop window (width x height + left + top).
                double newWidth = value.Width * NaturalVideoWidth;
                double newHeight = value.Height * NaturalVideoHeight;
                double leftOffset = value.X * NaturalVideoWidth;
                double topOffset = value.Y * NaturalVideoHeight;
                VlcPlayer.CropGeometry = $"{newWidth:F0}x{newHeight:F0}+{leftOffset:F0}+{topOffset:F0}";
'@
if ($vlcCode.Contains($oldCrop)) {
    $vlcCode = $vlcCode.Replace($oldCrop, $newCrop)
}
elseif (!$vlcCode.Contains('value.X * NaturalVideoWidth')) {
    throw 'VlcMediaPlayer normalized crop geometry anchor not found'
}
Set-Content -Path $vlcPlayerPath -Value $vlcCode -Encoding UTF8

Write-Host 'Mosuan crop pipeline v3 applied: normalized crop messages now preserve crop position and size.'
