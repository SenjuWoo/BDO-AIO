# No live tool, drive mapping or game file is used in these failure-path tests.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\bdo_aio.ps1')
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('bdo-workflow-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot
try {
    $Script:Root = $tempRoot
    $Script:Config = [pscustomobject]@{ pazFolder = $tempRoot; lastMetaVersion = 0 }
    $null = New-Item -ItemType Directory -Path (Join-Path $tempRoot 'files_to_patch')
    $null = New-Item -ItemType File -Path (Join-Path $tempRoot 'Meta Injector.exe')
    function Write-Banner {}
    function Pause-Any {}
    function Test-IsPazFolder { return $true }
    function Test-BdoToolsIdle { return $true }
    function Ensure-Python { return $true }
    function Ensure-ToolsInPaz {}
    function Test-BdoToolkitInstalled { return $true }
    function Mount-BdoTemporaryDrive { return 'X:' }
    function Dismount-BdoTemporaryDrive {}
    function Prepare-BdoInjectStage { return 'X:\stage' }
    function Get-BdoMetaVersion { return 3435 }
    function Get-BdoClientRegion { return 'NA' }
    function Save-Config { $Script:Saved++ }
    function Invoke-VanillaRestoreTool {
        param([string[]]$ToolArgs)
        if ($ToolArgs[0] -eq 'backup') { return $Script:BackupResult }
        if ($ToolArgs[0] -eq 'verify') { $Script:Verified++; return $Script:VerifyResult }
        throw 'Unexpected restore operation in test.'
    }
    function Start-Process {
        $Script:Launched++
        $fake = [pscustomobject]@{ ExitCode = $Script:InjectorExit }
        $fake | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { if ($args.Count) { return $true } }
        $fake | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
        return $fake
    }
    foreach ($case in @(
        @($false, 0, $true, 'backup-failed', 0, 0, 0),
        @($true, 27, $true, 'injector-failed', 1, 0, 0),
        @($true, 0, $false, 'verify-failed', 1, 1, 0),
        @($true, 0, $true, 'completed', 1, 1, 1)
    )) {
        $Script:BackupResult = $case[0]
        $Script:InjectorExit = $case[1]
        $Script:VerifyResult = $case[2]
        $Script:Launched = 0
        $Script:Verified = 0
        $Script:Saved = 0
        $result = @(Run-MetaInjector)
        $report = Get-Content -LiteralPath $Script:LastMetaInjectReportPath -Raw | ConvertFrom-Json
        if ($result.Count -ne 1 -or $result[0] -isnot [bool] -or $result[0] -ne ($case[3] -eq 'completed')) { throw "Wrong Boolean result for $($case[3])." }
        if ($report.state -ne $case[3] -or $Script:Launched -ne $case[4] -or $Script:Verified -ne $case[5] -or $Script:Saved -ne $case[6] -or -not $report.finishedAt) { throw "Incorrect state/side effects for $($case[3])." }
        if ($report.state -eq 'completed' -and ($report.injectorExitCode -ne 0 -or $report.verifyPassed -ne $true)) { throw 'False completion.' }
    }
    Write-Host 'PASS: failed backup, nonzero injector and failed verification cannot reach completion.'
    $Script:Steps = @()
    function Test-PackReady { return @{ Ok = $true } }
    function Deploy-Midnight { $Script:Steps += 'deploy'; return $true }
    function Apply-AllRestoredChoices { $Script:Steps += 'restored'; return $false }
    function Run-PartCutGen { $Script:Steps += 'partcut'; return $true }
    function Run-MetaInjector { $Script:Steps += 'inject'; return $true }
    if (Run-FullWizard -NoPrompt) { throw 'Wizard accepted a failed generator.' }
    if (($Script:Steps -join ',') -ne 'deploy,restored') { throw 'Wizard continued past generator failure.' }
    Write-Host 'PASS: wizard stops before PartCutGen/injection after a failed generator.'
    $ftp = Join-Path $tempRoot 'files_to_patch'
    foreach ($name in @('_slot_hide_boots', '_censorship_high', 'my-personal-mod', 'character')) {
        $folder = Join-Path $ftp $name
        $null = New-Item -ItemType Directory -Path $folder -Force
        [IO.File]::WriteAllText((Join-Path $folder 'keep.txt'), $name)
    }
    $count = Clear-AioGenerated -Archive
    if ($count -ne 2 -or (Test-Path -LiteralPath (Join-Path $ftp '_slot_hide_boots'))) { throw 'Generated stages were not archived.' }
    foreach ($name in @('my-personal-mod', 'character')) {
        if ([IO.File]::ReadAllText((Join-Path $ftp ($name + '\keep.txt'))) -ne $name) { throw 'Unowned stage changed.' }
    }
    $backups = @(Get-ChildItem -LiteralPath (Join-Path $tempRoot 'BDO_AIO_STAGE_BACKUPS') -Filter 'keep.txt' -Recurse -File)
    if ($backups.Count -ne 2) { throw 'Previous generated files were not retained.' }
    Write-Host 'PASS: old generated stages are retained; personal and Midnight files stay untouched.'

    $stale = Join-Path $ftp '_pubic_hair_oldstyle'
    $null = New-Item -ItemType Directory -Path $stale -Force
    [IO.File]::WriteAllText((Join-Path $stale 'keep-stale.txt'), 'stale')
    Remove-StalePubicPackages
    if (Test-Path -LiteralPath $stale) { throw 'Stale pubic package was deleted or left in the injector input.' }
    $staleBackups = @(Get-ChildItem -LiteralPath (Join-Path $tempRoot 'BDO_AIO_STAGE_BACKUPS') -Filter 'keep-stale.txt' -Recurse -File)
    if ($staleBackups.Count -ne 1) { throw 'Stale pubic package was not retained in a recoverable archive.' }
    Write-Host 'PASS: stale pubic packages are archived instead of deleted.'
} finally {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if ($resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and $resolved -match 'bdo-workflow-test-[0-9a-f]{32}$') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
