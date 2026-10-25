$ErrorActionPreference = 'Stop'

$screenboxRoot = Join-Path $PSScriptRoot '..\Screenbox'
$project = Join-Path $screenboxRoot 'Screenbox\Screenbox.csproj'
$elementXaml = Join-Path $screenboxRoot 'Screenbox\Controls\PlayerElement.xaml'
$elementCode = Join-Path $screenboxRoot 'Screenbox\Controls\PlayerElement.xaml.cs'
$controlsXaml = Join-Path $screenboxRoot 'Screenbox\Controls\PlayerControls.xaml'
$controlsCode = Join-Path $screenboxRoot 'Screenbox\Controls\PlayerControls.xaml.cs'

foreach ($path in @($project, $elementXaml, $elementCode, $controlsXaml, $controlsCode)) {
    if (!(Test-Path $path)) { throw "Required Screenbox file not found: $path" }
}

# Win2D provides the ColorMatrixEffect used by the composition backdrop overlay.
$projectText = Get-Content -Raw -Encoding UTF8 $project
if ($projectText -notmatch 'Win2D\.uwp') {
    $anchor = '<PackageReference Include="Microsoft.UI.Xaml"'
    if (!$projectText.Contains($anchor)) { throw 'Could not find Microsoft.UI.Xaml package anchor.' }
    $insert = '<PackageReference Include="Win2D.uwp" Version="1.28.3" />' + [Environment]::NewLine + '    ' + $anchor
    $projectText = $projectText.Replace($anchor, $insert)
    Set-Content -Path $project -Value $projectText -Encoding UTF8
}

# Put the inversion toggle in the actual playback control bar, not over the video/window chrome.
$controlsXamlText = Get-Content -Raw -Encoding UTF8 $controlsXaml
if ($controlsXamlText -notmatch 'x:Name="InvertButton"') {
    $anchor = @'
            <controls:VolumeControl
                x:Name="VolumeControl"
                Width="140"
                Margin="0,0,8,0"
                ShowValueText="False"
                VolumeToggleButtonStyle="{StaticResource PlayerToggleButtonStyle}" />
'@
    if (!$controlsXamlText.Contains($anchor)) { throw 'Could not find VolumeControl anchor in PlayerControls.xaml.' }
    $insert = $anchor + @'

            <!-- Mosuan video inversion toggle -->
            <ToggleButton
                x:Name="InvertButton"
                Margin="0,0,4,0"
                Content="反色"
                AutomationProperties.Name="视频反色"
                IsEnabled="{x:Bind ViewModel.HasVideo, Mode=OneWay}"
                Style="{StaticResource PlayerToggleButtonStyle}"
                Checked="InvertButton_OnChecked"
                Unchecked="InvertButton_OnUnchecked">
                <ToggleButton.KeyboardAccelerators>
                    <KeyboardAccelerator Key="I" Modifiers="Control" Invoked="InvertKeyboardAccelerator_OnInvoked" />
                </ToggleButton.KeyboardAccelerators>
            </ToggleButton>
'@
    $controlsXamlText = $controlsXamlText.Replace($anchor, $insert.TrimEnd())
    Set-Content -Path $controlsXaml -Value $controlsXamlText -Encoding UTF8
}

# Wire the control-bar toggle to the PlayerElement that owns the video surface.
$controlsCodeText = Get-Content -Raw -Encoding UTF8 $controlsCode
if ($controlsCodeText -notmatch 'InvertButton_OnChecked') {
    $anchor = '    private bool IsCastButtonEnabled(bool hasActiveItem)'
    if (!$controlsCodeText.Contains($anchor)) { throw 'Could not find PlayerControls code insertion point.' }
    $methods = @'
    private void InvertButton_OnChecked(object sender, RoutedEventArgs e)
    {
        PlayerElement.RequestInversion(true);
    }

    private void InvertButton_OnUnchecked(object sender, RoutedEventArgs e)
    {
        PlayerElement.RequestInversion(false);
    }

    private void InvertKeyboardAccelerator_OnInvoked(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        InvertButton.IsChecked = !(InvertButton.IsChecked ?? false);
        args.Handled = true;
    }

'@
    $controlsCodeText = $controlsCodeText.Replace($anchor, $methods + $anchor)
    Set-Content -Path $controlsCode -Value $controlsCodeText -Encoding UTF8
}

$elementXamlText = Get-Content -Raw -Encoding UTF8 $elementXaml
if ($elementXamlText -notmatch 'Loaded="OnLoaded"') {
    $elementXamlText = $elementXamlText.Replace('    Unloaded="OnUnloaded"', '    Loaded="OnLoaded"' + [Environment]::NewLine + '    Unloaded="OnUnloaded"')
    Set-Content -Path $elementXaml -Value $elementXamlText -Encoding UTF8
}

$elementCodeText = Get-Content -Raw -Encoding UTF8 $elementCode
if ($elementCodeText -notmatch 'RequestInversion') {
    $usingAnchor = 'using CommunityToolkit.Mvvm.DependencyInjection;'
    if (!$elementCodeText.Contains($usingAnchor)) { throw 'Could not find PlayerElement using anchor.' }
    $usingInsert = $usingAnchor + [Environment]::NewLine + 'using System;' + [Environment]::NewLine + 'using System.Numerics;' + [Environment]::NewLine + 'using Microsoft.Graphics.Canvas.Effects;
using Windows.System;' + [Environment]::NewLine + 'using Windows.UI.Composition;' + [Environment]::NewLine + 'using Windows.UI.Xaml.Hosting;'
    $elementCodeText = $elementCodeText.Replace($usingAnchor, $usingInsert)

    $eventAnchor = '    public event RoutedEventHandler? Click;'
    if (!$elementCodeText.Contains($eventAnchor)) { throw 'Could not find PlayerElement event anchor.' }
    $elementCodeText = $elementCodeText.Replace($eventAnchor, $eventAnchor + [Environment]::NewLine + [Environment]::NewLine + '    public static event Action<bool>? InversionRequested;' + [Environment]::NewLine + '    public static void RequestInversion(bool enabled) => InversionRequested?.Invoke(enabled);')

    $unloadedAnchor = '    private void OnUnloaded(object sender, RoutedEventArgs e)' + [Environment]::NewLine + '    {'
    if (!$elementCodeText.Contains($unloadedAnchor)) { throw 'Could not find OnUnloaded anchor.' }
    $elementCodeText = $elementCodeText.Replace($unloadedAnchor, $unloadedAnchor + [Environment]::NewLine + '        InversionRequested -= SetInversion;')

    $loadedAnchor = '    private void VlcVideoView_OnInitialized(object sender, VideoViewInitializedEventArgs e)'
    if (!$elementCodeText.Contains($loadedAnchor)) { throw 'Could not find VlcVideoView initialization anchor.' }
    $loadedMethod = @'
    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        InversionRequested -= SetInversion;
        InversionRequested += SetInversion;
    }

'@
    $elementCodeText = $elementCodeText.Replace($loadedAnchor, $loadedMethod + $loadedAnchor)

    $resizeAnchor = '        ViewModel.UpdatePlayerViewSize(e.NewSize);'
    if (!$elementCodeText.Contains($resizeAnchor)) { throw 'Could not find video size-change anchor.' }
    $elementCodeText = $elementCodeText.Replace($resizeAnchor, $resizeAnchor + [Environment]::NewLine + '        if (_invertOverlay is not null) _invertOverlay.Size = new Vector2((float)e.NewSize.Width, (float)e.NewSize.Height);')

    $method = @'

    private SpriteVisual? _invertOverlay;
    private bool _isInverted;

    private void SetInversion(bool enabled)
    {
        if (_isInverted == enabled) return;
        _isInverted = enabled;

        if (!_isInverted)
        {
            ElementCompositionPreview.SetElementChildVisual(VlcVideoView, null);
            _invertOverlay = null;
            return;
        }

        var compositor = ElementCompositionPreview.GetElementVisual(VlcVideoView).Compositor;

        // Match the website's CSS filter order: brightness(0.9) -> invert(1) -> hue-rotate(180deg).
        var effect = new HueRotationEffect
        {
            Name = "MosuanHueRotation",
            Angle = 180.0f,
            Source = new ColorMatrixEffect
            {
                Name = "MosuanInvert",
                ColorMatrix = new Matrix5x4
                {
                    M11 = -1.0f, M22 = -1.0f, M33 = -1.0f, M44 = 1.0f,
                    M51 = 1.0f, M52 = 1.0f, M53 = 1.0f
                },
                Source = new ColorMatrixEffect
                {
                    Name = "MosuanBrightness",
                    ColorMatrix = new Matrix5x4
                    {
                        M11 = 0.9f, M22 = 0.9f, M33 = 0.9f, M44 = 1.0f
                    },
                    Source = new CompositionEffectSourceParameter("source")
                }
            }
        };

        var factory = compositor.CreateEffectFactory(effect);
        var brush = factory.CreateBrush();
        brush.SetSourceParameter("source", compositor.CreateBackdropBrush());

        _invertOverlay = compositor.CreateSpriteVisual();
        _invertOverlay.Brush = brush;
        _invertOverlay.Size = new Vector2((float)VlcVideoView.ActualWidth, (float)VlcVideoView.ActualHeight);
        ElementCompositionPreview.SetElementChildVisual(VlcVideoView, _invertOverlay);
    }

'@
    $lastBrace = $elementCodeText.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw 'Could not find PlayerElement class closing brace.' }
    $elementCodeText = $elementCodeText.Insert($lastBrace, $method)
    Set-Content -Path $elementCode -Value $elementCodeText -Encoding UTF8
}

Write-Host 'Mosuan inversion toggle moved to PlayerControls playback bar.'
