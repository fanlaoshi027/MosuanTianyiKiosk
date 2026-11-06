$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.VideoView\VideoView.cs'
if (!(Test-Path $path)) { throw "VideoView source not found: $path" }
$code = Get-Content -Raw -Encoding UTF8 $path
$nl = [Environment]::NewLine

if (!$code.Contains('private ID3D11Texture2D? _mosuanIntermediateTexture;')) {
    $anchor = '    private ID3D11PixelShader? _mosuanInvertPixelShader;'
    if (!$code.Contains($anchor)) { throw 'Shader field anchor not found.' }
    $fields = @'
    private ID3D11Texture2D? _mosuanIntermediateTexture;
    private ID3D11ShaderResourceView? _mosuanIntermediateShaderView;
    private ID3D11RenderTargetView? _mosuanIntermediateRenderTarget;
    private string _mosuanSurfaceStatus = "尚未创建";
'@
    $code = $code.Replace($anchor, $anchor + $nl + $fields.TrimEnd())
}

if (!$code.Contains('InitializeMosuanIntermediateResources();')) {
    $anchor = '            _swapChain = dxgiFactory.CreateSwapChainForComposition(_d3d11Device, scd);'
    if (!$code.Contains($anchor)) { throw 'SwapChain creation anchor not found.' }
    $code = $code.Replace($anchor, $anchor + $nl + '            InitializeMosuanIntermediateResources();')
}

if (!$code.Contains('private void InitializeMosuanIntermediateResources()')) {
    $method = @'
    private void InitializeMosuanIntermediateResources()
    {
        _mosuanIntermediateRenderTarget?.Dispose();
        _mosuanIntermediateRenderTarget = null;
        _mosuanIntermediateShaderView?.Dispose();
        _mosuanIntermediateShaderView = null;
        _mosuanIntermediateTexture?.Dispose();
        _mosuanIntermediateTexture = null;

        if (_d3d11Device is null || _swapChain is null)
        {
            _mosuanSurfaceStatus = "D3D11 设备或 SwapChain 不可用";
            return;
        }

        try
        {
            using var backBuffer = _swapChain.GetBuffer<ID3D11Texture2D>(0);
            var source = backBuffer.Description;
            var description = new Texture2DDescription
            {
                Width = source.Width,
                Height = source.Height,
                MipLevels = 1,
                ArraySize = 1,
                Format = source.Format,
                SampleDescription = new SampleDescription(1, 0),
                Usage = ResourceUsage.Default,
                BindFlags = BindFlags.ShaderResource | BindFlags.RenderTarget,
                CPUAccessFlags = CpuAccessFlags.None,
                MiscFlags = ResourceOptionFlags.None
            };

            _mosuanIntermediateTexture = _d3d11Device.CreateTexture2D(description);
            _mosuanIntermediateShaderView = _d3d11Device.CreateShaderResourceView(_mosuanIntermediateTexture);
            _mosuanIntermediateRenderTarget = _d3d11Device.CreateRenderTargetView(_mosuanIntermediateTexture);
            _mosuanSurfaceStatus = $"中间纹理已创建：{source.Width} × {source.Height}，{source.Format}（SRV + RTV）";
        }
        catch (Exception ex)
        {
            _mosuanIntermediateRenderTarget?.Dispose();
            _mosuanIntermediateRenderTarget = null;
            _mosuanIntermediateShaderView?.Dispose();
            _mosuanIntermediateShaderView = null;
            _mosuanIntermediateTexture?.Dispose();
            _mosuanIntermediateTexture = null;
            _mosuanSurfaceStatus = $"中间纹理创建失败：{ex.GetType().Name}: {ex.Message}";
        }
    }

    public string GetIntermediateSurfaceDiagnostics()
    {
        return _mosuanSurfaceStatus;
    }

'@
    $anchor = '    private void DestroySwapChain()'
    if (!$code.Contains($anchor)) { throw 'DestroySwapChain anchor not found.' }
    $code = $code.Replace($anchor, $method + $anchor)
}

$disposeAnchor = '        _swapChain?.Dispose();'
if ($code.Contains($disposeAnchor) -and !$code.Contains('_mosuanIntermediateRenderTarget?.Dispose();' + $nl + '        _mosuanIntermediateRenderTarget = null;')) {
    $cleanup = @'
        _mosuanIntermediateRenderTarget?.Dispose();
        _mosuanIntermediateRenderTarget = null;
        _mosuanIntermediateShaderView?.Dispose();
        _mosuanIntermediateShaderView = null;
        _mosuanIntermediateTexture?.Dispose();
        _mosuanIntermediateTexture = null;
        _mosuanSurfaceStatus = "SwapChain 已释放";
'@
    $code = $code.Replace($disposeAnchor, $cleanup + $disposeAnchor)
}
Set-Content -Path $path -Value $code -Encoding UTF8
Write-Host 'Mosuan intermediate GPU surface initialized with a separate shader-readable texture and render-target view. No VLC frame is modified in this stage.'

$wrapperPath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Controls\PlayerElement.xaml.cs'
$pagePath = Join-Path $PSScriptRoot '..\Screenbox\Screenbox\Pages\PlayerPage.xaml.cs'
$wrapper = Get-Content -Raw -Encoding UTF8 $wrapperPath
if (!$wrapper.Contains('GetIntermediateSurfaceDiagnostics()')) {
    $anchor = '    public string GetShaderDiagnostics()'
    if (!$wrapper.Contains($anchor)) { throw 'PlayerElement shader diagnostic anchor not found.' }
    $method = @'
    public string GetIntermediateSurfaceDiagnostics()
    {
        return VlcVideoView.GetIntermediateSurfaceDiagnostics();
    }

'@
    $wrapper = $wrapper.Replace($anchor, $method + $anchor)
    Set-Content -Path $wrapperPath -Value $wrapper -Encoding UTF8
}
$page = Get-Content -Raw -Encoding UTF8 $pagePath
$anchor = '{VideoView.GetShaderDiagnostics()}'
if ($page.Contains($anchor) -and !$page.Contains('{VideoView.GetIntermediateSurfaceDiagnostics()}')) {
    $page = $page.Replace($anchor, $anchor + '\n{VideoView.GetIntermediateSurfaceDiagnostics()}')
    Set-Content -Path $pagePath -Value $page -Encoding UTF8
}
