$ErrorActionPreference = 'Stop'

$videoViewRoot = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.VideoView'
$probePath = Join-Path $videoViewRoot 'SwapChainPresentProbe.cs'
$playerCodePath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Pages\PlayerPage.xaml.cs'

foreach ($path in @($probePath, $playerCodePath)) {
    if (!(Test-Path $path)) { throw "Required GPU probe diagnostic target not found: $path" }
}

$code = Get-Content -Raw -Encoding UTF8 $probePath
$nl = [Environment]::NewLine

# Track whether the instance hook is currently installed, separately from frame counts.
if (!$code.Contains('private static int s_activeHookCount;')) {
    $anchor = '    private static long s_present1Count;'
    if (!$code.Contains($anchor)) { throw 'GPU probe counter anchor not found.' }
    $code = $code.Replace($anchor, $anchor + $nl +
        '    private static int s_activeHookCount;' + $nl +
        '    private static long s_lastSwapChain;' + $nl +
        '    private static string? s_lastInstallError;')
}
if (!$code.Contains('public static int ActiveHookCount')) {
    $anchor = '    public static long Present1Count => Interlocked.Read(ref s_present1Count);'
    if (!$code.Contains($anchor)) { throw 'GPU probe public counter anchor not found.' }
    $code = $code.Replace($anchor, $anchor + $nl +
        '    public static int ActiveHookCount => Volatile.Read(ref s_activeHookCount);' + $nl +
        '    public static string LastInstallError => Volatile.Read(ref s_lastInstallError) ?? string.Empty;' + $nl +
        '    public static string LastSwapChainAddress => $"0x{Interlocked.Read(ref s_lastSwapChain):X}";')
}

$successAnchor = '            return new SwapChainPresentProbe(swapChain, originalVtable, clone);'
if ($code.Contains($successAnchor)) {
    $successReplacement = @'
            var probe = new SwapChainPresentProbe(swapChain, originalVtable, clone);
            Interlocked.Exchange(ref s_lastSwapChain, swapChain.ToInt64());
            Interlocked.Exchange(ref s_lastInstallError, null);
            Interlocked.Increment(ref s_activeHookCount);
            return probe;
'@
    $code = $code.Replace($successAnchor, $successReplacement.TrimEnd())
}
$catchAnchor = '            Trace.WriteLine($"Mosuan DXGI Present probe not installed; continuing without it: {ex}");'
if ($code.Contains($catchAnchor) -and !$code.Contains('Interlocked.Exchange(ref s_lastInstallError, ex.ToString());')) {
    $code = $code.Replace($catchAnchor,
        '            Interlocked.Exchange(ref s_lastInstallError, ex.ToString());' + $nl + $catchAnchor)
}
$disposeAnchor = '        _disposed = true;'
if ($code.Contains($disposeAnchor) -and !$code.Contains('Interlocked.Decrement(ref s_activeHookCount);')) {
    $code = $code.Replace($disposeAnchor,
        $disposeAnchor + $nl + '        Interlocked.Decrement(ref s_activeHookCount);')
}
Set-Content -Path $probePath -Value $code -Encoding UTF8

# Expand the existing diagnostic dialog. It reports hook state, target pointer, frame
# callbacks, and the last installation exception instead of making zero counts ambiguous.
$playerCode = Get-Content -Raw -Encoding UTF8 $playerCodePath
$old = '            Content = $"Present：{Screenbox.Controls.SwapChainPresentProbe.PresentCount}\nPresent1：{Screenbox.Controls.SwapChainPresentProbe.Present1Count}",'
$new = @'
            Content = $"拦截状态：{(Screenbox.Controls.SwapChainPresentProbe.ActiveHookCount > 0 ? "已安装" : "未安装")}\n活动钩子：{Screenbox.Controls.SwapChainPresentProbe.ActiveHookCount}\nSwapChain：{Screenbox.Controls.SwapChainPresentProbe.LastSwapChainAddress}\nPresent：{Screenbox.Controls.SwapChainPresentProbe.PresentCount}\nPresent1：{Screenbox.Controls.SwapChainPresentProbe.Present1Count}\n安装错误：{(string.IsNullOrWhiteSpace(Screenbox.Controls.SwapChainPresentProbe.LastInstallError) ? "无" : Screenbox.Controls.SwapChainPresentProbe.LastInstallError)}",
'@
if ($playerCode.Contains($old)) {
    $playerCode = $playerCode.Replace($old, $new.TrimEnd())
} elseif (!$playerCode.Contains('拦截状态：')) {
    throw 'GPU diagnostic dialog content anchor not found.'
}
Set-Content -Path $playerCodePath -Value $playerCode -Encoding UTF8

Write-Host 'GPU probe diagnostics upgraded: install state, active hook count, swapchain address, frame counts, and install error.'
