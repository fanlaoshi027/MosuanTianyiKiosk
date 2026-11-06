
$stateAnchor = "    private ID3D11PixelShader? _mosuanInvertPixelShader;"
$stateFields = @'
    private ID3D11SamplerState? _mosuanVideoSampler;
    private ID3D11RasterizerState? _mosuanRasterizerState;
    private ID3D11DepthStencilState? _mosuanDepthStencilState;
'@
$codeInsert = @'
if (!$code.Contains('private ID3D11SamplerState? _mosuanVideoSampler;')) {
    if (!$code.Contains($stateAnchor)) { throw 'Shader resource field anchor missing for GPU pipeline states.' }
    $code = $code.Replace($stateAnchor, $stateAnchor + $nl + $stateFields.TrimEnd())
}

'@
$methodAnchor = '            _mosuanInvertPixelShader = _d3d11Device.CreatePixelShader(pixelBytecode);'
$methodInsert = @'
            _mosuanInvertPixelShader = _d3d11Device.CreatePixelShader(pixelBytecode);
            _mosuanVideoSampler = _d3d11Device.CreateSamplerState(SamplerDescription.LinearClamp);
            _mosuanRasterizerState = _d3d11Device.CreateRasterizerState(RasterizerDescription.CullNone);
            _mosuanDepthStencilState = _d3d11Device.CreateDepthStencilState(DepthStencilDescription.None);
'@
$replaceMethod = @'
if ($code.Contains($methodAnchor) -and !$code.Contains('CreateSamplerState(SamplerDescription.LinearClamp)')) {
    $code = $code.Replace($methodAnchor, $methodInsert.TrimEnd())
}

'@
$disposeInsert = @'
        _mosuanVideoSampler?.Dispose();
        _mosuanVideoSampler = null;
        _mosuanRasterizerState?.Dispose();
        _mosuanRasterizerState = null;
        _mosuanDepthStencilState?.Dispose();
        _mosuanDepthStencilState = null;
'@
$disposeAnchor = '        _swapChain?.Dispose();'
$disposeCode = @'
if ($code.Contains($disposeAnchor) -and !$code.Contains('_mosuanVideoSampler?.Dispose();')) {
    $code = $code.Replace($disposeAnchor, $disposeInsert + $nl + $disposeAnchor)
}

'@
$tail = @'
$code = Get-Content -Raw -Encoding UTF8 $videoViewPath
'@ + $codeInsert + $replaceMethod + $disposeCode + @'
Set-Content -Path $videoViewPath -Value $code -Encoding UTF8
'@
Set-Content -Path (Join-Path $PSScriptRoot 'Apply-MosuanGpuPipelineStates.ps1') -Value $tail -Encoding UTF8
Write-Host 'Created follow-up patch for GPU sampler/rasterizer/depth-stencil states.'
