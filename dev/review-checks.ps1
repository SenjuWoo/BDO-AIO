param([string]$Root = (Split-Path $PSScriptRoot), [string]$CaptureDir)
$ErrorActionPreference = 'Stop'
$tests = @(Get-ChildItem (Join-Path $Root 'tools/bdo_meta/test_*.ps1') -File | Sort-Object Name)
foreach ($test in $tests) {
    Write-Host ('RUN ' + $test.Name)
    $arguments = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $test.FullName)
    if ($test.Name -eq 'test_dashboard.ps1' -and $CaptureDir) { $arguments += @('-CaptureDir', $CaptureDir) }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw ('Failed: ' + $test.Name) }
}
$files = @(Get-ChildItem $Root -Recurse -File -Include *.ps1,*.psm1,*.psd1 | Where-Object { $_.FullName -notmatch '[\\/](backup|pack|experimental)[\\/]' })
foreach ($file in $files) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors) { throw ($errors | Out-String) }
}
Write-Host ('PASS: ' + $tests.Count + ' PowerShell suites and ' + $files.Count + ' parsed files.')
