# Windows-native control and persistence checks. Never uses the real game/config.
param([string]$CaptureDir)
$ErrorActionPreference = 'Stop'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('bdo-dashboard-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot
$settings = Join-Path $tempRoot 'config.json'
Add-Type -AssemblyName PresentationFramework
$bindingLog = [IO.StringWriter]::new()
$bindingListener = [Diagnostics.TextWriterTraceListener]::new($bindingLog)
$bindingSource = [Diagnostics.PresentationTraceSources]::DataBindingSource
$previousTraceLevel = $bindingSource.Switch.Level
$bindingSource.Switch.Level = [Diagnostics.SourceLevels]::Warning
$null = $bindingSource.Listeners.Add($bindingListener)
try {
    . (Join-Path $PSScriptRoot '..\..\bdo_aio_gui.ps1') -ConfigFile $settings -NoShow
    if (Test-Path -LiteralPath $settings) { throw 'Opening the dashboard wrote settings.' }
    if ($Script:UI.ThemeBox.SelectedItem.Tag -ne 'Dark') { throw 'Dark must be the default theme.' }
    foreach ($theme in @('Night', 'Light', 'Dark')) {
        $Script:UI.ThemeBox.SelectedItem = @($Script:UI.ThemeBox.Items | Where-Object Tag -eq $theme)[0]
        if ($Script:DashboardTheme -ne $theme -or -not $Script:DashboardDirty) { throw 'Theme selection did not preview or mark unsaved.' }
        if (Test-Path -LiteralPath $settings) { throw 'Theme preview saved unrelated choices.' }
        if ($Script:DashboardWindow.Background.ToString() -ne $Script:DashboardWindow.Resources['CanvasBrush'].ToString()) { throw 'Window theme resource is stale.' }
    }
    if (-not (Save-DashboardSettings)) { throw 'Theme save failed.' }
    $Script:UI.ThemeBox.SelectedItem = @($Script:UI.ThemeBox.Items | Where-Object Tag -eq 'Night')[0]
    if (-not (Save-DashboardSettings)) { throw 'Night save failed.' }
    $savedTheme = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    if ($savedTheme.uiTheme -ne 'Night') { throw 'Theme did not persist.' }
    $Script:UI.ThemeBox.SelectedItem = @($Script:UI.ThemeBox.Items | Where-Object Tag -eq 'Light')[0]
    Read-DashboardSettings
    if ($Script:DashboardTheme -ne 'Night') { throw 'Reload did not discard theme preview.' }
    $savedTheme.uiTheme = 'invalid'
    [IO.File]::WriteAllText($settings, ($savedTheme | ConvertTo-Json -Depth 32))
    Read-DashboardSettings
    if ($Script:DashboardTheme -ne 'Dark') { throw 'Invalid saved theme did not fall back to Dark.' }
    Set-DashboardMessage 'Fixture error' -IsError
    $Script:UI.ThemeBox.SelectedItem = @($Script:UI.ThemeBox.Items | Where-Object Tag -eq 'Night')[0]
    Set-DashboardMessage 'Fixture error' -IsError
    if ($Script:UI.SaveState.Foreground.ToString() -ne $Script:DashboardWindow.Resources['ErrorBrush'].ToString()) { throw 'Error text ignores theme.' }
    Read-DashboardSettings
    foreach ($theme in @('Dark', 'Night', 'Light')) {
        Set-DashboardTheme $theme
        foreach ($match in [regex]::Matches($dashboardXaml.OuterXml, '\{DynamicResource (\w+)\}')) {
            if (-not $Script:DashboardWindow.Resources.Contains($match.Groups[1].Value)) { throw "Missing theme resource: $($match.Value)" }
        }
        $Script:UI.ThemeBox.ApplyTemplate() | Out-Null
        $popup = $Script:UI.ThemeBox.Template.FindName('PART_Popup', $Script:UI.ThemeBox)
        if ($popup.Child.Background.ToString() -ne $Script:DashboardWindow.Resources['FieldBrush'].ToString()) { throw 'Dropdown surface ignores theme.' }
        Set-DashboardMessage 'Error retained across palette changes' -IsError
        Set-DashboardTheme $(if ($theme -eq 'Light') { 'Night' } else { 'Light' })
        if ($Script:UI.SaveState.Foreground.ToString() -ne $Script:DashboardWindow.Resources['ErrorBrush'].ToString()) { throw 'Existing validation text kept a stale brush.' }
    }
    Read-DashboardSettings
    Write-Host 'PASS: theme default, live preview, explicit save, reload, invalid fallback, complete resources and themed popup/feedback.'
    if ($Script:BodyInputs.Count -ne 12) { throw 'Body axis coverage changed.' }
    if ($Script:DashboardActions.Count -ne 11) { throw "Unexpected action coverage: $($Script:DashboardActions.Count)" }
    if ([string]$Script:UI.GraphicsProfile.SelectedItem.Tag -ne 'GameOption_Remastered_1440p.patch') { throw '1440p is not the default graphics profile.' }
    if (-not (Save-DashboardSettings)) { throw 'Could not save initial settings.' }

    # Add fields the dashboard does not own, then exercise its actual save path.
    $saved = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    $saved.pubicHairStyles = 'pew=medium_bush,pww=full_bush'
    $saved.genitalFemaleClasses = 'pew,pww'
    $saved | Add-Member -NotePropertyName userExtension -NotePropertyValue ([pscustomobject]@{ nested = @('keep', 42) })
    [IO.File]::WriteAllText($settings, ($saved | ConvertTo-Json -Depth 10))
    Read-DashboardSettings
    $Script:BodyInputs['belly.x'].Text = '1.75'
    $Script:UI.hideBoots.IsChecked = $true
    if (-not (Save-DashboardSettings)) { throw $Script:UI.SaveState.Text }
    $saved = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    if ($saved.pubicHairStyles -ne 'pew=medium_bush,pww=full_bush' -or $saved.userExtension.nested[1] -ne 42 -or $saved.genitalFemaleClasses -ne 'pew,pww') { throw 'Saving dropped unrelated choices.' }
    if (-not $saved.hideBoots -or $saved.bodySizeParts -notmatch 'belly.x:1.75') { throw 'Edited choices were not saved.' }
    if (-not (Test-Path -LiteralPath ($settings + '.bak'))) { throw 'Previous config was not retained.' }
    $before = [IO.File]::ReadAllText($settings)
    $Script:BodyInputs['belly.x'].Text = 'NaN'
    if (Save-DashboardSettings) { throw 'NaN was accepted.' }
    if ($Script:UI.Nav.SelectedIndex -ne 2 -or $Script:DashboardInvalidInput -ne $Script:BodyInputs['belly.x']) { throw 'Validation did not target the invalid field.' }
    if ([Windows.Automation.AutomationProperties]::GetLiveSetting($Script:UI.SaveState) -ne 'Assertive') { throw 'Validation feedback is not a live region.' }
    if ([IO.File]::ReadAllText($settings) -ne $before) { throw 'Invalid values changed the saved config.' }
    Read-DashboardSettings
    [IO.File]::AppendAllText($settings, ' ')
    if (Save-DashboardSettings) { throw 'An external config edit was overwritten.' }
    Read-DashboardSettings
    foreach ($tier in @('off', 'minimal', 'medium', 'high', 'expanded')) {
        if (-not @($Script:UI.CensorshipBox.Items | Where-Object Tag -eq $tier).Count) { throw "Missing censorship tier $tier." }
    }
    Write-Host 'PASS: settings round-trip, unknown fields, atomic backup, invalid input and concurrent edits.'

    # The former console-only options now edit the real settings through WPF controls.
    if ($Script:PubicInputs.Count -ne 5 -or $Script:FemaleMeshInputs.Count -ne 10 -or $Script:MaleMeshInputs.Count -ne 6) { throw 'Detailed class coverage changed.' }
    $Script:UI.DetailsButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($Script:UI.DetailsPanel.Visibility -ne 'Visible' -or $Script:DashboardProcess) { throw 'Detailed editor still leaves the dashboard.' }
    $Script:PubicInputs['pew'].SelectedItem = @($Script:PubicInputs['pew'].Items | Where-Object Tag -eq 'trimmed')[0]
    $Script:UI.SharedPubicBox.SelectedItem = @($Script:UI.SharedPubicBox.Items | Where-Object Tag -eq 'full_bush')[0]
    $Script:UI.SlotClasses.Text = 'pew,pdw'
    $Script:UI.MaleModeBox.SelectedItem = @($Script:UI.MaleModeBox.Items | Where-Object Tag -eq 'perclass')[0]
    $Script:MaleMeshInputs['penisWarrior'].SelectedItem = @($Script:MaleMeshInputs['penisWarrior'].Items | Where-Object Tag -eq 'hard')[0]
    if (-not (Save-DashboardSettings)) { throw $Script:UI.SaveState.Text }
    $map = Get-PubicStyleMap
    if ($map['pew'] -ne 'trimmed' -or $map['pww'] -ne 'full_bush' -or $map.Count -ne 15) { throw 'Private/shared style edit lost choices.' }
    foreach ($prefix in $Script:SharedAtlasPrefixes) { if ($map[$prefix] -ne 'full_bush') { throw 'Shared texture styles diverged.' } }
    if ($Script:Config.slotHideClasses -ne 'pew,pdw' -or $Script:Config.malePenisMode -ne 'perclass' -or $Script:Config.penisWarrior -ne 'hard') { throw 'Detailed options did not persist.' }
    $Script:UI.MaleModeBox.SelectedItem = @($Script:UI.MaleModeBox.Items | Where-Object Tag -eq 'none')[0]
    if (-not (Save-DashboardSettings) -or $Script:Config.penisWarrior -ne 'hard') { throw 'Turning male mode off erased custom choices.' }

    $Script:UI.FemaleMeshEnabled.IsChecked = $true
    $Script:UI.FemaleMeshEnabled.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    foreach ($input in $Script:FemaleMeshInputs.Values) { $input.IsChecked = $false }
    Set-DashboardDetailEdited 'female'
    $before = [IO.File]::ReadAllText($settings)
    if (Save-DashboardSettings) { throw 'Empty enabled female selection was broadened to ALL.' }
    if ([IO.File]::ReadAllText($settings) -ne $before -or $Script:UI.DetailTabs.SelectedIndex -ne 1 -or $Script:UI.Nav.SelectedIndex -ne 3) { throw 'Female validation lost settings or focus context.' }
    $Script:FemaleMeshInputs['pew'].IsChecked = $true
    if (-not (Save-DashboardSettings) -or $Script:Config.genitalFemaleClasses -ne 'pew' -or -not $Script:Config.female3dVagina) { throw 'Female class picker did not save.' }
    $Script:UI.SlotClasses.Text = 'pew; Remove-Item'
    if (Save-DashboardSettings) { throw 'Invalid class syntax accepted.' }
    Read-DashboardSettings

    # Existing mixed/partial shared choices remain byte-for-byte unless edited.
    $saved = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    $saved.pubicHairStyles = 'phw=trimmed,pnw=full_bush,pfw=shaved'
    [IO.File]::WriteAllText($settings, ($saved | ConvertTo-Json -Depth 32))
    Read-DashboardSettings
    if ($Script:UI.SharedPubicBox.SelectedItem.Tag -ne 'keep') { throw 'Legacy mixed styles were misrepresented.' }
    if (-not (Save-DashboardSettings) -or $Script:Config.pubicHairStyles -ne 'phw=trimmed,pnw=full_bush,pfw=shaved') { throw 'Unrelated save rewrote legacy pubic styles.' }
    Set-DashboardPubicPreset -Clear
    if (-not (Save-DashboardSettings) -or (Get-PubicStyleMap).Count -ne 0 -or $Script:Config.pubicHairStyle -ne 'none') { throw 'Clear styles left an active selection.' }
    Set-DashboardPubicPreset
    if (-not (Save-DashboardSettings) -or (Get-PubicStyleMap).Count -ne $Script:PubicImmersivePreset.Count) { throw 'Native immersive preset differs from engine.' }
    $Script:UI.DetailTabs.SelectedIndex = 0
    Write-Host 'PASS: native detailed editing, shared atlas, presets, male modes, class validation and legacy preservation.'

    $chrome = [Windows.Shell.WindowChrome]::GetWindowChrome($Script:DashboardWindow)
    if ($Script:DashboardWindow.WindowStyle -ne 'None' -or $chrome.CaptionHeight -ne 44 -or $chrome.ResizeBorderThickness.Left -le 0) { throw 'Custom title bar lost native resize/drag chrome.' }
    foreach ($name in @('MinimizeButton','MaximizeButton','CloseButton')) {
        if (-not [Windows.Shell.WindowChrome]::GetIsHitTestVisibleInChrome($Script:UI[$name]) -or -not [Windows.Automation.AutomationProperties]::GetName($Script:UI[$name])) { throw 'Caption control is not accessible/clickable.' }
    }
    if (-not $Script:DashboardWindow.Resources[[Windows.Controls.Primitives.ScrollBar]] -or -not $Script:DashboardWindow.Resources[[Windows.Controls.ComboBox]]) { throw 'Scrollbar/dropdown styling missing.' }
    $root = $Script:DashboardWindow.Content
    $root.Measure([Windows.Size]::new(940, 680))
    $root.Arrange([Windows.Rect]::new(0, 0, 940, 680))
    $root.UpdateLayout()
    $lastPage = $Script:UI.Nav.Items[$Script:UI.Nav.Items.Count - 1]
    $navBottom = $lastPage.TranslatePoint([Windows.Point]::new(0, $lastPage.ActualHeight), $root).Y
    $themeTop = $Script:UI.ThemeBox.TranslatePoint([Windows.Point]::new(0, 0), $root).Y
    if ($lastPage.ActualHeight -le 0 -or $navBottom -gt ($themeTop - 24)) { throw 'At 940x680, navigation overlaps the Appearance label/selector.' }
    Write-Host 'PASS: all eight navigation entries fit above Appearance at 940x680.'
    $Script:UI.PageScroll.ScrollToVerticalOffset(120)
    $root.UpdateLayout()
    if ($Script:UI.PageScroll.VerticalOffset -le 0) { throw 'Custom vertical scrollbar lost scrolling.' }
    $bar = $Script:UI.PageScroll.Template.FindName('PART_VerticalScrollBar', $Script:UI.PageScroll)
    if (-not $bar -or -not $bar.Template.FindName('PART_Track', $bar) -or $bar.Value -ne $Script:UI.PageScroll.VerticalOffset) { throw 'Custom scrollbar track lost scroll binding.' }
    $Script:UI.PageScroll.ScrollToTop()
    $Script:UI.MaleModeBox.ApplyTemplate() | Out-Null
    if (-not $Script:UI.MaleModeBox.Template.FindName('PART_Popup', $Script:UI.MaleModeBox)) { throw 'Styled combo lost native popup part.' }
    Write-Host 'PASS: custom chrome retains resize regions and accessible caption controls; shared control styles present.'

    # Actual WPF selection event, not a string check.
    $Script:UI.Nav.SelectedIndex = 2
    if ($Script:UI.BodyPanel.Visibility -ne 'Visible' -or $Script:UI.OverviewPanel.Visibility -ne 'Collapsed') { throw 'Navigation failed.' }
    Set-DashboardBusy $true
    if ($Script:UI.SaveButton.IsEnabled -or $Script:UI.BodyPanel.IsEnabled -or $Script:UI.DetailsPanel.IsEnabled -or $Script:UI.ApplyButton.IsEnabled) { throw 'Busy controls are still enabled.' }
    Set-DashboardBusy $false
    $fixture = [pscustomobject]@{
        scanned_at = [DateTime]::UtcNow.ToString('o')
        meta = [pscustomobject]@{ state = 'MODDED'; detail = 'Fixture: meta differs from a same-version reference. This is a UI test, not a live game scan.'; meta_version = 3435; version_matches = $true }
        files_to_patch = [pscustomobject]@{ total_files = 2254 }
    }
    Update-DashboardStatus $fixture
    if ($Script:UI.StatusTitle.Text -ne 'Meta modified') { throw 'Modified meta was mislabeled as a proven injection.' }
    Write-Host 'PASS: navigation, busy state, and evidence-calibrated status.'

    # Hold an actual runspace result for A while requesting B. A must never land.
    $Script:DashboardScan = [PowerShell]::Create()
    $null = $Script:DashboardScan.AddScript({ param($report) Start-Sleep -Milliseconds 150; return $report }).AddArgument([pscustomobject]@{ report = $fixture; paz = 'old-game'; pythonPath = ''; python = $false; pack = $false; toolkit = $false })
    $Script:DashboardScanHandle = $Script:DashboardScan.BeginInvoke()
    $Script:Config.pazFolder = Join-Path $tempRoot 'new-game'
    $Script:UI.PazPath.Text = $Script:Config.pazFolder
    Start-DashboardScan
    if (-not $Script:DashboardScanPending) { throw 'Replacement scan was dropped.' }
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ($Script:DashboardScan -and [DateTime]::UtcNow -lt $deadline) { Update-DashboardTick; Start-Sleep -Milliseconds 30 }
    if ($Script:DashboardScan) { throw 'Queued scan timed out.' }
    if ($Script:DashboardScanPending -or $Script:UI.VersionValue.Text -eq '3435' -or $Script:UI.StatusTitle.Text -eq 'Meta modified') { throw 'Stale target scan reached the new game overview.' }
    Update-DashboardStatus $fixture
    $Script:DashboardScan = [PowerShell]::Create()
    $null = $Script:DashboardScan.AddScript({ throw 'test scan failure' })
    $Script:DashboardScanHandle = $Script:DashboardScan.BeginInvoke()
    while (-not $Script:DashboardScanHandle.IsCompleted) { Start-Sleep -Milliseconds 10 }
    Update-DashboardTick
    if ($Script:UI.StatusTitle.Text -ne 'Status check failed' -or $Script:UI.BackupValue.Text -ne 'Unknown' -or $Script:UI.VersionValue.Text -ne 'Unknown' -or $Script:UI.StatusUpdated.Text -ne 'Not verified') { throw 'Scan failure retained previous verification evidence.' }
    Read-DashboardSettings
    Update-DashboardStatus $fixture
    Write-Host 'PASS: stale scan is discarded and refreshed; failed scans clear previous evidence.'

    $recovery = [pscustomobject]@{
        targetPaz = $Script:Config.pazFolder; token = ('a' * 64); scannedAt = [DateTime]::UtcNow.ToString('o')
        current = [pscustomobject]@{ version = 3444; valid = $true }
        backup = [pscustomobject]@{ name = 'pad00000.BDOAIO-VANILLA.meta'; version = 3435 }
        restore = [pscustomobject]@{ allowed = $false; reason = 'Backup client 3435 differs from live client 3444. Restore is blocked.' }
        snapshot = [pscustomobject]@{ allowed = $true; reason = 'Fixture: current archive checks passed. Confirm launcher repair finished.' }
        cleanup = [pscustomobject]@{ allowed = $true; reason = 'Fixture: recoverable isolation, not disk-space reclamation.'; files = @([pscustomobject]@{ name = 'PAD61338.PAZ'; bytes = 123456 }) }
    }
    Set-DashboardRecoveryPlan $recovery
    $Script:UI.RecoveryPageButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($Script:UI.Nav.SelectedIndex -ne 4 -or $Script:DashboardProcess) { throw 'Recovery still opens a console.' }
    $Script:UI.RecoveryAcknowledge.IsChecked = $true
    Update-DashboardRecoveryChoice
    if ($Script:UI.RecoveryApplyButton.IsEnabled -or $Script:UI.RecoveryEvidence.Text -notmatch '3444') { throw 'Stale restore was enabled or client evidence missing.' }
    $Script:UI.RecoveryChoice.SelectedIndex = 1
    if ($Script:UI.RecoveryAcknowledge.IsChecked -or $Script:UI.RecoveryApplyButton.IsEnabled) { throw 'Changing operation reused acknowledgement.' }
    $Script:UI.RecoveryAcknowledge.IsChecked = $true
    Update-DashboardRecoveryChoice
    if (-not $Script:UI.RecoveryApplyButton.IsEnabled) { throw 'Reviewed eligible snapshot cannot be applied.' }
    Set-DashboardDirty
    if ($Script:UI.RecoveryApplyButton.IsEnabled) { throw 'Unsaved edits kept recovery enabled.' }
    Read-DashboardSettings
    if ($Script:RecoveryPlan -or $Script:UI.RecoveryApplyButton.IsEnabled) { throw 'Reload reused old approval.' }
    Set-DashboardRecoveryPlan $recovery
    $Script:UI.RecoveryChoice.SelectedIndex = 2
    if ($Script:UI.RecoveryFiles.Text -notmatch 'PAD61338.PAZ') { throw 'Exact move list missing.' }
    Set-DashboardBusy $true
    if ($Script:UI.RecoveryPanel.IsEnabled) { throw 'Busy recovery page accepts input.' }
    Set-DashboardBusy $false
    $recovery.targetPaz = 'different target'
    $rejected = $false
    try { Set-DashboardRecoveryPlan $recovery } catch { $rejected = $true }
    if (-not $rejected -or $Script:RecoveryPlan -or $Script:UI.RecoveryApplyButton.IsEnabled) { throw 'Cross-target recovery result was accepted.' }
    $recovery.targetPaz = $Script:Config.pazFolder
    Set-DashboardRecoveryPlan $recovery
    $Script:UI.RecoveryChoice.SelectedIndex = 0
    Write-Host 'PASS: native recovery navigation, stale-client refusal, per-action acknowledgement, dirty/busy locking and target isolation.'

    $graphics = [pscustomobject]@{
        profile = 'GameOption_Remastered_1080p.patch'; description = 'Fixture Remastered'; target = 'C:\fixture\GameOption.txt'; token = ('b' * 64)
        sourceBytes = 2707; changed = @('width', 'height', 'dof'); preservedLines = 110; canApply = $true
        nvidia = [pscustomobject]@{ bundledAvailable = $true; inspectorAvailable = $true }
    }
    Set-DashboardCombo $Script:UI.GraphicsProfile $Script:GraphicsProfiles $graphics.profile
    Set-DashboardGraphicsPlan $graphics
    $Script:UI.GraphicsPageButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($Script:UI.Nav.SelectedIndex -ne 5 -or $Script:DashboardProcess) { throw 'Graphics still opens a console.' }
    $Script:UI.GraphicsAcknowledge.IsChecked = $true
    Update-DashboardGraphicsChoice
    if (-not $Script:UI.GraphicsApplyButton.IsEnabled) { throw 'Reviewed graphics profile cannot be applied.' }
    $Script:UI.GraphicsProfile.SelectedIndex = 1
    if ($Script:UI.GraphicsAcknowledge.IsChecked -or $Script:UI.GraphicsApplyButton.IsEnabled) { throw 'Changing graphics profile reused acknowledgement.' }
    Set-DashboardCombo $Script:UI.GraphicsProfile $Script:GraphicsProfiles $graphics.profile
    Set-DashboardGraphicsPlan $graphics
    $Script:UI.GraphicsAcknowledge.IsChecked = $true
    Update-DashboardGraphicsChoice
    Set-DashboardDirty
    if ($Script:UI.GraphicsApplyButton.IsEnabled) { throw 'Unsaved edits kept graphics apply enabled.' }
    Read-DashboardSettings
    if ($Script:GraphicsPlan -or $Script:UI.GraphicsApplyButton.IsEnabled) { throw 'Reload reused old graphics approval.' }
    Set-DashboardGraphicsPlan $graphics
    Set-DashboardBusy $true
    if ($Script:UI.GraphicsPanel.IsEnabled) { throw 'Busy graphics page accepts input.' }
    Set-DashboardBusy $false
    Write-Host 'PASS: native graphics navigation, profile acknowledgement, dirty/busy locking and reset-on-reload.'

    if ($CaptureDir) {
        $null = New-Item -ItemType Directory -Path $CaptureDir -Force
        $Script:UI.BuildLabel.Text = 'UI test fixture / no game writes'
        foreach ($captureTheme in @('Dark', 'Night', 'Light')) {
        Set-DashboardTheme $captureTheme
        Set-DashboardCombo $Script:UI.ThemeBox ([ordered]@{ Dark='Dark'; Night='Night'; Light='Light' }) $captureTheme
        foreach ($size in @(@(1120, 820), @(940, 680))) {
            $detailCapture = 0
            foreach ($index in @(0, 1, 2, 3, 4, 5, 6, 7, 3, 3)) {
                $Script:UI.Nav.SelectedIndex = $index
                if ($index -eq 3) { $Script:UI.DetailTabs.SelectedIndex = $detailCapture; $detailCapture++ }
                $root = $Script:DashboardWindow.Content
                $root.Background = $Script:DashboardWindow.Background
                $root.Measure([Windows.Size]::new($size[0], $size[1]))
                $root.Arrange([Windows.Rect]::new(0, 0, $size[0], $size[1]))
                $root.UpdateLayout()
                $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($size[0], $size[1], 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
                $bitmap.Render($root)
                $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
                $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
                $suffix = if ($index -eq 3 -and $Script:UI.DetailTabs.SelectedIndex -gt 0) { '-' + $Script:UI.DetailTabs.SelectedIndex } else { '' }
                $path = Join-Path $CaptureDir ("$captureTheme-$($Script:UI.Nav.SelectedItem.Tag)$suffix-$($size[0]).png")
                $stream = [IO.File]::Create($path)
                try { $encoder.Save($stream) } finally { $stream.Dispose() }
            }
            $Script:UI.DetailTabs.SelectedIndex = 0
        }
        }
        Write-Host "Rendered all eight pages in three themes at both supported test sizes: $CaptureDir"
    }
    [IO.File]::WriteAllText($settings, '{broken')
    $rejected = $false
    try { Load-Config } catch { $rejected = $true }
    if (-not $rejected -or [IO.File]::ReadAllText($settings) -ne '{broken') { throw 'Malformed settings were replaced with defaults.' }
    Write-Host 'PASS: unreadable settings remain untouched.'
    $bindingListener.Flush()
    if ($bindingLog.ToString()) { throw ('WPF binding diagnostics: ' + $bindingLog.ToString()) }
    Write-Host 'PASS: no WPF binding warnings/errors.'
    $Script:DashboardDirty = $false
    $Script:DashboardWindow.Close()
} finally {
    $bindingSource.Listeners.Remove($bindingListener)
    $bindingSource.Switch.Level = $previousTraceLevel
    $bindingListener.Dispose()
    $bindingLog.Dispose()
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if ($resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and $resolved -match 'bdo-dashboard-test-[0-9a-f]{32}$') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
