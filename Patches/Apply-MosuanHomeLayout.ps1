$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$homePath = Join-Path $root 'Pages\HomePage.xaml'
$mainPath = Join-Path $root 'Pages\MainPage.xaml'

foreach ($path in @($homePath, $mainPath)) {
    if (!(Test-Path $path)) { throw "Required shell layout file not found: $path" }
}

# Home page: establish a clear Chinese hierarchy without changing bindings,
# item templates, commands, or navigation behavior.
$home = Get-Content -Raw -Encoding UTF8 $homePath
$home = $home.Replace(
    'Text="{x:Bind strings:Resources.Home}"',
    'Text="首页"'
)
$home = $home.Replace(
    'Text="{x:Bind strings:Resources.Recent}"',
    'Text="最近播放"'
)
$home = $home.Replace(
    'Text="{x:Bind strings:Resources.OpenFiles}"',
    'Text="打开文件"'
)

# Keep page headings legible and consistent with the charcoal player shell.
if (!$home.Contains('FontSize="30"')) {
    $home = $home.Replace(
        'Style="{StaticResource TitleMediumTextBlockStyle}"' + [Environment]::NewLine + '                Text="首页"',
        'Style="{StaticResource TitleMediumTextBlockStyle}"' + [Environment]::NewLine + '                FontSize="30"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#F3F4F6"' + [Environment]::NewLine + '                Text="首页"'
    )
}
if (!$home.Contains('Foreground="#E5E7EB"')) {
    $home = $home.Replace(
        'Style="{StaticResource SubtitleTextBlockStyle}"' + [Environment]::NewLine + '                Text="最近播放"',
        'Style="{StaticResource SubtitleTextBlockStyle}"' + [Environment]::NewLine + '                FontSize="18"' + [Environment]::NewLine + '                FontWeight="SemiBold"' + [Environment]::NewLine + '                Foreground="#E5E7EB"' + [Environment]::NewLine + '                Text="最近播放"'
    )
}
Set-Content -Path $homePath -Value $home -Encoding UTF8

# Navigation shell: use a restrained surface and clear divider between pane and content.
$main = Get-Content -Raw -Encoding UTF8 $mainPath
if (!$main.Contains('PaneBackground="#151B23"')) {
    $anchor = '            x:Name="NavView"'
    if (!$main.Contains($anchor)) { throw 'NavigationView anchor not found' }
    $main = $main.Replace(
        $anchor,
        $anchor + [Environment]::NewLine + '            PaneBackground="#151B23"'
    )
}
Set-Content -Path $mainPath -Value $main -Encoding UTF8

Write-Host 'Mosuan home layout v1 applied: Chinese home hierarchy and restrained navigation surface.'
