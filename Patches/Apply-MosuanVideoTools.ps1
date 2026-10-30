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
            Panel.ZIndex="40"
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
                    <MenuFlyoutItem Text="重置裁切" Click="MosuanResetCrop_OnClick" />
                </MenuFlyout>
            </Button.Flyout>
        </Button>
'@
    $anchor = '(?s)(</Grid>\s*</Page>\s*)$'
    if ($xaml -notmatch $anchor) { throw 'PlayerPage root Grid closing anchor not found' }
    $newline = [Environment]::NewLine
    $replacement = $button + $newline + '</Grid>' + $newline + '</Page>' + $newline
    $xaml = [regex]::Replace($xaml, $anchor, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)
    Set-Content -Path $xamlPath -Value $xaml -Encoding UTF8
}

# Route aspect-ratio selections through Screenbox's existing crop message pipeline.
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
if (!$code.Contains('MosuanAspectRatio_OnClick')) {
    $handlers = @'

    // Mosuan UI: reuse the existing PlayerElementViewModel crop pipeline.
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
    if ($lastBrace -lt 0) { throw 'PlayerPage class closing brace not found' }
    $code = $code.Insert($lastBrace, $handlers + [Environment]::NewLine)
    Set-Content -Path $codePath -Value $code -Encoding UTF8
}

Write-Host 'Mosuan video tools v1 applied: aspect-ratio presets and crop reset use the existing player pipeline.'
