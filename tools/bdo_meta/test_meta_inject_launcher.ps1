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
