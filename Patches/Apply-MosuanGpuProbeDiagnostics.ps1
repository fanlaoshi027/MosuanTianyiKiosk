$ErrorActionPreference = 'Stop'

$videoViewRoot = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.VideoView'
$probePath = Join-Path $videoViewRoot 'SwapChainPresentProbe.cs'
$playerCodePath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Pages\PlayerPage.xaml.cs'
$videoViewPath = Join-Path $videoViewRoot 'VideoView.cs'
$playerElementCodePath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Controls\PlayerElement.xaml.cs'

foreach ($path in @($probePath, $playerCodePath, $videoViewPath, $playerElementCodePath)) {
    if (!(Test-Path $path)) { throw "Required GPU probe diagnostic target not found: $path" }
}

$code = Get-Content -Raw -Encoding UTF8 $probePath
$nl = [Environment]::NewLine

# Track whether the instance hook is currently installed, separately from frame counts.
# Record non-exceptional install failures too; zero frame counts alone are ambiguous.
$installStart = '        if (swapChain == IntPtr.Zero)'
$installOld = $installStart + [Environment]::NewLine + '            return null;' + [Environment]::NewLine + '        }'
$installNew = @'
        Interlocked.Exchange(ref s_lastSwapChain, swapChain.ToInt64());
        Interlocked.Exchange(ref s_lastInstallError, null);
        if (swapChain == IntPtr.Zero)
        {
            Interlocked.Exchange(ref s_lastInstallError, "SwapChain 指针为空。");
            return null;
        }
'@
if ($code.Contains($installOld) -and !$code.Contains('SwapChain 指针为空。')) { $code = $code.Replace($installOld, $installNew.TrimEnd()) }
$nullVtable = @'
            if (originalVtable == IntPtr.Zero)
                return null;
'@
$nullVtableNew = @'
            if (originalVtable == IntPtr.Zero)
            {
                Interlocked.Exchange(ref s_lastInstallError, "SwapChain vtable 指针为空。");
                return null;
            }
'@
if ($code.Contains($nullVtable)) { $code = $code.Replace($nullVtable, $nullVtableNew.TrimEnd()) }
$nullMethods = @'
            if (originalPresent == IntPtr.Zero || originalPresent1 == IntPtr.Zero)
                return null;
'@
$nullMethodsNew = @'
            if (originalPresent == IntPtr.Zero || originalPresent1 == IntPtr.Zero)
            {
                Interlocked.Exchange(ref s_lastInstallError, "Present 或 Present1 原始函数指针为空。");
                return null;
            }
'@
if ($code.Contains($nullMethods)) { $code = $code.Replace($nullMethods, $nullMethodsNew.TrimEnd()) }
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
        '    public static string HookStatus => ActiveHookCount > 0 ? "已安装" : "未安装";' + $nl +
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
if ($code.Contains($disposeAnchor)) {
    # The hook remains active if VirtualProtect fails. Decrement only when we
    # know this instance no longer owns the swap-chain vtable.
    $code = $code.Replace($disposeAnchor, $disposeAnchor + $nl +
        '        if (Marshal.ReadIntPtr(_swapChain) != _hookedVtable)' + $nl +
        '        {' + $nl +
        '            Interlocked.Decrement(ref s_activeHookCount);' + $nl +
        '            return;' + $nl +
        '        }')
    $restoreAnchor = '                Marshal.WriteIntPtr(_swapChain, _originalVtable);'
    if ($code.Contains($restoreAnchor) -and !$code.Contains('                Interlocked.Decrement(ref s_activeHookCount);')) {
        $code = $code.Replace($restoreAnchor, $restoreAnchor + $nl +
            '                Interlocked.Decrement(ref s_activeHookCount);')
    }
}
Set-Content -Path $probePath -Value $code -Encoding UTF8

# Read-only back-buffer inspection: GetBuffer + ID3D11Texture2D.Description only.
# No immediate-context calls are made here, so this diagnostic cannot disturb VLC's pipeline.
$videoView = Get-Content -Raw -Encoding UTF8 $videoViewPath
if (!$videoView.Contains('GetBackBufferDiagnostics()')) {
    $methodAnchor = '    private void DestroySwapChain()'
    if (!$videoView.Contains($methodAnchor)) { throw 'VideoView teardown method anchor not found.' }
    $method = @'
    public string GetBackBufferDiagnostics()
    {
        if (_swapChain is null)
        {
            return "后台缓冲区：SwapChain 尚未创建。";
        }

        try
        {
            using var backBuffer = _swapChain.GetBuffer<ID3D11Texture2D>(0);
            var description = backBuffer.Description;
            return $"后台缓冲区：{description.Width} × {description.Height}\n格式：{description.Format}\n采样数：{description.SampleDescription.Count}\nMip：{description.MipLevels}\nBindFlags：{description.BindFlags}";
        }
        catch (Exception ex)
        {
            return $"后台缓冲区读取失败：{ex.GetType().Name}: {ex.Message}";
        }
    }

'@
    $videoView = $videoView.Replace($methodAnchor, $method + $methodAnchor)
    Set-Content -Path $videoViewPath -Value $videoView -Encoding UTF8
}

# PlayerPage's named VideoView is a PlayerElement wrapper, not the low-level
# VideoView SwapChainPanel. Expose the low-level diagnostic through that wrapper.
$playerElementCode = Get-Content -Raw -Encoding UTF8 $playerElementCodePath
if (!$playerElementCode.Contains('GetBackBufferDiagnostics()')) {
    $playerElementAnchor = '    private void VlcVideoView_OnInitialized(object sender, VideoViewInitializedEventArgs e)'
    if (!$playerElementCode.Contains($playerElementAnchor)) { throw 'PlayerElement initialization handler anchor not found.' }
    $playerElementMethod = @'
    public string GetBackBufferDiagnostics()
    {
        return VlcVideoView.GetBackBufferDiagnostics();
    }

'@
    $playerElementCode = $playerElementCode.Replace($playerElementAnchor, $playerElementMethod + $playerElementAnchor)
    Set-Content -Path $playerElementCodePath -Value $playerElementCode -Encoding UTF8
}

# Expand the existing diagnostic dialog. It reports hook state, target pointer, frame
# callbacks, and the last installation exception instead of making zero counts ambiguous.
$playerCode = Get-Content -Raw -Encoding UTF8 $playerCodePath
$old = '            Content = $"Present：{Screenbox.Controls.SwapChainPresentProbe.PresentCount}\nPresent1：{Screenbox.Controls.SwapChainPresentProbe.Present1Count}",'
$new = @'
            Content = $"拦截状态：{Screenbox.Controls.SwapChainPresentProbe.HookStatus}\n活动钩子：{Screenbox.Controls.SwapChainPresentProbe.ActiveHookCount}\nSwapChain：{Screenbox.Controls.SwapChainPresentProbe.LastSwapChainAddress}\nPresent：{Screenbox.Controls.SwapChainPresentProbe.PresentCount}\nPresent1：{Screenbox.Controls.SwapChainPresentProbe.Present1Count}\n安装错误：{(string.IsNullOrWhiteSpace(Screenbox.Controls.SwapChainPresentProbe.LastInstallError) ? "无" : Screenbox.Controls.SwapChainPresentProbe.LastInstallError)}\n{VideoView.GetBackBufferDiagnostics()}",
'@
if ($playerCode.Contains($old)) {
    $playerCode = $playerCode.Replace($old, $new.TrimEnd())
} elseif (!$playerCode.Contains('拦截状态：')) {
    throw 'GPU diagnostic dialog content anchor not found.'
}
Set-Content -Path $playerCodePath -Value $playerCode -Encoding UTF8

Write-Host 'GPU probe diagnostics upgraded: install state, active hook count, swapchain address, frame counts, and install error.'
