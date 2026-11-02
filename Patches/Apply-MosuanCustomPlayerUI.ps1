$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$controlsPath = Join-Path $root 'Controls\PlayerControls.xaml'
$playerPath = Join-Path $root 'Pages\PlayerPage.xaml'
foreach ($path in @($controlsPath, $playerPath)) {
    if (!(Test-Path $path)) { throw "Custom player UI target not found: $path" }
}

# Rebuild the transport surface as a distinct Mosuan control deck.
# Keep the existing named controls, commands, flyouts and state groups so the
# playback state machine and keyboard behavior remain intact.
$controls = Get-Content -Raw -Encoding UTF8 $controlsPath

if (!$controls.Contains('MosuanControlDeck')) {
    $resourceAnchor = '        </ResourceDictionary>' + [Environment]::NewLine + '    </UserControl.Resources>'
    if (!$controls.Contains($resourceAnchor)) { throw 'PlayerControls resource dictionary anchor not found.' }

    $styles = @'
            <Style x:Key="PlayerButtonStyle" TargetType="Button" BasedOn="{StaticResource SubtleButtonStyle}">
                <Setter Property="Background" Value="#1B2736" />
                <Setter Property="Foreground" Value="#E8EEF5" />
                <Setter Property="BorderBrush" Value="#34465B" />
                <Setter Property="BorderThickness" Value="1" />
                <Setter Property="CornerRadius" Value="10" />
                <Setter Property="Width" Value="42" />
                <Setter Property="Height" Value="42" />
                <Setter Property="Padding" Value="8" />
            </Style>
            <Style x:Key="PlayerToggleButtonStyle" TargetType="ToggleButton" BasedOn="{StaticResource SubtleToggleButtonStyle}">
                <Setter Property="Background" Value="#1B2736" />
                <Setter Property="Foreground" Value="#C9D4E2" />
                <Setter Property="BorderBrush" Value="#34465B" />
                <Setter Property="BorderThickness" Value="1" />
                <Setter Property="CornerRadius" Value="10" />
                <Setter Property="Width" Value="40" />
                <Setter Property="Height" Value="40" />
                <Setter Property="Padding" Value="8" />
            </Style>
            <Style x:Key="SmallPlayerButtonStyle" TargetType="Button" BasedOn="{StaticResource PlayerButtonStyle}">
                <Setter Property="Width" Value="34" />
                <Setter Property="Height" Value="34" />
            </Style>
            <Style x:Key="SmallPlayerToggleButtonStyle" TargetType="ToggleButton" BasedOn="{StaticResource PlayerToggleButtonStyle}">
                <Setter Property="Width" Value="34" />
                <Setter Property="Height" Value="34" />
            </Style>
'@
    $controls = $controls.Replace($resourceAnchor, $styles + $resourceAnchor)
}

if (!$controls.Contains('x:Name="MosuanControlDeck"')) {
    $rootStart = '    <Grid' + [Environment]::NewLine + '        Padding="{x:Bind Padding, Mode=OneWay}"'
    $start = $controls.IndexOf($rootStart)
    if ($start -lt 0) { throw 'PlayerControls root grid anchor not found.' }
    $visualStart = $controls.IndexOf('        <VisualStateManager.VisualStateGroups>', $start)
    $rootEnd = $controls.LastIndexOf('    </Grid>' + [Environment]::NewLine + '</UserControl>')
    if ($visualStart -lt 0 -or $rootEnd -lt $visualStart) { throw 'PlayerControls visual state section not found.' }
    $visualStates = $controls.Substring($visualStart, $rootEnd - $visualStart)

    $newRoot = @'
    <Grid
        x:Name="MosuanControlDeck"
        Padding="{x:Bind Padding, Mode=OneWay}"
        Background="{x:Bind Background, Mode=OneWay}"
        BackgroundTransition="{x:Bind BackgroundTransition, Mode=OneWay}"
        KeyTipPlacementMode="Top">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <Border
            Grid.RowSpan="4"
            Background="#111B29"
            BorderBrush="#2B3B50"
            BorderThickness="1"
            CornerRadius="18" />

        <Grid Grid.Row="0" Margin="18,12,18,2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>
            <StackPanel Orientation="Horizontal" Spacing="8" VerticalAlignment="Center">
                <Border Width="7" Height="7" CornerRadius="4" Background="#F28C28" VerticalAlignment="Center" />
                <TextBlock Text="墨算播放控制" FontSize="12" FontWeight="SemiBold" Foreground="#AFC0D3" />
            </StackPanel>
            <TextBlock
                Grid.Column="2"
                Text="MOSUAN  PLAYER"
                FontSize="10"
                CharacterSpacing="150"
                Foreground="#60758D"
                VerticalAlignment="Center" />
        </Grid>

        <Grid Grid.Row="1" Margin="18,0,18,8">
            <controls:SeekBar
                x:Name="SeekBar"
                Grid.Row="0"
                Margin="0"
                Height="18"
                HorizontalAlignment="Stretch"
                VerticalAlignment="Center"
                Background="Transparent"
                Foreground="#F28C28" />
        </Grid>

        <Grid Grid.Row="2" Margin="12,0,12,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Spacing="5">
                <Button
                    x:Name="PlayPauseButton"
                    Width="48"
                    Height="48"
                    Margin="0,0,5,0"
                    Background="#F28C28"
                    Foreground="#111827"
                    BorderBrush="#F28C28"
                    BorderThickness="1"
                    CornerRadius="14"
                    Padding="8"
                    extensions:AcceleratorService.ToolTip="{x:Bind helpers:ItemLabelHelper.GetPlayPauseLabel(ViewModel.IsPlaying), Mode=OneWay}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerPlayPauseKey}"
                    AutomationProperties.Name="{x:Bind helpers:ItemLabelHelper.GetPlayPauseLabel(ViewModel.IsPlaying), Mode=OneWay}"
                    Command="{x:Bind ViewModel.PlayPauseCommand}">
                    <FontIcon FontFamily="{StaticResource ScreenboxSymbolThemeFontFamily}" FontSize="20" Foreground="#111827" Glyph="{x:Bind converters:GlyphConverter.ToPlayPauseGlyph(ViewModel.IsPlaying), Mode=OneWay}" />
                    <Button.KeyboardAccelerators>
                        <KeyboardAccelerator Key="P" Invoked="PlayPauseKeyboardAccelerator_OnInvoked" />
                        <KeyboardAccelerator Key="K" Invoked="PlayPauseKeyboardAccelerator_OnInvoked" />
                    </Button.KeyboardAccelerators>
                </Button>
                <Button
                    x:Name="PreviousButton"
                    Width="40" Height="40"
                    Background="#1B2736" Foreground="#E8EEF5"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.Previous}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerPreviousKey}"
                    AutomationProperties.Name="{x:Bind PreviousButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    Command="{x:Bind ViewModel.PreviousCommand}">
                    <FontIcon Glyph="&#xE892;" />
                    <Button.KeyboardAccelerators>
                        <KeyboardAccelerator Key="PageUp" />
                        <KeyboardAccelerator Key="P" Modifiers="Shift" />
                    </Button.KeyboardAccelerators>
                </Button>
                <Button
                    x:Name="NextButton"
                    Width="40" Height="40"
                    Background="#1B2736" Foreground="#E8EEF5"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.Next}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerNextKey}"
                    AutomationProperties.Name="{x:Bind NextButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    Command="{x:Bind ViewModel.NextCommand}">
                    <FontIcon Glyph="&#xE893;" />
                    <Button.KeyboardAccelerators>
                        <KeyboardAccelerator Key="PageDown" />
                        <KeyboardAccelerator Key="N" Modifiers="Shift" />
                    </Button.KeyboardAccelerators>
                </Button>
                <Border Width="1" Height="28" Background="#34465B" Margin="8,0" />
                <controls:TimeDisplay
                    x:Name="TimeDisplay"
                    MinWidth="0"
                    Margin="4,0,0,0"
                    VerticalAlignment="Center"
                    Foreground="#DDE6F0"
                    FontSize="13"
                    IsRemainingTimeVisible="{x:Bind ViewModel.IsDisplayingRemainingTime, Mode=TwoWay}"
                    Length="{x:Bind SeekBar.ViewModel.Length, Mode=OneWay}"
                    Time="{x:Bind SeekBar.ViewModel.Time, Mode=OneWay}" />
                <Button
                    x:Name="ChapterButton"
                    Width="Auto"
                    Margin="8,0,0,0"
                    Padding="8,0"
                    Background="#1B2736"
                    Foreground="#C9D4E2"
                    BorderBrush="#34465B"
                    BorderThickness="1"
                    CornerRadius="8"
                    IsEnabled="{x:Bind IsEnabled, Mode=OneWay}"
                    Visibility="{x:Bind GetChapterVisibility(ViewModel.PlayerShowChapters, SeekBar.ViewModel.Chapters.Count), Mode=OneWay}">
                    <TextBlock
                        Text="{x:Bind converters:ChapterTitleConverter.GetChapterTitle(SeekBar.ViewModel.CurrentChapterCue, SeekBar.ViewModel.Chapters), Mode=OneWay}"
                        TextTrimming="CharacterEllipsis" />
                    <Button.Flyout>
                        <Flyout ShouldConstrainToRootBounds="True">
                            <controls:ChapterPickerControl
                                ChapterCommand="{x:Bind SeekBar.ViewModel.SeekToChapterCommand}"
                                ChaptersSource="{x:Bind SeekBar.ViewModel.Chapters}"
                                Label="{x:Bind strings:Resources.ChapterPluralized(SeekBar.ViewModel.Chapters.Count), Mode=OneWay}"
                                SelectedChapter="{x:Bind SeekBar.ViewModel.CurrentChapterCue, Mode=TwoWay}" />
                        </Flyout>
                    </Button.Flyout>
                </Button>
            </StackPanel>

            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Spacing="5">
                <controls:VolumeControl
                    x:Name="VolumeControl"
                    Width="124"
                    Margin="0,0,6,0"
                    ShowValueText="False"
                    VolumeToggleButtonStyle="{StaticResource PlayerToggleButtonStyle}" />
                <ToggleButton
                    x:Name="ShuffleButton"
                    Width="38" Height="38"
                    Background="#1B2736" Foreground="#C9D4E2"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.ShuffleMode(ViewModel.PlayQueue.ShuffleMode), Mode=OneWay}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerShuffleKey}"
                    AutomationProperties.Name="{x:Bind ShuffleButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    IsChecked="{x:Bind ViewModel.PlayQueue.ShuffleMode, Mode=TwoWay}"
                    IsEnabled="{x:Bind IsEnabled, Mode=OneWay}">
                    <FontIcon FontFamily="{StaticResource ScreenboxSymbolThemeFontFamily}" Glyph="{x:Bind converters:GlyphConverter.ToShuffleGlyph(ViewModel.PlayQueue.ShuffleMode), Mode=OneWay}" />
                    <ToggleButton.KeyboardAccelerators><KeyboardAccelerator Key="S" Modifiers="Control" /></ToggleButton.KeyboardAccelerators>
                </ToggleButton>
                <ToggleButton
                    x:Name="RepeatButton"
                    Width="38" Height="38"
                    Background="#1B2736" Foreground="#C9D4E2"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.RepeatMode(ViewModel.PlayQueue.RepeatMode), Mode=OneWay}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerRepeatKey}"
                    AutomationProperties.Name="{x:Bind RepeatButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    IsChecked="{x:Bind ViewModel.PlayQueue.RepeatMode, Converter={StaticResource ToggleButtonCheckToRepeatModeConverter}, Mode=TwoWay}"
                    IsEnabled="{x:Bind IsEnabled, Mode=OneWay}"
                    IsThreeState="True">
                    <FontIcon FontFamily="{StaticResource ScreenboxSymbolThemeFontFamily}" Glyph="{x:Bind converters:GlyphConverter.ToRepeatGlyph(ViewModel.PlayQueue.RepeatMode), Mode=OneWay}" />
                    <ToggleButton.KeyboardAccelerators><KeyboardAccelerator Key="R" Modifiers="Control" /></ToggleButton.KeyboardAccelerators>
                </ToggleButton>
                <Button
                    x:Name="AudioAndCaptionButton"
                    Width="38" Height="38"
                    Background="#1B2736" Foreground="#C9D4E2"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.AudioAndCaption}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerAudioAndCaptionsKey}"
                    AutomationProperties.Name="{x:Bind AudioAndCaptionButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    IsEnabled="{x:Bind IsEnabled, Mode=OneWay}">
                    <FontIcon Glyph="&#xED1F;" />
                    <Button.KeyboardAccelerators>
                        <KeyboardAccelerator Key="C" Invoked="ToggleSubtitleKeyboardAccelerator_OnInvoked" />
                        <KeyboardAccelerator Key="C" Invoked="ToggleSubtitleKeyboardAccelerator_OnInvoked" Modifiers="Control" />
                        <KeyboardAccelerator Key="C" Invoked="ToggleSubtitleKeyboardAccelerator_OnInvoked" Modifiers="Control,Shift" />
                    </Button.KeyboardAccelerators>
                    <Button.Flyout>
                        <Flyout
                            x:Name="AudioSubtitlePickerFlyout"
                            Closed="{x:Bind AudioTrackSubtitlePicker.ViewModel.OnFlyoutClosed}"
                            FlyoutPresenterStyle="{StaticResource FlyoutPresenterMenuFlyoutStyle}"
                            Opening="{x:Bind AudioTrackSubtitlePicker.ViewModel.OnFlyoutOpening}"
                            ShouldConstrainToRootBounds="False">
                            <controls:CompositeTrackPicker x:Name="AudioTrackSubtitlePicker" IsAccessKeyScope="True" />
                        </Flyout>
                    </Button.Flyout>
                </Button>
                <Button
                    x:Name="VolumeButton"
                    Width="38" Height="38"
                    Background="#1B2736" Foreground="#C9D4E2"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.Volume}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerVolumeButtonSliderKey}"
                    AutomationProperties.Name="{x:Bind VolumeButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    Flyout="{StaticResource VolumeControlFlyout}"
                    IsEnabled="{x:Bind IsEnabled, Mode=OneWay}"
                    Visibility="Collapsed">
                    <FontIcon Glyph="{x:Bind converters:GlyphConverter.ToVolumeGlyph(VolumeControl.ViewModel.IsMute, VolumeControl.ViewModel.Volume), Mode=OneWay}" />
                    <Button.KeyboardAccelerators><KeyboardAccelerator Key="M" /></Button.KeyboardAccelerators>
                </Button>
                <Button
                    x:Name="CompactOverlayButton"
                    Width="38" Height="38"
                    Background="#1B2736" Foreground="#C9D4E2"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.CompactOverlayToggle(ViewModel.IsCompact), Mode=OneWay}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerCompactOverlayKey}"
                    AutomationProperties.Name="{x:Bind CompactOverlayButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    Command="{x:Bind ViewModel.ToggleCompactLayoutCommand}"
                    Visibility="{x:Bind helpers:DeviceInfoHelper.IsDesktop}">
                    <FontIcon x:Name="CompactOverlayButtonIcon" FontFamily="{StaticResource ScreenboxSymbolThemeFontFamily}" Glyph="{StaticResource MiniContract2MirroredGlyph}" />
                    <Button.KeyboardAccelerators><KeyboardAccelerator Key="M" Modifiers="Control" /></Button.KeyboardAccelerators>
                </Button>
                <Button
                    x:Name="FullscreenButton"
                    Width="38" Height="38"
                    Background="#1B2736" Foreground="#C9D4E2"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    extensions:AcceleratorService.ToolTip="{x:Bind strings:Resources.FullscreenToggle(ViewModel.IsFullscreen), Mode=OneWay}"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerFullscreenKey}"
                    AutomationProperties.Name="{x:Bind FullscreenButton.(extensions:AcceleratorService.ToolTip), Mode=OneWay}"
                    Command="{x:Bind ViewModel.ToggleFullscreenCommand}"
                    Visibility="{x:Bind helpers:DeviceInfoHelper.IsDesktop}">
                    <FontIcon x:Name="FullscreenButtonIcon" Glyph="&#xE740;" />
                    <Button.KeyboardAccelerators>
                        <KeyboardAccelerator Key="F" />
                        <KeyboardAccelerator Key="F11" />
                    </Button.KeyboardAccelerators>
                </Button>
                <Button
                    x:Name="MoreButton"
                    Width="38" Height="38"
                    Background="#1B2736" Foreground="#C9D4E2"
                    BorderBrush="#34465B" BorderThickness="1" CornerRadius="10"
                    AccessKey="{x:Bind strings:KeyboardResources.PlayerMoreKey}"
                    AutomationProperties.Name="{x:Bind MoreButton.(ToolTipService.ToolTip)}"
                    Flyout="{StaticResource NormalPlayerContextMenu}"
                    IsAccessKeyScope="True"
                    IsEnabled="{x:Bind IsEnabled, Mode=OneWay}"
                    ToolTipService.ToolTip="{x:Bind strings:Resources.More}">
                    <FontIcon Glyph="&#xE712;" />
                </Button>
            </StackPanel>
        </Grid>

        <Grid Grid.Row="3" Visibility="Collapsed" />
'@
    # Compact mode moves the seek bar to the reserved final row.
    $visualStates = $visualStates.Replace('Target="SeekBar.(Grid.Row)" Value="2"', 'Target="SeekBar.(Grid.Row)" Value="3"')
    $newRoot += $visualStates + '    </Grid>' + [Environment]::NewLine + '</UserControl>'
    $controls = $controls.Substring(0, $start) + $newRoot
    Set-Content -Path $controlsPath -Value $controls -Encoding UTF8
}

# Make the title area read as Mosuan, not the stock Screenbox gradient header.
$player = Get-Content -Raw -Encoding UTF8 $playerPath
$player = $player.Replace('MinHeight="80"' + [Environment]::NewLine + '            Background="{ThemeResource PlayerTitleBarBackgroundBrush}"',
    'MinHeight="68"' + [Environment]::NewLine + '            Background="#111B29"')
$player = $player.Replace('Margin="16,-12,0,16"', 'Margin="18,-6,0,8"')
if (!$player.Contains('Text="墨算播放器"')) {
    $anchor = '                    <TextBlock' + [Environment]::NewLine + '                        x:Name="TitleBarTitleTextBlock"'
    if (!$player.Contains($anchor)) { throw 'Player title text anchor not found.' }
    $brand = @'
                    <TextBlock
                        Text="墨算播放器"
                        FontSize="10"
                        FontWeight="SemiBold"
                        CharacterSpacing="120"
                        Foreground="#F28C28"
                        Margin="0,0,0,2" />
'@
    $player = $player.Replace($anchor, $brand + $anchor)
}
Set-Content -Path $playerPath -Value $player -Encoding UTF8

Write-Host 'Mosuan custom player UI applied: branded title strip and a redesigned floating transport deck.'
