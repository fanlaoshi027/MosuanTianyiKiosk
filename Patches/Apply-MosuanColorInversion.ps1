$ErrorActionPreference = 'Stop'

$screenboxRoot = Join-Path $PSScriptRoot '..\Screenbox'
$project = Join-Path $screenboxRoot 'Screenbox\Screenbox.csproj'
$xaml = Join-Path $screenboxRoot 'Screenbox\Controls\PlayerElement.xaml'
$code = Join-Path $screenboxRoot 'Screenbox\Controls\PlayerElement.xaml.cs'

foreach ($path in @($project, $xaml, $code)) {
    if (!(Test-Path $path)) { throw "Required Screenbox file not found: $path" }
}

# Win2D provides the ColorMatrixEffect used by the composition backdrop overlay.
$projectText = Get-Content -Raw -Encoding UTF8 $project
if ($projectText -notmatch 'Microsoft\.Graphics\.Win2D') {
    $anchor = '<PackageReference Include="Microsoft.UI.Xaml"'
    if (!$projectText.Contains($anchor)) { throw 'Could not find Microsoft.UI.Xaml package anchor.' }
    $insert = '<PackageReference Include="Win2D.uwp" Version="1.28.3" />' + [Environment]::NewLine + '    ' + $anchor
    $projectText = $projectText.Replace($anchor, $insert)
    Set-Content -Path $project -Value $projectText -Encoding UTF8
}

# Add a small first-pass toggle above the video surface.
$xamlText = Get-Content -Raw -Encoding UTF8 $xaml
if ($xamlText -notmatch 'x:Name="InvertButton"') {
    $anchor = '            SizeChanged="VlcVideoView_OnSizeChanged" />'
    if (!$xamlText.Contains($anchor)) { throw 'Could not find VideoView XAML anchor.' }
    $button = @'
            SizeChanged="VlcVideoView_OnSizeChanged" />

        <Button
            x:Name="InvertButton"
            HorizontalAlignment="Right"
            VerticalAlignment="Top"
            Margin="12"
            Padding="12,6"
            Background="#CC202020"
            Foreground="White"
            Content="反色"
            Click="InvertButton_OnClick" />
'@
    $xamlText = $xamlText.Replace($anchor, $button.TrimEnd())
    Set-Content -Path $xaml -Value $xamlText -Encoding UTF8
}

$codeText = Get-Content -Raw -Encoding UTF8 $code
$resizeAnchor = '        ViewModel.UpdatePlayerViewSize(e.NewSize);'
if ($codeText.Contains($resizeAnchor) -and $codeText -notmatch '_invertOverlay\.Size = new Vector2\(\(float\)e\.NewSize\.Width') {
    $resizeInsert = $resizeAnchor + [Environment]::NewLine + '        if (_invertOverlay is not null) _invertOverlay.Size = new Vector2((float)e.NewSize.Width, (float)e.NewSize.Height);'
    $codeText = $codeText.Replace($resizeAnchor, $resizeInsert)
}
if ($codeText -notmatch 'InvertButton_OnClick') {
    $usingAnchor = 'using CommunityToolkit.Mvvm.DependencyInjection;'
    if (!$codeText.Contains($usingAnchor)) { throw 'Could not find C# using anchor.' }
    $usingInsert = $usingAnchor + [Environment]::NewLine + 'using System.Numerics;' + [Environment]::NewLine + 'using Microsoft.Graphics.Canvas.Effects;' + [Environment]::NewLine + 'using Windows.UI.Composition;' + [Environment]::NewLine + 'using Windows.UI.Xaml.Hosting;'
    $codeText = $codeText.Replace($usingAnchor, $usingInsert)

    $method = @'

    private SpriteVisual? _invertOverlay;
    private bool _isInverted;

    private void InvertButton_OnClick(object sender, RoutedEventArgs e)
    {
        _isInverted = !_isInverted;
        InvertButton.Content = _isInverted ? "关闭反色" : "反色";

        if (!_isInverted)
        {
            ElementCompositionPreview.SetElementChildVisual(VlcVideoView, null);
            _invertOverlay = null;
            return;
        }

        var compositor = ElementCompositionPreview.GetElementVisual(VlcVideoView).Compositor;
        var effect = new ColorMatrixEffect
        {
            Name = "SmartInvertMatrix",
            Source = new CompositionEffectSourceParameter("source"),
            ColorMatrix = new Matrix5x4
            {
                M11 = -1, M22 = -1, M33 = -1, M44 = 1,
                M51 = 1, M52 = 1, M53 = 1
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
    $lastBrace = $codeText.LastIndexOf('}')
    if ($lastBrace -lt 0) { throw 'Could not find PlayerElement class closing brace.' }
    $codeText = $codeText.Insert($lastBrace, $method)
    Set-Content -Path $code -Value $codeText -Encoding UTF8
}

Write-Host 'Mosuan first-pass color inversion patch applied.'
