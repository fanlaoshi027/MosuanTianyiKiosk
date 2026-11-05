$ErrorActionPreference = 'Stop'
$videoViewRoot = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.VideoView'
$videoViewPath = Join-Path $videoViewRoot 'VideoView.cs'
$playerElementPath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Controls\PlayerElement.xaml.cs'
$playerPagePath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Pages\PlayerPage.xaml.cs'
foreach ($path in @($videoViewPath, $playerElementPath, $playerPagePath)) {
    if (!(Test-Path $path)) { throw "Shader runtime diagnostic target not found: $path" }
}
$nl = [Environment]::NewLine
$code = Get-Content -Raw -Encoding UTF8 $videoViewPath

if (!$code.Contains('private ID3D11VertexShader? _mosuanInvertVertexShader;')) {
    $anchor = '    private IDXGISwapChain1? _swapChain;'
    if (!$code.Contains($anchor)) { throw 'VideoView swapchain field anchor not found for shader initialization.' }
    $fields = @'
    private ID3D11VertexShader? _mosuanInvertVertexShader;
    private ID3D11PixelShader? _mosuanInvertPixelShader;
    private string _mosuanShaderStatus = "尚未初始化";
'@
    $code = $code.Replace($anchor, $anchor + $nl + $fields.TrimEnd())
}

if (!$code.Contains('InitializeMosuanInvertShaders();')) {
    $anchor = '        if (_d3d11Device is null || _d3d11Context is null)'
    if (!$code.Contains($anchor)) { throw 'D3D11 device validation anchor not found.' }
    # Initialize after device creation; failure is diagnostic-only and must not stop playback.
    $code = $code.Replace($anchor, '        InitializeMosuanInvertShaders();' + $nl + $nl + $anchor)
}

if (!$code.Contains('private void InitializeMosuanInvertShaders()')) {
    $method = @'
    private void InitializeMosuanInvertShaders()
    {
        _mosuanInvertVertexShader?.Dispose();
        _mosuanInvertPixelShader?.Dispose();
        _mosuanInvertVertexShader = null;
        _mosuanInvertPixelShader = null;

        if (_d3d11Device is null)
        {
            _mosuanShaderStatus = "D3D11 设备尚未创建";
            return;
        }

        try
        {
            var assembly = typeof(VideoView).Assembly;
            using var vertexStream = assembly.GetManifestResourceStream("Screenbox.VideoView.Shaders.FullscreenVS.cso")
                ?? throw new InvalidOperationException("找不到顶点 Shader 内嵌资源。");
            using var pixelStream = assembly.GetManifestResourceStream("Screenbox.VideoView.Shaders.VideoInvertPS.cso")
                ?? throw new InvalidOperationException("找不到像素 Shader 内嵌资源。");

            byte[] vertexBytecode = new byte[vertexStream.Length];
            byte[] pixelBytecode = new byte[pixelStream.Length];
            vertexStream.ReadExactly(vertexBytecode);
            pixelStream.ReadExactly(pixelBytecode);

            _mosuanInvertVertexShader = _d3d11Device.CreateVertexShader(vertexBytecode);
            _mosuanInvertPixelShader = _d3d11Device.CreatePixelShader(pixelBytecode);
            _mosuanShaderStatus = $"GPU Shader 已创建（VS {vertexBytecode.Length} B / PS {pixelBytecode.Length} B）";
        }
        catch (Exception ex)
        {
            _mosuanInvertVertexShader?.Dispose();
            _mosuanInvertPixelShader?.Dispose();
            _mosuanInvertVertexShader = null;
            _mosuanInvertPixelShader = null;
            _mosuanShaderStatus = $"Shader 初始化失败：{ex.GetType().Name}: {ex.Message}";
        }
    }

    public string GetShaderDiagnostics()
    {
        return _mosuanShaderStatus;
    }

'@
    $anchor = '    private void DestroySwapChain()'
    if (!$code.Contains($anchor)) { throw 'DestroySwapChain anchor not found for shader diagnostics.' }
    $code = $code.Replace($anchor, $method + $anchor)
}

$disposeAnchor = '        _swapChain?.Dispose();'
if ($code.Contains($disposeAnchor) -and !$code.Contains('_mosuanInvertVertexShader?.Dispose();' + $nl + '        _mosuanInvertPixelShader?.Dispose();')) {
    $code = $code.Replace($disposeAnchor,
        '        _mosuanInvertVertexShader?.Dispose();' + $nl +
        '        _mosuanInvertVertexShader = null;' + $nl +
        '        _mosuanInvertPixelShader?.Dispose();' + $nl +
        '        _mosuanInvertPixelShader = null;' + $nl +
        '        _mosuanShaderStatus = "SwapChain 已释放";' + $nl + $disposeAnchor)
}
Set-Content -Path $videoViewPath -Value $code -Encoding UTF8

$wrapper = Get-Content -Raw -Encoding UTF8 $playerElementPath
if (!$wrapper.Contains('GetShaderDiagnostics()')) {
    $anchor = '    public string GetBackBufferDiagnostics()'
    if (!$wrapper.Contains($anchor)) { throw 'PlayerElement back-buffer diagnostics wrapper not found.' }
    $method = @'
    public string GetShaderDiagnostics()
    {
        return VlcVideoView.GetShaderDiagnostics();
    }

'@
    $wrapper = $wrapper.Replace($anchor, $method + $anchor)
    Set-Content -Path $playerElementPath -Value $wrapper -Encoding UTF8
}

$page = Get-Content -Raw -Encoding UTF8 $playerPagePath
$old = '\n{VideoView.GetBackBufferDiagnostics()}",'
$new = '\n{VideoView.GetBackBufferDiagnostics()}\n{VideoView.GetShaderDiagnostics()}",'
if ($page.Contains($old)) {
    $page = $page.Replace($old, $new)
} elseif (!$page.Contains('{VideoView.GetShaderDiagnostics()}')) {
    throw 'GPU diagnostic dialog back-buffer content anchor not found.'
}
Set-Content -Path $playerPagePath -Value $page -Encoding UTF8
Write-Host 'Mosuan GPU shader runtime initialization added: embedded bytecode is loaded and D3D11 shader objects are created; playback remains fail-open.'
