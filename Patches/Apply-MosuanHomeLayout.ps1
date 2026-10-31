$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$homePath = Join-Path $root 'Pages\HomePage.xaml'
$mainPath = Join-Path $root 'Pages\MainPage.xaml'

foreach ($path in @($homePath, $mainPath)) {
    if (!(Test-Path $path)) { throw "Required shell layout file not found: $path" }
}

# Home page: establish a clear Chinese hierarchy without changing bindings,
# item templates, commands, or navigation behavior.
$homeXaml = Get-Content -Raw -Encoding UTF8 $homePath
$homeXaml = $homeXaml.Replace(
    'Text="{x:Bind strings:Resources.Home}"',
    'Text="首页"'
)
$homeXaml = $homeXaml.Replace(
    'Text="{x:Bind strings:Resources.Recent}"',
    'Text="最近播放"'
)
$homeXaml = $homeXaml.Replace(
    'Text="{x:Bind strings:Resources.OpenFiles}"',
    'Text="打开文件"'
)

# Keep page headings legible and consistent with the charcoal player shell.
# Add typography only when the corresponding attribute is not already present.
if ($homeXaml -notmatch 'FontSize="30"') {
    $homeXaml = $homeXaml.Replace(
        'Style="{StaticResource TitleMediumTextBlockStyle}"',
        'Style="{StaticResource TitleMediumTextBlockStyle}"' + [Environment]::NewLine + '                FontSize="30"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#F3F4F6"'
    )
}
if ($homeXaml -notmatch 'FontSize="18"') {
    $homeXaml = $homeXaml.Replace(
        'Style="{StaticResource SubtitleTextBlockStyle}"',
        'Style="{StaticResource SubtitleTextBlockStyle}"' + [Environment]::NewLine + '                FontSize="18"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#E5E7EB"'
    )
}
$homeXaml = $homeXaml.Replace(
    'Padding="{StaticResource ContentPagePadding}">',
    'Padding="32,20,32,16">'
)
Set-Content -Path $homePath -Value $homeXaml -Encoding UTF8

# Navigation shell surface is styled by Apply-MosuanShellUI.ps1.
# NavigationViewEx does not expose PaneBackground, so do not add unsupported XAML members.


Write-Host 'Mosuan home layout v1 applied: Chinese home hierarchy and restrained navigation surface.'
