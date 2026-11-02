$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$playerPath = Join-Path $root 'Pages\PlayerPage.xaml'
if (!(Test-Path $playerPath)) { throw "Player page not found: $playerPath" }

$xaml = Get-Content -Raw -Encoding UTF8 $playerPath

# Re-skin the existing title/control surfaces without inserting new XAML nodes.
# This keeps PlayerPage's visual-state tree and code-behind contract untouched.
$replacements = @(
    @{
        Old = '<Border' + [Environment]::NewLine + '            x:Name="PlayerControlsBackground"' + [Environment]::NewLine + '            Grid.Row="2"' + [Environment]::NewLine + '            Grid.Column="0"' + [Environment]::NewLine + '            Background="{ThemeResource PlayerControlsBackgroundBrush}"'
        New = '<Border' + [Environment]::NewLine + '            x:Name="PlayerControlsBackground"' + [Environment]::NewLine + '            Grid.Row="2"' + [Environment]::NewLine + '            Grid.Column="0"' + [Environment]::NewLine + '            Background="#111B29"'
    },
    @{
        Old = '<sbuc:TitleBar' + [Environment]::NewLine + '            x:Name="PlayerTitleBar"' + [Environment]::NewLine + '            MinHeight="80"' + [Environment]::NewLine + '            Background="{ThemeResource PlayerTitleBarBackgroundBrush}">'
        New = '<sbuc:TitleBar' + [Environment]::NewLine + '            x:Name="PlayerTitleBar"' + [Environment]::NewLine + '            MinHeight="72"' + [Environment]::NewLine + '            Background="#111B29">'
    },
    @{
        Old = '<Thickness x:Key="PlayerTitleBarButtonMargin">4,-24,0,0</Thickness>'
        New = '<Thickness x:Key="PlayerTitleBarButtonMargin">4,0,0,0</Thickness>'
    },
    @{
        Old = 'x:Name="TitleBarTitleTextBlock"' + [Environment]::NewLine + '                        d:Text="Lorem ipsum dolor sit amet"' + [Environment]::NewLine + '                        Style="{StaticResource SubtitleTextBlockStyle}"'
        New = 'x:Name="TitleBarTitleTextBlock"' + [Environment]::NewLine + '                        d:Text="Lorem ipsum dolor sit amet"' + [Environment]::NewLine + '                        FontSize="15"' + [Environment]::NewLine + '                        FontWeight="SemiBold"' + [Environment]::NewLine + '                        Foreground="#F3F6FA"' + [Environment]::NewLine + '                        Style="{StaticResource SubtitleTextBlockStyle}"'
    },
    @{
        Old = 'x:Name="TitleBarSubtitleTextBlock"' + [Environment]::NewLine + '                        d:Text="Lorem ipsum dolor sit amet, consectetur adipiscing elit"' + [Environment]::NewLine + '                        Foreground="{ThemeResource TextFillColorSecondaryBrush}"'
        New = 'x:Name="TitleBarSubtitleTextBlock"' + [Environment]::NewLine + '                        d:Text="Lorem ipsum dolor sit amet, consectetur adipiscing elit"' + [Environment]::NewLine + '                        Foreground="#91A2B6"'
    }
)

foreach ($item in $replacements) {
    if ($xaml.Contains($item.New)) { continue }
    if (!$xaml.Contains($item.Old)) {
        throw "Player surface anchor not found: $($item.Old.Split([Environment]::NewLine)[0])"
    }
    $xaml = $xaml.Replace($item.Old, $item.New)
}

Set-Content -Path $playerPath -Value $xaml -Encoding UTF8
Write-Host 'Mosuan player surface applied: unified header and transport surfaces, tightened title hierarchy.'
