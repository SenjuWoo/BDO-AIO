#Requires -Version 5.1
param([string]$ConfigFile, [string]$PythonPath, [switch]$NoShow)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
. (Join-Path $PSScriptRoot 'bdo_aio.ps1') -ConfigFile $ConfigFile -PythonPath $PythonPath
$Script:DashboardPythonOverride = $Script:PythonExe

$Script:UI = @{}
$Script:BodyInputs = [ordered]@{}
$Script:PubicInputs = [ordered]@{}
$Script:FemaleMeshInputs = [ordered]@{}
$Script:MaleMeshInputs = [ordered]@{}
$Script:DetailEdits = @{}
$Script:RecoveryPlan = $null
$Script:GraphicsPlan = $null
$Script:DashboardLoading = $true
$Script:DashboardDirty = $false
$Script:DashboardProcess = $null
$Script:DashboardScan = $null
$Script:DashboardScanHandle = $null
$Script:DashboardScanPending = $false
$Script:DashboardScanTarget = ''
$Script:DashboardInvalidInput = $null
$Script:DashboardInvalidPage = 0
$Script:DashboardResult = $null
$Script:DashboardClock = $null
$Script:DashboardActionName = ''
$Script:DashboardActions = @()
$Script:DashboardPages = [ordered]@{
    Overview = @('Overview', 'A clear path from saved choices to a verified patch.')
    Choices = @('Mod choices', 'Set up your next apply. Saving does not modify the game.')
    Body = @('Body limits', 'Twelve independent axes. Vanilla defaults stay intact.')
    Details = @('Detailed editor', 'Class-specific styles and meshes. All saved here, without a console.')
    Recovery = @('Recovery & updates', 'Know what changes. Keep a way back.')
    Graphics = @('Graphics & performance', 'Apply known GameOption profiles and keep driver tools explicit.')
    Tools = @('Tools', 'Individual steps and existing utilities.')
    Activity = @('Activity', 'Real output, elapsed time, and verification results.')
}
[xml]$dashboardXaml = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ui\dashboard.xaml') -Raw
$reader = New-Object Xml.XmlNodeReader $dashboardXaml
try { $Script:DashboardWindow = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
foreach ($attribute in $dashboardXaml.SelectNodes('//@*[local-name()="Name"]')) {
    $control = $Script:DashboardWindow.FindName($attribute.Value)
    if ($control) { $Script:UI[$attribute.Value] = $control }
}
$Script:UI.BuildLabel.Text = $Script:Version + ' / dashboard preview'

function Set-DashboardMessage([string]$Message, [switch]$IsError) {
    $Script:UI.SaveState.Text = $Message
    $Script:UI.SaveState.Foreground = if ($IsError) { '#993B31' } else { '#586162' }
    if ($IsError) {
        $peer = [Windows.Automation.Peers.UIElementAutomationPeer]::FromElement($Script:UI.SaveState)
        if (-not $peer) { $peer = [Windows.Automation.Peers.UIElementAutomationPeer]::CreatePeerForElement($Script:UI.SaveState) }
        if ($peer) { $peer.RaiseAutomationEvent([Windows.Automation.Peers.AutomationEvents]::LiveRegionChanged) }
    }
}
function Set-DashboardDirty {
    if ($Script:DashboardLoading) { return }
    $Script:DashboardDirty = $true
    Update-DashboardRecoveryChoice
    Update-DashboardGraphicsChoice
    Set-DashboardMessage 'Unsaved choices. Nothing applied.'
}
function Show-DashboardPage([string]$Page) {
    foreach ($name in $Script:DashboardPages.Keys) {
        $Script:UI[($name + 'Panel')].Visibility = if ($name -eq $Page) { 'Visible' } else { 'Collapsed' }
    }
    $Script:UI.PageTitle.Text = $Script:DashboardPages[$Page][0]
    $Script:UI.PageSubtitle.Text = $Script:DashboardPages[$Page][1]
    $Script:UI.PageScroll.ScrollToTop()
}
function Set-DashboardCombo($Control, [System.Collections.IDictionary]$Values, [string]$Selected) {
    $Control.Items.Clear()
    foreach ($key in $Values.Keys) {
        $item = New-Object Windows.Controls.ComboBoxItem
        $item.Content = $Values[$key]
        $item.Tag = $key
        $null = $Control.Items.Add($item)
        if ($key -eq $Selected) { $Control.SelectedItem = $item }
    }
}
function Set-DashboardBodyValues([System.Collections.IDictionary]$Values) {
    foreach ($axis in $Script:BodyInputs.Keys) {
        $Script:BodyInputs[$axis].Text = if ($Values.Contains($axis)) { ([double]$Values[$axis]).ToString('0.##', [Globalization.CultureInfo]::InvariantCulture) } else { '' }
    }
}
function Read-DashboardSettings {
    $Script:DashboardLoading = $true
    try {
        Load-Config
        $Script:PythonExe = if ($Script:Config.PSObject.Properties['pythonPath'] -and $Script:Config.pythonPath) { [string]$Script:Config.pythonPath } else { $Script:DashboardPythonOverride }
        $Script:UI.PazPath.Text = [string]$Script:Config.pazFolder
        Set-DashboardCombo $Script:UI.GenderBox $Script:GenderMap $Script:Config.gender
        Set-DashboardCombo $Script:UI.ArmorBox $Script:ArmorMap $Script:Config.armor
        Set-DashboardCombo $Script:UI.CensorshipBox ([ordered]@{ off = 'Off'; minimal = 'Minimal'; medium = 'Medium'; high = 'High'; expanded = 'Expanded (scans the full meta)' }) $Script:Config.censorshipTier
        $Script:UI.XyzwCheck.IsChecked = [bool]$Script:Config.xyzwCollections
        foreach ($key in @('hideGloves', 'hideBoots', 'hideHelmets', 'hideWeapons', 'hideStockings')) { $Script:UI[$key].IsChecked = [bool]$Script:Config.$key }
        Set-DashboardBodyValues (Get-BodySizeSpec)
        $Script:UI.SlotScope.Text = 'Limit the equipment toggles to specific classes, or leave the filter empty.'
        $Script:UI.SlotClasses.Text = [string]$Script:Config.slotHideClasses
        $pubic = Get-PubicStylesArg
        $Script:UI.AdvancedSummary.Text = 'Saved detailed choices: pubic hair ' + $(if ($pubic) { $pubic } else { 'off' }) + '; female 3D mesh ' + $(if ($Script:Config.female3dVagina) { 'on' } else { 'off' }) + '; male mesh ' + $Script:Config.malePenisMode + '.'
        $Script:UI.ChoicesSummary.Text = (Get-GenderLabel $Script:Config.gender) + ' / ' + (Get-ArmorLabel $Script:Config.armor) + ' / XYZW ' + $(if ($Script:Config.xyzwCollections) { 'on' } else { 'off' })
        Read-DashboardDetails
        $Script:DashboardDirty = $false
        Reset-DashboardRecovery
        Reset-DashboardGraphics
        Set-DashboardMessage 'Settings loaded. Nothing applied.'
    } finally { $Script:DashboardLoading = $false }
}
function Get-DashboardEditedConfig {
    $Script:DashboardInvalidInput = $null
    # Clone first: a failed field must not partially change the in-memory settings.
    $edited = $Script:Config | ConvertTo-Json -Depth 32 | ConvertFrom-Json
    $paz = $Script:UI.PazPath.Text.Trim().Trim('"')
    if ($paz -and -not (Test-IsPazFolder $paz)) {
        $Script:DashboardInvalidInput = $Script:UI.PazPath
        $Script:DashboardInvalidPage = 0
        throw 'Choose a PAZ folder containing pad00000.meta.'
    }
    foreach ($name in @('GenderBox', 'ArmorBox', 'CensorshipBox')) {
        if (-not $Script:UI[$name].SelectedItem) {
            $Script:DashboardInvalidInput = $Script:UI[$name]
            $Script:DashboardInvalidPage = 1
            throw 'Select valid gender, armor and censorship options.'
        }
    }
    $edited.pazFolder = $paz
    $edited.gender = [string]$Script:UI.GenderBox.SelectedItem.Tag
    $edited.armor = [string]$Script:UI.ArmorBox.SelectedItem.Tag
    $edited.censorshipTier = [string]$Script:UI.CensorshipBox.SelectedItem.Tag
    $edited.xyzwCollections = [bool]$Script:UI.XyzwCheck.IsChecked
    foreach ($key in @('hideGloves', 'hideBoots', 'hideHelmets', 'hideWeapons', 'hideStockings')) { $edited.$key = [bool]$Script:UI[$key].IsChecked }
    $values = [ordered]@{}
    foreach ($axis in $Script:BodyInputs.Keys) {
        $raw = $Script:BodyInputs[$axis].Text.Trim()
        if (-not $raw) { continue }
        $value = 0.0
        if (-not [double]::TryParse($raw, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or [double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -lt 1 -or $value -gt 99) {
            $Script:DashboardInvalidInput = $Script:BodyInputs[$axis]
            $Script:DashboardInvalidPage = 2
            throw ("$axis must be a number from 1 to 99, using a decimal point.")
        }
        $values[$axis] = $value
    }
    if ($values.Count -eq 0) {
        $Script:DashboardInvalidInput = $Script:UI.RecommendedButton
        $Script:DashboardInvalidPage = 2
        throw 'Keep at least one body axis, or choose Use recommended.'
    }
    $edited.bodySizeParts = ConvertTo-BodySizeSpecString $values
    $edited.bodySizePreset = if ($edited.bodySizeParts -eq $Script:BodySizeRecommendedSpec) { 'recommended' } else { 'custom' }
    $edited.bodySizeSchema = $Script:BodySizeSchema
    $filter = $Script:UI.SlotClasses.Text.Trim()
    if ($filter -and $filter -notmatch '^[a-zA-Z][a-zA-Z0-9]*(\s*,\s*[a-zA-Z][a-zA-Z0-9]*)*$') {
        $Script:DashboardInvalidInput = $Script:UI.SlotClasses
        $Script:DashboardInvalidPage = 1
        throw 'Use comma-separated class prefixes, for example pew,pdw. Leave blank for all selected-gender classes.'
    }
    $edited.slotHideClasses = $filter
    Save-DashboardDetails $edited
    return $edited
}
function Set-DashboardDetailEdited([string]$Key) {
    if ($Script:DashboardLoading) { return }
    $Script:DetailEdits[$Key] = $true
    Set-DashboardDirty
}
function Read-DashboardDetails {
    $map = Get-PubicStyleMap
    foreach ($prefix in $Script:PubicInputs.Keys) {
        Set-DashboardCombo $Script:PubicInputs[$prefix] $Script:PubicHairStyles $(if ($map.Contains($prefix)) { $map[$prefix] } else { 'none' })
    }
    $shared = @($Script:SharedAtlasPrefixes | Where-Object { $map.Contains($_) })
    $styles = @($shared | ForEach-Object { $map[$_] } | Select-Object -Unique)
    $choices = [ordered]@{}
    $selection = 'none'
    $Script:UI.PubicLegacyNotice.Text = ''
    if ($shared.Count -eq $Script:SharedAtlasPrefixes.Count -and $styles.Count -eq 1) { $selection = $styles[0] }
    elseif ($shared.Count) {
        $selection = 'keep'
        $choices['keep'] = 'Keep saved mixed / partial selection'
        $Script:UI.PubicLegacyNotice.Text = 'Your saved shared-texture selection is partial or mixed. It is preserved until you choose a group style; these classes cannot display independent styles.'
    }
    foreach ($key in $Script:PubicHairStyles.Keys) { $choices[$key] = $Script:PubicHairStyles[$key] }
    Set-DashboardCombo $Script:UI.SharedPubicBox $choices $selection
    $Script:UI.SharedPubicHelp.Text = 'One style affects all 13: ' + (($Script:SharedAtlasPrefixes | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ') + '.'
    $Script:UI.FemaleMeshEnabled.IsChecked = [bool]$Script:Config.female3dVagina
    $selected = @(([string]$Script:Config.genitalFemaleClasses) -split '[,;]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($prefix in $Script:FemaleMeshInputs.Keys) { $Script:FemaleMeshInputs[$prefix].IsChecked = (-not $selected.Count -or $prefix -in $selected) }
    Set-DashboardCombo $Script:UI.MaleModeBox ([ordered]@{ none = 'Off'; normal = 'Normal for all six classes'; hard = 'Erect for all six classes'; perclass = 'Choose per class' }) $Script:Config.malePenisMode
    foreach ($key in $Script:MaleMeshInputs.Keys) { Set-DashboardCombo $Script:MaleMeshInputs[$key] ([ordered]@{ none = 'Off'; normal = 'Normal'; hard = 'Erect' }) $Script:Config.$key }
    $Script:UI.MaleMeshFields.IsEnabled = ($Script:Config.malePenisMode -eq 'perclass')
    $Script:UI.FemaleMeshFields.IsEnabled = [bool]$Script:UI.FemaleMeshEnabled.IsChecked
    $Script:UI.FemaleAllButton.IsEnabled = [bool]$Script:UI.FemaleMeshEnabled.IsChecked
    $Script:DetailEdits = @{}
}
function Save-DashboardDetails($Edited) {
    # Only fields explicitly edited here are rewritten. Legacy mixed selections and
    # fields introduced by other versions survive unrelated Save operations.
    if (@($Script:DetailEdits.Keys | Where-Object { $_ -like 'pubic:*' }).Count) {
        $map = Get-PubicStyleMap
        if ($Script:DetailEdits.ContainsKey('pubic:clear')) { $map.Clear() }
        foreach ($prefix in $Script:PubicInputs.Keys) {
            if (-not $Script:DetailEdits.ContainsKey('pubic:' + $prefix)) { continue }
            $map.Remove($prefix)
            $style = [string]$Script:PubicInputs[$prefix].SelectedItem.Tag
            if ($style -ne 'none') { $map[$prefix] = $style }
        }
        if ($Script:DetailEdits.ContainsKey('pubic:shared')) {
            $style = [string]$Script:UI.SharedPubicBox.SelectedItem.Tag
            if ($style -ne 'keep') {
                foreach ($prefix in $Script:SharedAtlasPrefixes) {
                    $map.Remove($prefix)
                    if ($style -ne 'none') { $map[$prefix] = $style }
                }
            }
        }
        $Edited.pubicHairStyles = (($map.Keys | ForEach-Object { '{0}={1}' -f $_, $map[$_] }) -join ',')
        $Edited.pubicHairClasses = $map.Keys -join ','
        $Edited.pubicHairStyle = if ($map.Count) { @($map.Values)[0] } else { 'none' }
    }
    if ($Script:DetailEdits.ContainsKey('female')) {
        $selected = @($Script:FemaleMeshInputs.Keys | Where-Object { $Script:FemaleMeshInputs[$_].IsChecked })
        if ($Script:UI.FemaleMeshEnabled.IsChecked -and -not $selected.Count) {
            $Script:DashboardInvalidInput = $Script:UI.FemaleAllButton
            $Script:DashboardInvalidPage = 3
            $Script:UI.DetailTabs.SelectedIndex = 1
            throw 'Select at least one female mesh class, or switch female meshes off.'
        }
        $Edited.female3dVagina = [bool]$Script:UI.FemaleMeshEnabled.IsChecked
        if ($selected.Count) { $Edited.genitalFemaleClasses = if ($selected.Count -eq $Script:GenitalFemalePrefixes.Count) { '' } else { $selected -join ',' } }
        $Edited.genitalReuse = $false
    }
    if ($Script:DetailEdits.ContainsKey('male')) {
        $Edited.malePenisMode = [string]$Script:UI.MaleModeBox.SelectedItem.Tag
        foreach ($key in $Script:MaleMeshInputs.Keys) { $Edited.$key = [string]$Script:MaleMeshInputs[$key].SelectedItem.Tag }
    }
}
function Set-DashboardPubicPreset([switch]$Clear) {
    $Script:DetailEdits['pubic:clear'] = $true
    foreach ($prefix in $Script:PubicInputs.Keys) {
        $style = if (-not $Clear -and $Script:PubicImmersivePreset.Contains($prefix)) { $Script:PubicImmersivePreset[$prefix] } else { 'none' }
        $Script:PubicInputs[$prefix].SelectedItem = @($Script:PubicInputs[$prefix].Items | Where-Object Tag -eq $style)[0]
        $Script:DetailEdits['pubic:' + $prefix] = $true
    }
    $Script:UI.SharedPubicBox.SelectedItem = @($Script:UI.SharedPubicBox.Items | Where-Object Tag -eq 'none')[0]
    $Script:DetailEdits['pubic:shared'] = $true
    $Script:UI.PubicLegacyNotice.Text = ''
    Set-DashboardDirty
}
function Save-DashboardSettings {
    $Script:DashboardInvalidInput = $null
    $old = $Script:Config
    $mutex = New-Object Threading.Mutex($false, 'Local\BDO-AIO-PatchOperation')
    $locked = $false
    try {
        try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { throw 'A tool session is open. Finish or close it before saving settings.' }
        $Script:Config = Get-DashboardEditedConfig
        Save-Config
        Read-DashboardSettings
        Set-DashboardMessage 'Settings saved. Apply them when ready.'
        return $true
    } catch {
        $Script:Config = $old
        Set-DashboardMessage $_.Exception.Message -IsError
        if ($Script:DashboardInvalidInput) {
            $Script:UI.Nav.SelectedIndex = $Script:DashboardInvalidPage
            $Script:DashboardInvalidInput.BringIntoView()
            $null = $Script:DashboardInvalidInput.Focus()
        }
        return $false
    } finally {
        if ($locked) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}
function Update-DashboardStatus($Report) {
    $meta = $Report.meta
    $Script:UI.StatusTitle.Text = switch ([string]$meta.state) {
        'MODDED' { 'Meta modified' }
        'RESTORED' { 'Meta matches reference' }
        'STALE_BACKUP' { 'Vanilla backup needs attention' }
        default { 'Meta state is unknown' }
    }
    $Script:UI.StatusDetail.Text = $meta.detail
    $Script:UI.StatusUpdated.Text = 'Scanned ' + ([DateTime]::Parse($Report.scanned_at).ToLocalTime().ToString('HH:mm:ss')) + '. Staging is separate from what is active in game.'
    $Script:UI.VersionValue.Text = if ($meta.PSObject.Properties['meta_version'] -and $meta.meta_version) { [string]$meta.meta_version } else { 'Unknown' }
    $Script:UI.BackupValue.Text = if ($meta.state -eq 'STALE_BACKUP') { 'Different client version' } elseif ($meta.PSObject.Properties['version_matches'] -and $meta.version_matches) { 'Same client version' } else { 'Unavailable or unreadable' }
    $Script:UI.FilesValue.Text = '{0:N0} files (not activation proof)' -f $Report.files_to_patch.total_files
}
function Clear-DashboardStatus {
    foreach ($name in @('VersionValue', 'BackupValue', 'FilesValue')) { $Script:UI[$name].Text = 'Unknown' }
    $Script:UI.StatusUpdated.Text = 'Not verified'
}
function Start-DashboardScan {
    Clear-DashboardStatus
    $Script:UI.StatusTitle.Text = 'Checking saved game location'
    $Script:UI.StatusDetail.Text = 'Reading the meta and staged-file inventory. No game files are changed by this scan.'
    if ($Script:DashboardScan -or $Script:DashboardProcess) { $Script:DashboardScanPending = $true; return }
    $Script:DashboardScanPending = $false
    $Script:DashboardScanTarget = [string]$Script:Config.pazFolder
    $Script:UI.RefreshButton.IsEnabled = $false
    $Script:UI.StatusUpdated.Text = 'Checking saved game location...'
    $Script:DashboardScan = [PowerShell]::Create()
    # Read-only work runs away from WPF's dispatcher. No auto-installs or PAZ writes.
    $null = $Script:DashboardScan.AddScript({
        param($Engine, $PazFolder, $ConfiguredPython)
        . $Engine
        $Script:Config = [pscustomobject]@{ pazFolder = $PazFolder; pythonPath = $ConfiguredPython }
        $python = Ensure-Python -ProbeOnly
        $report = if ($python -and (Test-IsPazFolder $Script:Config.pazFolder)) { Get-PazStatusReport -PazFolder $Script:Config.pazFolder } else { $null }
        [pscustomobject]@{ report = $report; python = $python; pythonPath = $Script:PythonExe; pack = (Test-PackReady).Ok; toolkit = (Test-BdoToolkitInstalled); paz = [string]$Script:Config.pazFolder }
    }).AddArgument((Join-Path $Script:Root 'bdo_aio.ps1')).AddArgument($Script:DashboardScanTarget).AddArgument($Script:PythonExe)
    $Script:DashboardScanHandle = $Script:DashboardScan.BeginInvoke()
}
function Read-DashboardTimings {
    $folder = Join-Path $Script:Root 'logs'
    if (-not (Test-Path -LiteralPath $folder)) { return }
    $reports = @(Get-ChildItem -LiteralPath $folder -Filter 'meta-inject-*.json' -File | Where-Object { $_.Name -notlike '*-stage.json' } | Sort-Object LastWriteTime -Descending | Select-Object -First 20)
    foreach ($file in $reports) {
        try {
            $report = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            if ($report.targetPaz -ne $Script:Config.pazFolder) { continue }
            $parts = @('Last recorded injection: ' + $report.state)
            foreach ($pair in @(@('backupMs', 'Backup'), @('stageBuildMs', 'Stage'), @('injectorMs', 'Injector'), @('verifyMs', 'Verify'))) {
                if ($null -ne $report.($pair[0])) { $parts += ('{0} {1:N1}s' -f $pair[1], ($report.($pair[0]) / 1000)) }
            }
            $Script:UI.RunTiming.Text = $parts -join ' / '
            return
        } catch { continue }
    }
}
function Set-DashboardBusy([bool]$Busy) {
    foreach ($button in $Script:DashboardActions) { $button.IsEnabled = -not $Busy }
    foreach ($name in @('SaveButton', 'ReloadButton', 'BrowseButton', 'PythonButton', 'PazPath', 'ChoicesPanel', 'BodyPanel', 'DetailsPanel', 'RecoveryPanel', 'GraphicsPanel', 'RefreshButton')) { $Script:UI[$name].IsEnabled = -not $Busy }
    $Script:UI.OperationProgress.IsIndeterminate = $Busy
    $Script:UI.OperationProgress.Visibility = if ($Busy) { 'Visible' } else { 'Collapsed' }
    Update-DashboardRecoveryChoice
    Update-DashboardGraphicsChoice
}
function Reset-DashboardRecovery {
    $Script:RecoveryPlan = $null
    $Script:UI.RecoveryAcknowledge.IsChecked = $false
    $Script:UI.RecoveryEvidence.Text = 'No current recovery preview. Check options before making changes.'
    $Script:UI.RecoveryTitle.Text = 'Review before changing anything'
    Update-DashboardRecoveryChoice
}
function Update-DashboardRecoveryChoice {
    if (-not $Script:UI.RecoveryChoice.SelectedItem) { return }
    $key = [string]$Script:UI.RecoveryChoice.SelectedItem.Tag
    $titles = @{ restore = 'Restore meta from backup'; snapshot = 'Create current-client reference'; cleanup = 'Move listed archives to recovery folder' }
    $Script:UI.RecoveryApplyButton.Content = $titles[$key]
    $Script:UI.RecoveryFiles.Visibility = 'Collapsed'
    $Script:UI.RecoveryAcknowledgementText.Text = switch ($key) {
        restore { 'I will reapply body limits before loading characters saved above stock limits. Local Customization presets will be copied first if present; a failed copy stops recovery.' }
        snapshot { 'The game launcher has finished patching / repair. I want this current meta recorded as my new reference, with the old reference retained.' }
        cleanup { 'I reviewed the exact file list. These files will be moved, not deleted; this does not free disk space.' }
    }
    $Script:UI.RecoveryChanges.Text = switch ($key) {
        restore { 'Changes only pad00000.meta. Saves its current bytes under PAZ/BDO_AIO_RECOVERY first. No PAZ archives, staged files or saved settings are deleted.' }
        snapshot { 'Replaces the AIO reference meta and its checksum record, retaining both previous files. Does not change the live meta, archives, staging or settings.' }
        cleanup { 'Moves only unreferenced archives above both the highest live reference and the contiguous game range into PAZ/BDO_AIO_RECOVERY. The live meta and staging stay untouched.' }
    }
    $allowed = $false
    if ($Script:RecoveryPlan -and $Script:RecoveryPlan.targetPaz -eq $Script:Config.pazFolder) {
        $allowed = [bool]$Script:RecoveryPlan.$key.allowed
        $Script:UI.RecoveryReason.Text = $Script:RecoveryPlan.$key.reason
        if ($key -eq 'cleanup') {
            $Script:UI.RecoveryFiles.Text = if (@($Script:RecoveryPlan.cleanup.files).Count) {
                ($Script:RecoveryPlan.cleanup.files | ForEach-Object { '{0}  ({1:N1} MB)' -f $_.name, ($_.bytes / 1MB) }) -join [Environment]::NewLine
            } else { 'No eligible files. Nothing will be moved.' }
            $Script:UI.RecoveryFiles.Visibility = 'Visible'
        }
    } else { $Script:UI.RecoveryReason.Text = 'Check recovery options to build a fresh preview for the saved PAZ folder.' }
    if ($Script:DashboardDirty) { $Script:UI.RecoveryReason.Text = 'Save or reload your edited settings, then check recovery options again.'; $allowed = $false }
    $Script:UI.RecoveryAcknowledge.IsEnabled = $allowed -and -not [bool]$Script:DashboardProcess
    $Script:UI.RecoveryApplyButton.IsEnabled = $allowed -and [bool]$Script:UI.RecoveryAcknowledge.IsChecked -and -not [bool]$Script:DashboardProcess
}
function Set-DashboardRecoveryPlan($Plan) {
    if ($Plan.targetPaz -ne $Script:Config.pazFolder) { Reset-DashboardRecovery; throw 'Recovery result belongs to a different PAZ folder. Check again.' }
    $Script:RecoveryPlan = $Plan
    $Script:UI.RecoveryTitle.Text = 'Recovery preview ready'
    $backup = if ($Plan.backup) { $Plan.backup.name + ' / client ' + $Plan.backup.version } else { 'No backup found' }
    $valid = if ($Plan.current.valid) { 'Archive bounds passed' } else { 'Archive check failed or unreadable' }
    $Script:UI.RecoveryEvidence.Text = 'Live client: ' + $Plan.current.version + ' / ' + $valid + [Environment]::NewLine + 'Reference: ' + $backup + [Environment]::NewLine + 'Checked: ' + ([DateTime]::Parse($Plan.scannedAt).ToLocalTime().ToString('g'))
    $Script:UI.RecoveryAcknowledge.IsChecked = $false
    Update-DashboardRecoveryChoice
}
function Update-DashboardGraphicsToolStatus {
    $nip = Test-NipReady
    $npi = Find-NvidiaProfileInspector
    $Script:UI.GraphicsNvidiaStatus.Text = if ($npi) {
        'NVIDIA Profile Inspector: available. Import remains in the official NVIDIA tool.'
    } else {
        'NVIDIA Profile Inspector: not found. Install it or choose its path in the classic NVIDIA action.'
    }
    $Script:UI.GraphicsNvidiaButton.IsEnabled = [bool]$npi -and -not [bool]$Script:DashboardProcess
    $Script:UI.GraphicsNvidiaReadmeButton.IsEnabled = [bool]$nip.Ok -and -not [bool]$Script:DashboardProcess
}
function Reset-DashboardGraphics {
    $Script:GraphicsPlan = $null
    $Script:UI.GraphicsAcknowledge.IsChecked = $false
    $Script:UI.GraphicsTitle.Text = 'Preview before changing GameOption.txt'
    $Script:UI.GraphicsEvidence.Text = 'Choose a profile and preview it. Preview reads the current file and makes no changes.'
    $Script:UI.GraphicsPreview.Text = 'No profile preview yet.'
    Update-DashboardGraphicsToolStatus
    Update-DashboardGraphicsChoice
}
function Update-DashboardGraphicsChoice {
    if (-not $Script:UI.GraphicsProfile.SelectedItem) { return }
    $key = [string]$Script:UI.GraphicsProfile.SelectedItem.Tag
    $allowed = $false
    if ($Script:GraphicsPlan -and $Script:GraphicsPlan.profile -eq $key) {
        $changes = @($Script:GraphicsPlan.changed)
        $Script:UI.GraphicsEvidence.Text = 'Target: ' + $Script:GraphicsPlan.target + [Environment]::NewLine + 'Profile: ' + $Script:GraphicsPlan.description + [Environment]::NewLine + 'Current file: ' + $Script:GraphicsPlan.sourceBytes.ToString('N0') + ' bytes'
        $Script:UI.GraphicsPreview.Text = if ($changes.Count) {
            ('Keys that will change (' + $changes.Count + '):' + [Environment]::NewLine + ($changes -join [Environment]::NewLine) + [Environment]::NewLine + [Environment]::NewLine + 'All other lines and unknown/current settings stay unchanged.')
        } else { 'This profile already matches the current file. No write is needed.' }
        $allowed = [bool]$Script:GraphicsPlan.canApply
    } else {
        $Script:UI.GraphicsEvidence.Text = 'Preview the selected profile against Documents\Black Desert\GameOption.txt before applying it.'
        $Script:UI.GraphicsPreview.Text = 'No profile preview yet.'
    }
    if ($Script:DashboardDirty) {
        $Script:UI.GraphicsEvidence.Text = 'Save or reload your edited choices, then preview the graphics profile again.'
        $allowed = $false
    }
    $Script:UI.GraphicsAcknowledge.IsEnabled = $allowed -and -not [bool]$Script:DashboardProcess
    $Script:UI.GraphicsApplyButton.IsEnabled = $allowed -and [bool]$Script:UI.GraphicsAcknowledge.IsChecked -and -not [bool]$Script:DashboardProcess
}
function Set-DashboardGraphicsPlan($Plan) {
    if (-not $Plan.profile -or -not @($Script:UI.GraphicsProfile.Items | Where-Object Tag -eq $Plan.profile).Count) {
        Reset-DashboardGraphics
        throw 'Graphics result contains an unknown profile.'
    }
    $Script:GraphicsPlan = $Plan
    $Script:UI.GraphicsTitle.Text = if ($Plan.canApply) { 'Graphics preview ready' } else { 'Graphics already match this profile' }
    $Script:UI.GraphicsAcknowledge.IsChecked = $false
    Update-DashboardGraphicsToolStatus
    Update-DashboardGraphicsChoice
}
function Start-DashboardAction([string]$ActionName) {
    if ($Script:DashboardProcess) { return }
    try {
        $nativeRecovery = $ActionName -in @('RecoveryPlan','RecoveryRestore','RecoverySnapshot','RecoveryCleanup')
        $nativeGraphics = $ActionName -in @('GraphicsPlan','GraphicsApply')
        $recoveryToken = ''
        $graphicsToken = ''
        $graphicsProfile = ''
        if ($nativeRecovery -and $ActionName -ne 'RecoveryPlan') {
            $key = $ActionName.Substring(8).ToLowerInvariant()
            if ($Script:UI.RecoveryChoice.SelectedItem.Tag -ne $key) { throw 'Select and acknowledge the matching recovery action first.' }
            if ($Script:DashboardDirty -or -not $Script:RecoveryPlan -or $Script:RecoveryPlan.targetPaz -ne $Script:Config.pazFolder -or -not $Script:RecoveryPlan.$key.allowed -or -not $Script:UI.RecoveryAcknowledge.IsChecked) { throw 'Save settings, review a fresh preview and acknowledge the action first.' }
            $answer = [Windows.MessageBox]::Show($Script:DashboardWindow, $Script:UI.RecoveryApplyButton.Content + [Environment]::NewLine + $Script:RecoveryPlan.targetPaz + [Environment]::NewLine + [Environment]::NewLine + $Script:UI.RecoveryChanges.Text, 'Confirm reviewed recovery', 'OKCancel', 'Warning', 'Cancel')
            if ($answer -ne 'OK') { return }
            $recoveryToken = $Script:RecoveryPlan.token
        }
        if ($nativeGraphics) {
            if (-not $Script:UI.GraphicsProfile.SelectedItem) { throw 'Choose a graphics profile first.' }
            $graphicsProfile = [string]$Script:UI.GraphicsProfile.SelectedItem.Tag
            if ($ActionName -eq 'GraphicsApply') {
                if ($Script:DashboardDirty -or -not $Script:GraphicsPlan -or $Script:GraphicsPlan.profile -ne $graphicsProfile -or -not $Script:GraphicsPlan.canApply -or -not $Script:UI.GraphicsAcknowledge.IsChecked) { throw 'Save settings, review a fresh graphics preview and acknowledge the profile first.' }
                $answer = [Windows.MessageBox]::Show($Script:DashboardWindow, 'Apply ' + $Script:GraphicsPlan.description + '?' + [Environment]::NewLine + [Environment]::NewLine + 'Target: ' + $Script:GraphicsPlan.target + [Environment]::NewLine + 'A complete backup will be created beside the current file. Existing and unknown settings remain in place.', 'Confirm graphics profile', 'OKCancel', 'Question', 'Cancel')
                if ($answer -ne 'OK') { return }
                $graphicsToken = $Script:GraphicsPlan.token
            }
        }
        if ($Script:DashboardDirty) {
            $choice = [Windows.MessageBox]::Show($Script:DashboardWindow, 'Save your edited choices before opening this tool? Yes saves them; No reloads the saved choices; Cancel stays here.', 'Unsaved choices', 'YesNoCancel', 'Question')
            if ($choice -eq 'Cancel') { return }
            if ($choice -eq 'Yes') { if (-not (Save-DashboardSettings)) { return } }
            else { Read-DashboardSettings }
        }
        if (-not (Test-Path -LiteralPath $Script:ConfigPath) -and -not ($nativeRecovery -or $nativeGraphics)) { if (-not (Save-DashboardSettings)) { return } }
        if ($ActionName -in @('Wizard', 'Deploy', 'PartCut', 'Inject', 'Restored', 'VerifyMeta') -and -not (Test-IsPazFolder $Script:Config.pazFolder)) { throw 'Set and save a valid game PAZ folder first.' }
        if ($ActionName -in @('Wizard', 'Deploy', 'PartCut', 'Inject', 'Restored') -and -not (Test-BdoToolsIdle)) { throw 'Close the game, launcher and other patch tools first.' }
        if ($ActionName -eq 'Wizard') {
            $answer = [Windows.MessageBox]::Show($Script:DashboardWindow, 'Apply the saved configuration to this game? This deploys files, generates selected options, then opens PartCutGen and Meta Injector. Follow their console prompts.', 'Apply saved choices', 'OKCancel', 'Question')
            if ($answer -ne 'OK') { return }
        }
        Reset-DashboardRecovery
        Reset-DashboardGraphics
        $folder = Join-Path $Script:Root 'logs'
        $null = New-Item -ItemType Directory -Path $folder -Force
        $Script:DashboardResult = Join-Path $folder ('operation-' + [guid]::NewGuid().ToString('N') + '.json')
        # Encode a script with single-quoted literal arguments: spaces, quotes and
        # PowerShell metacharacters in a selected path never become executable text.
        $command = "& '" + (Join-Path $Script:Root 'bdo_aio.ps1').Replace("'", "''") + "' -Action '" + $ActionName + "' -ConfigFile '" + $Script:ConfigPath.Replace("'", "''") + "' -ResultFile '" + $Script:DashboardResult.Replace("'", "''") + "'"
        if ($Script:PythonExe) { $command += " -PythonPath '" + $Script:PythonExe.Replace("'", "''") + "'" }
        if ($recoveryToken) { $command += " -RecoveryToken '" + $recoveryToken.Replace("'", "''") + "' -RecoveryConfirmed" }
        if ($nativeGraphics) {
            $command += " -GraphicsProfile '" + $graphicsProfile.Replace("'", "''") + "'"
            if ($graphicsToken) { $command += " -GraphicsToken '" + $graphicsToken.Replace("'", "''") + "' -GraphicsConfirmed" }
        }
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        # Native recovery has no console prompts. Other legacy tools remain interactive.
        $launch = @{ FilePath = 'powershell.exe'; ArgumentList = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded); WorkingDirectory = $Script:Root; PassThru = $true }
        if ($nativeRecovery -or $nativeGraphics) { $launch.WindowStyle = 'Hidden' }
        $Script:DashboardProcess = Start-Process @launch
        $Script:DashboardActionName = $ActionName
        $Script:DashboardClock = [Diagnostics.Stopwatch]::StartNew()
        $Script:UI.ActivityText.Text = if ($nativeRecovery) { 'Recovery is running in the background. Do not open the game or launcher until it finishes.' } elseif ($nativeGraphics) { 'Graphics profile is running in the background. Do not open BDO until it finishes.' } else { 'Opening the tool console. Answer any prompts there. External tool output remains in its own window.' }
        $Script:UI.Nav.SelectedIndex = if ($nativeRecovery) { 4 } elseif ($nativeGraphics) { 5 } else { 7 }
        if ($nativeRecovery) { $Script:UI.RecoveryTitle.Text = if ($ActionName -eq 'RecoveryPlan') { 'Checking meta and backup...' } else { 'Applying reviewed recovery...' } }
        if ($nativeGraphics) { $Script:UI.GraphicsTitle.Text = if ($ActionName -eq 'GraphicsPlan') { 'Previewing GameOption...' } else { 'Applying graphics profile...' } }
        Set-DashboardBusy $true
        Set-DashboardMessage $(if ($nativeRecovery) { 'Recovery running. Settings are locked until it finishes.' } elseif ($nativeGraphics) { 'Graphics action running. Settings are locked until it finishes.' } else { 'Tool session is open. Settings are locked until it closes.' })
    } catch {
        Set-DashboardMessage $_.Exception.Message -IsError
        if (-not $Script:DashboardProcess) { Set-DashboardBusy $false }
    }
}
function Update-DashboardTick {
    if ($Script:DashboardScan -and $Script:DashboardScanHandle.IsCompleted) {
        try {
            $rows = @($Script:DashboardScan.EndInvoke($Script:DashboardScanHandle))
            if ($Script:DashboardScan.HadErrors -or -not $rows.Count) { throw ($Script:DashboardScan.Streams.Error | Out-String) }
            $scan = $rows[-1]
            if ($Script:DashboardScanPending -or $scan.paz -ne $Script:Config.pazFolder) {
                $Script:DashboardScanPending = $true
                return
            }
            $Script:PythonExe = $scan.pythonPath
            $Script:UI.ChecksSummary.Text = 'Python: ' + $(if ($scan.python) { 'available' } else { 'not found' }) + ' / Full pack: ' + $(if ($scan.pack) { 'available' } else { 'missing files' }) + ' / BDO Toolkit: ' + $(if ($scan.toolkit) { 'detected' } else { 'not detected' })
            if ($scan.report) { Update-DashboardStatus $scan.report }
            else {
                $Script:UI.StatusTitle.Text = if (-not $scan.paz) { 'Choose your game folder' } else { 'Status unavailable' }
                $Script:UI.StatusDetail.Text = if (-not $scan.paz) { 'Select the PAZ folder containing pad00000.meta, then save your settings.' } else { 'Check the saved PAZ folder and Python installation, then refresh. No game files were changed by this scan.' }
                $Script:UI.StatusUpdated.Text = 'Not verified'
                foreach ($name in @('VersionValue', 'BackupValue', 'FilesValue')) { $Script:UI[$name].Text = 'Unknown' }
            }
        } catch {
            Clear-DashboardStatus
            $Script:UI.StatusTitle.Text = 'Status check failed'
            $Script:UI.StatusDetail.Text = $_.Exception.Message
        } finally {
            $Script:DashboardScan.Dispose()
            $Script:DashboardScan = $null
            $Script:DashboardScanHandle = $null
            $Script:UI.RefreshButton.IsEnabled = -not [bool]$Script:DashboardProcess
            if ($Script:DashboardScanPending -and -not $Script:DashboardProcess) { Start-DashboardScan }
        }
    }
    if (-not $Script:DashboardProcess) { return }
    $Script:UI.OperationLabel.Text = '{0} / {1:N0}s elapsed' -f $Script:DashboardActionName, $Script:DashboardClock.Elapsed.TotalSeconds
    $log = $Script:DashboardResult + '.log'
    if (Test-Path -LiteralPath $log) {
        try {
            $text = (Get-Content -LiteralPath $log -Tail 160 -ErrorAction Stop) -join [Environment]::NewLine
            if ($text -ne $Script:UI.ActivityText.Text) { $Script:UI.ActivityText.Text = $text; $Script:UI.ActivityText.ScrollToEnd() }
        } catch { } # The transcript can briefly be locked while it is opened/closed.
    }
    if (-not $Script:DashboardProcess.HasExited) { return }
    try {
        $Script:DashboardProcess.WaitForExit()
        if (-not (Test-Path -LiteralPath $Script:DashboardResult)) { throw 'The tool window closed without a result report. Its outcome is unknown; verify before continuing.' }
        $result = Get-Content -LiteralPath $Script:DashboardResult -Raw | ConvertFrom-Json
        if ($result.state -eq 'running') { throw 'The tool session was interrupted. Its outcome is unknown; verify before continuing.' }
        $Script:UI.OperationLabel.Text = $Script:DashboardActionName + ' / ' + $result.state + (' / {0:N0}s' -f $Script:DashboardClock.Elapsed.TotalSeconds)
        Read-DashboardSettings
        if ($Script:DashboardActionName -eq 'RecoveryPlan' -and $result.state -eq 'completed') {
            Set-DashboardRecoveryPlan $result.recoveryPlan
        }
        if ($Script:DashboardActionName -eq 'GraphicsPlan' -and $result.state -eq 'completed') {
            Set-DashboardGraphicsPlan $result.graphicsPlan
        }
        if ($result.PSObject.Properties['recoveryResult'] -and $result.state -eq 'completed') {
            $Script:UI.RecoveryOutcome.Text = 'Completed: ' + $result.recoveryResult.operation + '. Retained files: ' + $result.recoveryResult.retainedPath
            if ($result.recoveryResult.presetBackup) { $Script:UI.RecoveryOutcome.Text += [Environment]::NewLine + 'Presets copied to: ' + $result.recoveryResult.presetBackup }
            $Script:UI.RecoveryTitle.Text = 'Recovery completed. Check options again.'
        }
        if ($result.PSObject.Properties['graphicsResult'] -and $result.state -eq 'completed') {
            $Script:UI.GraphicsOutcome.Text = 'Applied ' + $result.graphicsResult.profile + '. Backup: ' + $result.graphicsResult.backup + [Environment]::NewLine + 'Changed keys: ' + (@($result.graphicsResult.changed) -join ', ')
            $Script:UI.GraphicsTitle.Text = 'Graphics profile applied. Preview again to verify current state.'
        }
        if ($result.state -in @('failed', 'stopped')) {
            Set-DashboardMessage $(if ($result.error) { $result.error } else { 'Stopped or cancelled. Check Activity before continuing.' }) -IsError
            if ($Script:DashboardActionName -like 'Recovery*') { $Script:UI.RecoveryTitle.Text = 'Recovery stopped'; $Script:UI.RecoveryOutcome.Text = $(if ($result.error) { $result.error } else { 'No completed recovery result. Review Activity and check options again.' }) }
            if ($Script:DashboardActionName -like 'Graphics*') { $Script:UI.GraphicsTitle.Text = 'Graphics action stopped'; $Script:UI.GraphicsOutcome.Text = $(if ($result.error) { $result.error } else { 'No completed graphics result. Check Activity before continuing.' }) }
        } else { Set-DashboardMessage 'Tool session closed. Check Activity for its result.' }
        Read-DashboardTimings
    } catch {
        Set-DashboardMessage $_.Exception.Message -IsError
        $Script:UI.OperationLabel.Text = 'Outcome unknown - verify before continuing'
        if ($Script:DashboardActionName -like 'Recovery*') {
            Reset-DashboardRecovery
            $Script:UI.RecoveryTitle.Text = 'Recovery result unavailable'
            $Script:UI.RecoveryOutcome.Text = $_.Exception.Message
        }
        if ($Script:DashboardActionName -like 'Graphics*') {
            Reset-DashboardGraphics
            $Script:UI.GraphicsTitle.Text = 'Graphics result unavailable'
            $Script:UI.GraphicsOutcome.Text = $_.Exception.Message
        }
    }
    finally {
        $Script:DashboardProcess.Dispose()
        $Script:DashboardProcess = $null
        $Script:DashboardClock.Stop()
        Set-DashboardBusy $false
        Start-DashboardScan
    }
}

# Body inputs reuse the engine's canonical axis list and values.
$regions = [ordered]@{ breasts = 'Breasts'; thighs = 'Thighs'; butt = 'Butt cheeks'; pelvis = 'Front pelvis / groin'; belly = 'Belly / lower torso' }
foreach ($region in $regions.Keys) {
    $row = New-Object Windows.Controls.Grid
    $row.Margin = '0,0,0,14'
    foreach ($width in @('2*', '*', '*', '*')) {
        $column = New-Object Windows.Controls.ColumnDefinition
        $column.Width = [Windows.GridLengthConverter]::new().ConvertFromString($width)
        $row.ColumnDefinitions.Add($column)
    }
    $title = New-Object Windows.Controls.TextBlock
    $title.Text = $regions[$region]
    $title.FontWeight = 'SemiBold'
    $title.VerticalAlignment = 'Center'
    $title.Margin = '0,18,14,0'
    $null = $row.Children.Add($title)
    foreach ($axis in $Script:BodySizeAxes) {
        if (-not $axis.StartsWith($region + '.')) { continue }
        $letter = $axis.Split('.')[1]
        $group = New-Object Windows.Controls.StackPanel
        $group.Margin = '0,0,12,0'
        [Windows.Controls.Grid]::SetColumn($group, (@('x', 'y', 'z').IndexOf($letter) + 1))
        $input = New-Object Windows.Controls.TextBox
        $input.Tag = $axis
        [Windows.Automation.AutomationProperties]::SetName($input, ($regions[$region] + ' ' + $letter.ToUpperInvariant() + ' maximum'))
        $label = New-Object Windows.Controls.Label
        $label.Content = $letter.ToUpperInvariant() + ' max'
        $label.Target = $input
        $label.Padding = '0,0,0,5'
        $null = $group.Children.Add($label)
        $null = $group.Children.Add($input)
        $null = $row.Children.Add($group)
        $Script:BodyInputs[$axis] = $input
        $input.Add_TextChanged({ Set-DashboardDirty })
    }
    $null = $Script:UI.BodyFields.Children.Add($row)
}
# Small native form rows share labels, focus targets and the same combo styling.
function Add-DashboardStyleRow($Panel, [string]$Label, [string]$Key) {
    $row = New-Object Windows.Controls.Grid
    $row.Margin = '0,0,0,12'
    $left = New-Object Windows.Controls.ColumnDefinition
    $left.Width = [Windows.GridLength]::new(190)
    $row.ColumnDefinitions.Add($left)
    $row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
    $input = New-Object Windows.Controls.ComboBox
    $input.Tag = $Key
    [Windows.Controls.Grid]::SetColumn($input, 1)
    [Windows.Automation.AutomationProperties]::SetName($input, $Label + ' style')
    $labelControl = New-Object Windows.Controls.Label
    $labelControl.Content = $Label
    $labelControl.Target = $input
    $labelControl.VerticalAlignment = 'Center'
    $labelControl.Padding = '0,0,12,0'
    $null = $row.Children.Add($labelControl)
    $null = $row.Children.Add($input)
    $null = $Panel.Children.Add($row)
    return $input
}
foreach ($prefix in $Script:PubicPrivateAtlasPrefixes) {
    $input = Add-DashboardStyleRow $Script:UI.PubicFields $Script:FemaleClasses[$prefix] ('pubic:' + $prefix)
    $Script:PubicInputs[$prefix] = $input
    $input.Add_SelectionChanged({ param($sender, $eventArgs) Set-DashboardDetailEdited ([string]$sender.Tag) })
}
foreach ($prefix in $Script:GenitalFemalePrefixes) {
    $input = New-Object Windows.Controls.CheckBox
    $input.Content = $Script:FemaleClasses[$prefix]
    $input.Margin = '0,0,16,6'
    $input.Add_Click({ Set-DashboardDetailEdited 'female' })
    $Script:FemaleMeshInputs[$prefix] = $input
    $null = $Script:UI.FemaleMeshFields.Children.Add($input)
}
foreach ($name in @('Warrior', 'Berserker', 'Musa', 'Wizard', 'Ninja', 'Striker')) {
    $input = Add-DashboardStyleRow $Script:UI.MaleMeshFields $name ('penis' + $name)
    $Script:MaleMeshInputs[('penis' + $name)] = $input
    $input.Add_SelectionChanged({ Set-DashboardDetailEdited 'male' })
}
$Script:UI.SharedPubicBox.Add_SelectionChanged({ Set-DashboardDetailEdited 'pubic:shared' })
$Script:UI.FemaleMeshEnabled.Add_Click({
    $Script:UI.FemaleMeshFields.IsEnabled = [bool]$Script:UI.FemaleMeshEnabled.IsChecked
    $Script:UI.FemaleAllButton.IsEnabled = [bool]$Script:UI.FemaleMeshEnabled.IsChecked
    Set-DashboardDetailEdited 'female'
})
$Script:UI.FemaleAllButton.Add_Click({ foreach ($input in $Script:FemaleMeshInputs.Values) { $input.IsChecked = $true }; Set-DashboardDetailEdited 'female' })
$Script:UI.MaleModeBox.Add_SelectionChanged({
    $Script:UI.MaleMeshFields.IsEnabled = ($Script:UI.MaleModeBox.SelectedItem -and $Script:UI.MaleModeBox.SelectedItem.Tag -eq 'perclass')
    Set-DashboardDetailEdited 'male'
})
$Script:UI.PubicPresetButton.Add_Click({ Set-DashboardPubicPreset })
$Script:UI.PubicClearButton.Add_Click({ Set-DashboardPubicPreset -Clear })
$Script:UI.PubicPreviewButton.Add_Click({
    try {
        if ($Script:UI.PubicPreview.Visibility -eq 'Visible') { $Script:UI.PubicPreview.Visibility = 'Collapsed'; return }
        $path = Join-Path $Script:PubicHairRoot 'preview.jpg'
        if (-not (Test-Path -LiteralPath $path)) { throw 'Style reference is missing: tools/pubic_hair/preview.jpg' }
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.UriSource = [uri]$path
        $bitmap.EndInit()
        $bitmap.Freeze()
        $Script:UI.PubicPreview.Source = $bitmap
        $Script:UI.PubicPreview.Visibility = 'Visible'
    } catch { Set-DashboardMessage $_.Exception.Message -IsError }
})
$Script:UI.MinimizeButton.Add_Click({ [Windows.SystemCommands]::MinimizeWindow($Script:DashboardWindow) })
$Script:UI.MaximizeButton.Add_Click({
    if ($Script:DashboardWindow.WindowState -eq 'Maximized') { [Windows.SystemCommands]::RestoreWindow($Script:DashboardWindow) }
    else { [Windows.SystemCommands]::MaximizeWindow($Script:DashboardWindow) }
})
$Script:UI.CloseButton.Add_Click({ $Script:DashboardWindow.Close() })
$Script:DashboardWindow.Add_StateChanged({
    $maximized = $Script:DashboardWindow.WindowState -eq 'Maximized'
    $Script:UI.WindowRoot.Margin = if ($maximized) { '7' } else { '0' }
    $Script:UI.MaximizeIcon.Data = [Windows.Media.Geometry]::Parse($(if ($maximized) { 'M 2 0 L 10 0 10 8 M 0 2 L 8 2 8 10 0 10 Z' } else { 'M 0 0 L 10 0 10 10 0 10 Z' }))
    [Windows.Automation.AutomationProperties]::SetName($Script:UI.MaximizeButton, $(if ($maximized) { 'Restore window' } else { 'Maximize' }))
})
$Script:UI.DetailsButton.Add_Click({ $Script:UI.Nav.SelectedIndex = 3 })
$Script:UI.RecoveryPageButton.Add_Click({ $Script:UI.Nav.SelectedIndex = 4 })
$Script:UI.UpdatePageButton.Add_Click({ $Script:UI.Nav.SelectedIndex = 4 })
$Script:UI.GraphicsPageButton.Add_Click({ $Script:UI.Nav.SelectedIndex = 5 })
$Script:UI.GraphicsNvidiaPageButton.Add_Click({ $Script:UI.Nav.SelectedIndex = 5 })
Set-DashboardCombo $Script:UI.RecoveryChoice ([ordered]@{ restore = 'Restore meta from compatible backup'; snapshot = 'Create current-client reference after update'; cleanup = 'Isolate unused high-numbered archives' }) 'restore'
$Script:UI.RecoveryChoice.Add_SelectionChanged({ $Script:UI.RecoveryAcknowledge.IsChecked = $false; Update-DashboardRecoveryChoice })
$Script:UI.RecoveryAcknowledge.Add_Click({ Update-DashboardRecoveryChoice })
$Script:UI.RecoveryCheckButton.Add_Click({ Start-DashboardAction 'RecoveryPlan' })
$Script:UI.RecoveryApplyButton.Add_Click({ Start-DashboardAction ('Recovery' + [string]$Script:UI.RecoveryChoice.SelectedItem.Tag) })
$Script:UI.GraphicsProfile.Add_SelectionChanged({ Reset-DashboardGraphics; Update-DashboardGraphicsChoice })
$Script:UI.GraphicsAcknowledge.Add_Click({ Update-DashboardGraphicsChoice })
$Script:UI.GraphicsCheckButton.Add_Click({ Start-DashboardAction 'GraphicsPlan' })
$Script:UI.GraphicsApplyButton.Add_Click({ Start-DashboardAction 'GraphicsApply' })
$Script:UI.GraphicsNvidiaButton.Add_Click({
    try {
        $path = Find-NvidiaProfileInspector
        if (-not $path) { throw 'nvidiaProfileInspector.exe was not found. Set its path through the classic NVIDIA action first.' }
        Start-Process -FilePath $path -WorkingDirectory (Split-Path -Parent $path)
        Set-DashboardMessage 'NVIDIA Profile Inspector opened. Import the bundled .nip there, then Apply.'
    } catch { Set-DashboardMessage $_.Exception.Message -IsError }
})
$Script:UI.GraphicsNvidiaReadmeButton.Add_Click({
    try {
        $path = Join-Path $Script:Root 'graphics\nvidia\README.txt'
        if (-not (Test-Path -LiteralPath $path)) { throw 'Bundled NVIDIA profile notes are missing.' }
        Start-Process notepad.exe -ArgumentList $path
    } catch { Set-DashboardMessage $_.Exception.Message -IsError }
})
Set-DashboardCombo $Script:UI.GraphicsProfile $Script:GraphicsProfiles 'GameOption_Remastered_1440p.patch'
$Script:UI.RecoveryFilesButton.Add_Click({
    $folder = if ($Script:Config.pazFolder) { Join-Path $Script:Config.pazFolder 'BDO_AIO_RECOVERY' } else { '' }
    if ($folder -and (Test-Path -LiteralPath $folder)) { Start-Process explorer.exe -ArgumentList ('"' + $folder + '"') }
    else { Set-DashboardMessage 'No retained recovery files exist for this game folder yet.' }
})
$Script:UI.PresetBackupsButton.Add_Click({
    $folder = Join-Path $Script:Root 'backup'
    if (Test-Path -LiteralPath $folder) { Start-Process explorer.exe -ArgumentList ('"' + $folder + '"') }
    else { Set-DashboardMessage 'No local preset backups exist yet.' }
})
$Script:UI.Nav.Add_SelectionChanged({ if ($Script:UI.Nav.SelectedItem) { Show-DashboardPage ([string]$Script:UI.Nav.SelectedItem.Tag) } })
foreach ($name in @('PazPath', 'SlotClasses')) { $Script:UI[$name].Add_TextChanged({ Set-DashboardDirty }) }
foreach ($name in @('GenderBox', 'ArmorBox', 'CensorshipBox')) { $Script:UI[$name].Add_SelectionChanged({ Set-DashboardDirty }) }
foreach ($name in @('XyzwCheck', 'hideGloves', 'hideBoots', 'hideHelmets', 'hideWeapons', 'hideStockings')) { $Script:UI[$name].Add_Click({ Set-DashboardDirty }) }
$Script:UI.RecommendedButton.Add_Click({ Set-DashboardBodyValues $Script:BodySizeAxisDefaults; Set-DashboardDirty })
$Script:UI.SaveButton.Add_Click({ if (Save-DashboardSettings) { Start-DashboardScan } })
$Script:UI.ReloadButton.Add_Click({
    if ($Script:DashboardDirty -and [Windows.MessageBox]::Show($Script:DashboardWindow, 'Discard unsaved edits and reload the saved settings?', 'Reload settings', 'OKCancel', 'Question') -ne 'OK') { return }
    try { Read-DashboardSettings; Start-DashboardScan } catch { Set-DashboardMessage $_.Exception.Message -IsError }
})
$Script:UI.RefreshButton.Add_Click({ Start-DashboardScan })
$Script:UI.PythonButton.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choose an existing Python 3 interpreter'
    $dialog.Filter = 'Python interpreter (python.exe)|python.exe'
    if ($Script:PythonExe -and (Test-Path -LiteralPath $Script:PythonExe)) { $dialog.FileName = $Script:PythonExe }
    try {
        if ($dialog.ShowDialog() -ne 'OK') { return }
        $resolved = & $dialog.FileName -c 'import sys; assert sys.version_info.major == 3; print(sys.executable)' 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $resolved -or -not (Test-Path -LiteralPath ([string]@($resolved)[-1]))) { throw 'That executable did not identify itself as Python 3.' }
        $Script:Config | Add-Member -NotePropertyName pythonPath -NotePropertyValue ([string]@($resolved)[-1]) -Force
        $Script:PythonExe = [string]@($resolved)[-1]
        Set-DashboardDirty
        Set-DashboardMessage 'Python selected. Save settings to keep this interpreter.'
    } catch { Set-DashboardMessage $_.Exception.Message -IsError }
    finally { $dialog.Dispose() }
})
$Script:UI.BrowseButton.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select Black Desert Online\PAZ (contains pad00000.meta)'
    $dialog.ShowNewFolderButton = $false
    if (Test-Path -LiteralPath $Script:UI.PazPath.Text) { $dialog.SelectedPath = $Script:UI.PazPath.Text }
    try {
        if ($dialog.ShowDialog() -eq 'OK') { $Script:UI.PazPath.Text = $dialog.SelectedPath }
    } finally { $dialog.Dispose() }
})
$Script:UI.StageFolderButton.Add_Click({
    $folder = if ($Script:Config.pazFolder) { Join-Path $Script:Config.pazFolder 'files_to_patch' } else { '' }
    if ($folder -and (Test-Path -LiteralPath $folder)) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $folder + '"') }
    else { Set-DashboardMessage 'No staged folder exists at the saved game location yet.' }
})
$Script:UI.LogsButton.Add_Click({
    $folder = Join-Path $Script:Root 'logs'
    if (Test-Path -LiteralPath $folder) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $folder + '"') }
    else { Set-DashboardMessage 'No logs yet. A tool session creates this folder.' }
})
$Script:UI.CopyLogButton.Add_Click({ try { [Windows.Clipboard]::SetText($Script:UI.ActivityText.Text); Set-DashboardMessage 'Visible log copied.' } catch { Set-DashboardMessage 'Clipboard is busy. Try again.' -IsError } })
# Walk the built tree to wire every action button, including those without a name.
function Connect-DashboardActions($Element) {
    if ($Element -is [Windows.Controls.Button] -and $Element.Tag) {
        $Script:DashboardActions += $Element
        $Element.Add_Click({ param($sender, $eventArgs) Start-DashboardAction ([string]$sender.Tag) })
    }
    foreach ($child in [Windows.LogicalTreeHelper]::GetChildren($Element)) {
        if ($child -is [Windows.DependencyObject]) { Connect-DashboardActions $child }
    }
}
Connect-DashboardActions $Script:DashboardWindow
Read-DashboardSettings
Read-DashboardTimings
$Script:DashboardTimer = New-Object Windows.Threading.DispatcherTimer
$Script:DashboardTimer.Interval = [TimeSpan]::FromMilliseconds(750)
$Script:DashboardTimer.Add_Tick({ try { Update-DashboardTick } catch { Set-DashboardMessage $_.Exception.Message -IsError } })
$Script:DashboardWindow.Add_Closing({
    param($sender, $eventArgs)
    if ($Script:DashboardProcess) {
        $eventArgs.Cancel = $true
        Set-DashboardMessage 'Finish or close the tool session before closing the dashboard.' -IsError
        return
    }
    if ($Script:DashboardDirty -and [Windows.MessageBox]::Show($Script:DashboardWindow, 'Close without saving your edited choices?', 'Unsaved choices', 'OKCancel', 'Question') -ne 'OK') { $eventArgs.Cancel = $true }
})
$Script:DashboardWindow.Add_Closed({
    $Script:DashboardTimer.Stop()
    if ($Script:DashboardScan) { $Script:DashboardScan.Stop(); $Script:DashboardScan.Dispose(); $Script:DashboardScan = $null }
})
if (-not $NoShow) {
    $Script:DashboardTimer.Start()
    $Script:DashboardWindow.Add_ContentRendered({ Start-DashboardScan })
    $null = $Script:DashboardWindow.ShowDialog()
}
