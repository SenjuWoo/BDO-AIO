# Disposable GameOption merge and native graphics-action boundary checks.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\bdo_aio.ps1')
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('bdo-graphics-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot
try {
    $sourceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $Script:GraphicsDir = Join-Path $sourceRoot 'graphics'
    $Script:GameOptionTool = Join-Path $sourceRoot 'tools\bdo_meta\gameoption_patcher.py'
    $Script:PythonExe = @(Get-Command python -CommandType Application -ErrorAction Stop)[0].Source
    $Script:Config = [pscustomobject]@{ npiPath = '' }
    $profile = 'GameOption_Remastered_1080p.patch'
    $profilePath = Join-Path $Script:GraphicsDir $profile
    $target = Join-Path $tempRoot 'GameOption.txt'
    $lines = @(Get-Content -LiteralPath $profilePath | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    $lines = @('adaptorList = 3077020889', 'unknownUserKey = keep-me') + ($lines -replace '^width\s*=.*$', 'width = 2560' -replace '^height\s*=.*$', 'height = 1440' -replace '^dof\s*=.*$', 'dof = 1' -replace '^motionBlurPower\s*=.*$', 'motionBlurPower = 0.75')
    [IO.File]::WriteAllText($target, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding $false))
    function Get-BdoDocumentsFolder { return $tempRoot }
    function Test-BdoToolsIdle { return $true }
    function Test-NipReady { return @{ Ok = $true; Path = (Join-Path $Script:GraphicsDir 'nvidia\Black_Desert_Max_Quality.nip') } }
    function Find-NvidiaProfileInspector { return 'nvidiaProfileInspector.exe' }

    $plan = Get-NativeGraphicsPlan -Profile $profile
    if (-not $plan.canApply -or @($plan.changed).Count -lt 4 -or $plan.sourceBytes -le 0 -or -not $plan.nvidia.inspectorAvailable) { throw 'Graphics preview did not report the disposable fixture correctly.' }
    $originalHash = (Get-FileHash -LiteralPath $target).Hash
    $result = Invoke-NativeGraphics -Profile $profile -Token $plan.token -Confirmed
    if ($result.operation -ne 'graphics' -or -not (Test-Path -LiteralPath $result.backup)) { throw 'Native graphics apply did not retain a complete backup.' }
    if ((Get-FileHash -LiteralPath $result.backup).Hash -ne $originalHash) { throw 'GameOption backup is not byte-identical.' }
    $written = [IO.File]::ReadAllText($target)
    if ($written -notmatch 'width = 1920' -or $written -notmatch 'height = 1080' -or $written -notmatch 'unknownUserKey = keep-me') { throw 'Profile merge changed the wrong data or missed a selected key.' }

    $stale = Get-NativeGraphicsPlan -Profile $profile
    [IO.File]::AppendAllText($target, "externalChange = preserved`r`n")
    $blocked = $false
    try { Invoke-NativeGraphics -Profile $profile -Token $stale.token -Confirmed } catch { $blocked = $_.Exception.Message -match 'changed after preview' }
    if (-not $blocked) { throw 'Changed GameOption did not invalidate the preview token.' }
    $blocked = $false
    try { Invoke-NativeGraphics -Profile $profile -Token $stale.token -Confirmed:$false } catch { $blocked = $_.Exception.Message -match 'explicitly confirm' }
    if (-not $blocked) { throw 'Unconfirmed native graphics action was not rejected.' }
    Write-Host 'PASS: graphics preview, atomic merge, complete backup, unknown-key preservation, token invalidation and confirmation guard.'

    # The legacy menu must enforce the same idle boundary before writing.
    $legacyRoot = Join-Path $tempRoot 'legacy'
    $null = New-Item -ItemType Directory -Path $legacyRoot -Force
    $legacyTarget = Join-Path $legacyRoot 'GameOption.txt'
    [IO.File]::WriteAllText($legacyTarget, 'adaptorList = 1`r`n', (New-Object System.Text.UTF8Encoding $false))
    function Write-Banner {}
    function Test-GraphicsReady { return [pscustomobject]@{ Ok = $true; Missing = @() } }
    function Get-BdoDocumentsFolder { return $Script:LegacyGraphicsRoot }
    function Ensure-Python { return $true }
    function Test-BdoToolsIdle { $Script:IdleChecks++; return $false }
    function Read-Host {
        param([string]$Prompt)
        if ($Prompt -match 'Select profile') { return '1' }
        return 'y'
    }
    function Pause-Any {}
    $Script:IdleChecks = 0
    $Script:LegacyGraphicsRoot = $legacyRoot
    $Script:GraphicsProfiles = [ordered]@{ 'GameOption_Remastered_1080p.patch' = 'Fixture' }
    Apply-GraphicsProfile
    if ($Script:IdleChecks -ne 1 -or @(Get-ChildItem -LiteralPath $legacyRoot -Filter 'GameOption.backup.*' -File).Count) { throw 'Legacy graphics path wrote while patch tools were active.' }
    Write-Host 'PASS: legacy graphics apply stops before backup when patch tools are active.'
} finally {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if ($resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and $resolved -match 'bdo-graphics-test-[0-9a-f]{32}$') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
