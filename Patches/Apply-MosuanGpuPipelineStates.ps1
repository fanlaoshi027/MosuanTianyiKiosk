$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.VideoView\VideoView.cs'
if (!(Test-Path $path)) { throw "VideoView source not found: $path" }
$code = Get-Content -Raw -Encoding UTF8 $path
$nl = [Environment]::NewLine

$stateAnchor = '    private ID3D11PixelShader? _mosuanInvertPixelShader;'
$stateFields = @'
    private ID3D11SamplerState? _mosuanVideoSampler;
    private ID3D11RasterizerState? _mosuanRasterizerState;
    private ID3D11DepthStencilState? _mosuanDepthStencilState;
'@
if (!$code.Contains('private ID3D11SamplerState? _mosuanVideoSampler;')) {
    if (!$code.Contains($stateAnchor)) { throw 'Shader resource field anchor missing for GPU pipeline states.' }
    $code = $code.Replace($stateAnchor, $stateAnchor + $nl + $stateFields.TrimEnd())
}

$methodAnchor = '            _mosuanInvertPixelShader = _d3d11Device.CreatePixelShader(pixelBytecode);'
$methodInsert = @'
            _mosuanInvertPixelShader = _d3d11Device.CreatePixelShader(pixelBytecode);
            _mosuanVideoSampler = _d3d11Device.CreateSamplerState(SamplerDescription.LinearClamp);
            _mosuanRasterizerState = _d3d11Device.CreateRasterizerState(RasterizerDescription.CullNone);
            _mosuanDepthStencilState = _d3d11Device.CreateDepthStencilState(DepthStencilDescription.None);
'@
if ($code.Contains($methodAnchor) -and !$code.Contains('CreateSamplerState(SamplerDescription.LinearClamp)')) {
    $code = $code.Replace($methodAnchor, $methodInsert.TrimEnd())
}

$disposeAnchor = '        _swapChain?.Dispose();'
$disposeInsert = @'
        _mosuanVideoSampler?.Dispose();
        _mosuanVideoSampler = null;
        _mosuanRasterizerState?.Dispose();
        _mosuanRasterizerState = null;
        _mosuanDepthStencilState?.Dispose();
        _mosuanDepthStencilState = null;
'@
if ($code.Contains($disposeAnchor) -and !$code.Contains('_mosuanVideoSampler?.Dispose();')) {
    $code = $code.Replace($disposeAnchor, $disposeInsert + $nl + $disposeAnchor)
}

Set-Content -Path $path -Value $code -Encoding UTF8
Write-Host 'Mosuan GPU sampler, rasterizer and depth-stencil states initialized and disposed with the swapchain.'
