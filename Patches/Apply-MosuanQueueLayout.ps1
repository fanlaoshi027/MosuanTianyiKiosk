$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$path = Join-Path $root 'Pages\PlayQueuePage.xaml'
if (!(Test-Path $path)) { throw "Required play queue page not found: $path" }

$xaml = Get-Content -Raw -Encoding UTF8 $path

# Match the Mosuan charcoal shell while preserving drag-and-drop behavior.
$xaml = $xaml.Replace(
    '        Background="Transparent"',
    '        Background="#101318"'
)

# Localize only visible labels; keep all commands, bindings and tooltips intact.
$xaml = $xaml.Replace(
    'Text="{x:Bind strings:Resources.PlayQueue}"',
    'Text="当前播放队列"'
)
$xaml = $xaml.Replace(
    'Text="{x:Bind strings:Resources.AddFiles}"',
    'Text="添加文件"'
)

# Refine the header and content insets.
$xaml = $xaml.Replace(
    'Padding="{StaticResource ContentPagePadding}"' + [Environment]::NewLine + '            ColumnSpacing="8"',
    'Padding="32,20,32,16"' + [Environment]::NewLine + '            ColumnSpacing="12"'
)
$xaml = $xaml.Replace(
    'Padding="{StaticResource ContentPagePadding}" />',
    'Padding="32,8,32,20" />'
)

Set-Content -Path $path -Value $xaml -Encoding UTF8
Write-Host 'Mosuan play queue layout applied: charcoal canvas, localized labels and refined spacing.'
