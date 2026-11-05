$ErrorActionPreference = 'Stop'
$projectRoot = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.VideoView'
$source = Join-Path $PSScriptRoot 'Shaders\VideoInvert.hlsl'
$shaderDir = Join-Path $projectRoot 'Shaders'
$projectFile = Join-Path $projectRoot 'Screenbox.VideoView.csproj'

if (!(Test-Path $source)) { throw "Shader source not found: $source" }
if (!(Test-Path $projectFile)) { throw "VideoView project not found: $projectFile" }

$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$fxc = Get-ChildItem -Path $sdkRoot | Where-Object { $_.PSIsContainer } |
    Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\fxc.exe' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
if (!$fxc) { throw 'Windows SDK fxc.exe was not found.' }

New-Item -ItemType Directory -Force -Path $shaderDir | Out-Null
$vertex = Join-Path $shaderDir 'FullscreenVS.cso'
$pixel = Join-Path $shaderDir 'VideoInvertPS.cso'

& $fxc /nologo /Ges /WX /T vs_4_0 /E VSMain /Fo $vertex $source
if ($LASTEXITCODE -ne 0) { throw "Vertex shader compilation failed: $LASTEXITCODE" }
& $fxc /nologo /Ges /WX /T ps_4_0 /E PSMain /Fo $pixel $source
if ($LASTEXITCODE -ne 0) { throw "Pixel shader compilation failed: $LASTEXITCODE" }

foreach ($file in @($vertex, $pixel)) {
    if (!(Test-Path $file) -or (Get-Item $file).Length -lt 128) {
        throw "Shader bytecode missing or invalid: $file"
    }
}

$project = Get-Content -Raw -Encoding UTF8 $projectFile
if (!$project.Contains('Screenbox.VideoView.Shaders.FullscreenVS.cso')) {
    $resourceGroup = @'
  <ItemGroup>
    <EmbeddedResource Include="Shaders\FullscreenVS.cso" LogicalName="Screenbox.VideoView.Shaders.FullscreenVS.cso" />
    <EmbeddedResource Include="Shaders\VideoInvertPS.cso" LogicalName="Screenbox.VideoView.Shaders.VideoInvertPS.cso" />
  </ItemGroup>
'@
    $project = $project.Replace('</Project>', $resourceGroup + [Environment]::NewLine + '</Project>')
    Set-Content -Path $projectFile -Value $project -Encoding UTF8
}

Write-Host "Compiled D3D11 shader bytecode:"
Get-Item $vertex, $pixel | ForEach-Object { Write-Host ("{0}: {1} bytes" -f $_.Name, $_.Length) }
