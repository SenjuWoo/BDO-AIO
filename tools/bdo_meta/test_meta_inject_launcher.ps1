$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = Join-Path $root 'bdo_aio.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
    throw ($parseErrors | ForEach-Object Message | Out-String)
}

$functionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Prepare-BdoInjectStage'
}, $true)
if (-not $functionAst) { throw 'Prepare-BdoInjectStage was not found.' }
if ($functionAst.Extent.Text -notmatch '\$ReportPath' -or $functionAst.Extent.Text -notmatch "'--report'") {
    throw 'Prepare-BdoInjectStage does not forward the structured stage report path.'
}
Invoke-Expression $functionAst.Extent.Text

$injectorAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Run-MetaInjector'
}, $true)
if (-not $injectorAst) { throw 'Run-MetaInjector was not found.' }
if ($injectorAst.Extent.Text -notmatch '\.WaitForExit\(5000\)' -or
    $injectorAst.Extent.Text -notmatch 'Meta Injector is running') {
    throw 'Run-MetaInjector does not expose a five-second progress heartbeat.'
}
if ($injectorAst.Extent.Text -match 'Run Meta Injector again anyway') {
    throw 'Modified meta alone must not block changed settings from being reinjected.'
}

$reportFunctionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Write-MetaInjectReport'
}, $true)
if (-not $reportFunctionAst) { throw 'Write-MetaInjectReport was not found.' }
Invoke-Expression $reportFunctionAst.Extent.Text

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('bdo-aio-meta-launch-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $dummyBuilder = Join-Path $tempRoot 'builder.ps1'
    Set-Content -LiteralPath $dummyBuilder -Encoding ASCII -Value @(
        "Write-Output 'builder stdout one'",
        "Write-Output 'builder stdout two'",
        'exit 0'
    )
    $Script:PythonExe = (Get-Process -Id $PID).Path
    $Script:InjectStageTool = $dummyBuilder
    function Write-Info([string]$Message) { Write-Host $Message }

    $reportPath = Join-Path $tempRoot 'reports\sample.json'
    $sample = [ordered]@{ runId = 'test-run'; state = 'verified'; injectorMs = 123 }
    Write-MetaInjectReport -Report $sample -Path $reportPath
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'Structured report was not written.' }
    $roundTrip = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($roundTrip.runId -ne 'test-run' -or $roundTrip.state -ne 'verified' -or $roundTrip.injectorMs -ne 123) {
        throw 'Structured report did not round-trip its fields.'
    }
    Write-Host 'PASS: Meta Injector report writer creates a readable structured report.'

    $stage = Prepare-BdoInjectStage -PazDrive 'X:' -SourceDrive 'Y:'
    if ($stage -isnot [string]) { throw "Stage must be one string; got $($stage.GetType().FullName)." }
    if ($stage -ne 'X:\BDO_AIO_INJECT') { throw "Unexpected stage path: $stage" }

    Write-Host 'PASS: stage-builder console output cannot contaminate the Meta Injector argument.'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

# Ensure-VanillaMeta: an already-injected meta must be restored to vanilla before any generator or
# injector runs. Measured 2026-10-21: re-injecting over an injected meta left 27 body-size entries
# pointing into a rewritten archive, and the game refused to start ("file corruption").
$guardAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Ensure-VanillaMeta'
}, $true)
if (-not $guardAst) { throw 'Ensure-VanillaMeta was not found.' }
Invoke-Expression $guardAst.Extent.Text

$Script:Config = [pscustomobject]@{ pazFolder = 'X:\paz' }
function Write-Warn([string]$Message) {}
function Write-Ok([string]$Message) {}
function Write-Err([string]$Message) {}
$Script:RestoreCalls = New-Object System.Collections.Generic.List[string]
$Script:RestoreResult = $true
function Invoke-VanillaRestoreTool { param([string[]]$ToolArgs) $Script:RestoreCalls.Add($ToolArgs -join ' '); return $Script:RestoreResult }
function Get-PazStatusReport { param([string]$PazFolder) return $Script:FakeReport }

$Script:FakeReport = [pscustomobject]@{ meta = [pscustomobject]@{ state = 'RESTORED' } }
if (-not (Ensure-VanillaMeta) -or $Script:RestoreCalls.Count -ne 0) { throw 'A vanilla meta must pass without a restore.' }
$Script:FakeReport = [pscustomobject]@{ meta = [pscustomobject]@{ state = 'STALE_BACKUP' } }
if (-not (Ensure-VanillaMeta) -or $Script:RestoreCalls.Count -ne 0) { throw 'A stale snapshot is not an injected meta and must not trigger a restore.' }
$Script:FakeReport = $null
if (-not (Ensure-VanillaMeta) -or $Script:RestoreCalls.Count -ne 0) { throw 'An unreadable state must not block or restore.' }
$Script:FakeReport = [pscustomobject]@{ meta = [pscustomobject]@{ state = 'MODDED' } }
if (-not (Ensure-VanillaMeta)) { throw 'A modded meta must be restored and then pass.' }
if ($Script:RestoreCalls.Count -ne 1 -or $Script:RestoreCalls[0] -ne 'restore --apply') { throw "Unexpected restore call: $($Script:RestoreCalls -join '|')" }
$Script:RestoreResult = $false
if (Ensure-VanillaMeta) { throw 'A failed restore must stop the apply.' }
Write-Host 'PASS: an injected meta is restored to vanilla before applying; a failed restore stops the run.'

# Every entry point that generates or injects must call the guard before its first meta read/write.
function Get-FunctionText([string]$Name) {
    $node = $ast.Find({
        param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name
    }, $true)
    if (-not $node) { throw "$Name was not found." }
    return $node.Extent.Text
}
foreach ($case in @(
    @{ Fn = 'Run-FullWizard'; Before = 'Deploy-Midnight' },
    @{ Fn = 'Apply-AllRestoredChoices'; Before = 'Clear-AioGenerated' },
    @{ Fn = 'Run-MetaInjector'; Before = "Invoke-VanillaRestoreTool @('backup')" }
)) {
    $text = Get-FunctionText $case.Fn
    $guard = $text.IndexOf('Ensure-VanillaMeta')
    $first = $text.IndexOf($case.Before)
    if ($guard -lt 0 -or $first -lt 0 -or $guard -gt $first) { throw "$($case.Fn) must call Ensure-VanillaMeta before $($case.Before)." }
}
Write-Host 'PASS: the wizard, apply-all and Meta Injector all restore vanilla before they generate or inject.'
