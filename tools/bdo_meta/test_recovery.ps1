# Real preset copying and native recovery boundary checks; disposable files only.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\bdo_aio.ps1')
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('bdo-recovery-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot
try {
    $Script:Root = $tempRoot
    $presets = Join-Path $tempRoot 'presets'
    $null = New-Item -ItemType Directory -Path $presets
    [IO.File]::WriteAllText((Join-Path $presets 'character'), 'personal preset')
    [IO.File]::WriteAllText((Join-Path $presets 'hidden'), 'hidden preset')
    (Get-Item -LiteralPath (Join-Path $presets 'hidden')).Attributes = 'Hidden'
    $copies = @(Backup-BdoCustomizationPresets -Required -CustomizationPath $presets)
    if ($copies.Count -ne 1 -or [IO.File]::ReadAllText((Join-Path $copies[0] 'hidden')) -ne 'hidden preset' -or [IO.File]::ReadAllText((Join-Path $copies[0] 'character')) -ne 'personal preset') { throw 'Preset copy lost files or polluted the result.' }
    $Script:Root = Join-Path $presets 'character'
    $rejected = $false
    try { Backup-BdoCustomizationPresets -Required -CustomizationPath $presets } catch { $rejected = $true }
    if (-not $rejected) { throw 'Required preset copy failure was ignored.' }
    $Script:Root = $tempRoot
    $Script:Calls = 0
    $Script:Idle = $true
    $Script:CopyFails = $false
    function Test-BdoToolsIdle { return $Script:Idle }
    function Backup-BdoCustomizationPresets { param([switch]$Required); if (-not $Required -or $Script:CopyFails) { throw 'Preset copy failed' }; return 'retained-presets' }
    function Invoke-RecoveryJson { param([string[]]$Arguments); $Script:Calls++; if ($Arguments[0] -ne 'recover' -or '--confirmed' -notin $Arguments) { throw 'Wrong recovery arguments' }; return [pscustomobject]@{ state = 'completed' } }
    foreach ($case in @('unconfirmed', 'bad-token', 'busy', 'copy-failed')) {
        $Script:Idle = $case -ne 'busy'
        $Script:CopyFails = $case -eq 'copy-failed'
        $token = if ($case -eq 'bad-token') { 'bad' } else { 'a' * 64 }
        $rejected = $false
        try { Invoke-NativeRecovery -Operation restore -Token $token -Confirmed:($case -ne 'unconfirmed') } catch { $rejected = $true }
        if (-not $rejected -or $Script:Calls) { throw "Recovery crossed failed $case guard." }
    }
    $Script:Idle = $true
    $Script:CopyFails = $false
    $result = @(Invoke-NativeRecovery -Operation restore -Token ('a' * 64) -Confirmed)
    if ($result.Count -ne 1 -or $result[0].presetBackup -ne 'retained-presets' -or $Script:Calls -ne 1) { throw 'Native result was lost or polluted.' }
    # A fresh read-only launch must not persist lastMetaVersion before failing.
    $fixtureConfig = Join-Path $tempRoot 'config.json'
    $config = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\config.example.json') -Raw | ConvertFrom-Json
    $config.pazFolder = $tempRoot
    $config.lastMetaVersion = 0
    [IO.File]::WriteAllBytes((Join-Path $tempRoot 'pad00000.meta'), [BitConverter]::GetBytes([uint32]3444))
    [IO.File]::WriteAllText($fixtureConfig, ($config | ConvertTo-Json -Depth 32))
    $before = (Get-FileHash -LiteralPath $fixtureConfig).Hash
    $report = Join-Path $tempRoot 'result.json'
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\..\bdo_aio.ps1') -Action RecoveryPlan -ConfigFile $fixtureConfig -ResultFile $report
    if ($LASTEXITCODE -notin @(0, 1)) { throw 'Recovery preview exited unexpectedly.' }
    $preview = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    if ($preview.state -eq 'completed' -and $preview.recoveryPlan.current.valid) { throw 'Malformed fixture was reported as valid.' }
    if ((Get-FileHash -LiteralPath $fixtureConfig).Hash -ne $before) { throw 'Read-only recovery launch saved personal configuration.' }
    Write-Host 'PASS: hidden/personal presets copied, copy failure aborts, confirmation/token/process guards stop writes, one structured result.'
} finally {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if ($resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and $resolved -match 'bdo-recovery-test-[0-9a-f]{32}$') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
