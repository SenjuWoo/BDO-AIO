# Real child-process output must never turn a failed tool into a truthy array.
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\..\bdo_aio.ps1'
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$null, [ref]$null)
foreach ($name in @('Invoke-BdoPythonChecked', 'Invoke-VanillaRestoreTool')) {
    $fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
    Invoke-Expression $fn.Extent.Text
}
function Write-Err([string]$Message) { Write-Host $Message }
function Ensure-Python { return $true }
$Script:PythonExe = (Get-Process -Id $PID).Path
$Script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Script:Config = [pscustomobject]@{ pazFolder = 'unused' }

foreach ($code in @(1, 0)) {
    $result = @(Invoke-BdoPythonChecked -Arguments @('-NoProfile', '-Command', "Write-Output 'tool diagnostic'; exit $code"))
    if ($result.Count -ne 1 -or $result[0] -isnot [bool] -or $result[0] -ne ($code -eq 0)) {
        throw "Exit $code produced $($result.Count) result objects; expected exactly one Boolean."
    }
}
# Resolve a real tool path, but substitute the child invocation through the shared
# checked runner. This also proves restore goes through the same tested boundary.
function Invoke-BdoPythonChecked {
    param([object[]]$Arguments, [string]$Label)
    if ($Arguments[1] -ne 'verify') { throw 'Restore arguments were not forwarded.' }
    return $false
}
$restore = @(Invoke-VanillaRestoreTool @('verify'))
if ($restore.Count -ne 1 -or $restore[0] -isnot [bool] -or $restore[0]) { throw 'Restore failure was lost.' }
Write-Host 'PASS: checked child and restore return exactly one Boolean, including noisy failures.'
