#Requires -Version 5.1
# BDO Modding AIO - self-contained 2026 installer (everything under this folder)
param(
    [ValidateSet('Menu', 'Wizard', 'Deploy', 'PartCut', 'Inject', 'Restored', 'Options', 'Recovery', 'RecoveryPlan', 'RecoveryRestore', 'RecoverySnapshot', 'RecoveryCleanup', 'GraphicsPlan', 'GraphicsApply', 'Graphics', 'Nvidia', 'Dlss', 'Guide', 'VerifyPack', 'VerifyMeta', 'Regen')]
    [string]$Action = 'Menu',
    [string]$ConfigFile,
    [string]$ResultFile,
    [string]$PythonPath,
    [string]$RecoveryToken,
    [switch]$RecoveryConfirmed,
    [string]$GraphicsProfile,
    [string]$GraphicsToken,
    [switch]$GraphicsConfirmed
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:Version = '2.4.2'
$Script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ConfigPath = Join-Path $Script:Root 'config.json'
if ($ConfigFile) { $Script:ConfigPath = [IO.Path]::GetFullPath($ConfigFile) }
$Script:ConfigFingerprint = $null
$Script:DashboardAction = [bool]$ResultFile
$Script:LastMetaInjectReportPath = $null
$Script:PackDir = Join-Path $Script:Root 'pack'
$Script:GraphicsDir = Join-Path $Script:Root 'graphics'
$Script:NvidiaDir = Join-Path $Script:GraphicsDir 'nvidia'
$Script:NipFileName = 'Black_Desert_Max_Quality.nip'
$Script:ExperimentalDlssDir = Join-Path $Script:Root 'experimental\dlss'
$Script:BodySizeTool = Join-Path $Script:Root 'tools\bdo_meta\body_size_patcher.py'
$Script:SlotHideTool = Join-Path $Script:Root 'tools\bdo_meta\slot_hide_patcher.py'
$Script:PubicHairTool = Join-Path $Script:Root 'tools\bdo_meta\pubic_hair_apply.py'
$Script:PubicHairRoot = Join-Path $Script:Root 'tools\pubic_hair'
$Script:CensorshipTool = Join-Path $Script:Root 'tools\bdo_meta\censorship_pack_apply.py'
$Script:CensorshipRoot = Join-Path $Script:Root 'tools\censorship_removal'
$Script:GenitalTool = Join-Path $Script:Root 'tools\bdo_meta\genital_pack_apply.py'
$Script:GenitalRoot = Join-Path $Script:Root 'tools\genital_packs'
$Script:GameOptionTool = Join-Path $Script:Root 'tools\bdo_meta\gameoption_patcher.py'
$Script:PazStatusTool = Join-Path $Script:Root 'tools\bdo_meta\paz_status_scan.py'
$Script:InjectStageTool = Join-Path $Script:Root 'tools\bdo_meta\inject_stage_builder.py'
$Script:PythonExe = $PythonPath
$Script:DefaultHeishaRoot = Join-Path $Script:Root 'heisha'
# AIO-generated folders under files_to_patch (safe to clear on restore)
$Script:AioPatchFolderPrefixes = @(
    '_body_size_limits',
    '_slot_hide_',
    '_pubic_hair_',
    '_censorship_',
    '_genital_',
    '_body_uncut'
)

$Script:PubicHairStyles = [ordered]@{
    'none'               = 'Off (do not apply)'
    'shaved'             = 'Shaved'
    'shaved_innie'       = 'Shaved innie'
    'full_bush'          = 'Full bush'
    'full_bush_2'        = 'Full bush 2'
    'full_bush_3'        = 'Full bush 3'
    'medium_bush'        = 'Medium bush'
    'medium_bush2'       = 'Medium bush 2'
    'small_bush'         = 'Small bush'
    'small_bush_2'       = 'Small bush 2'
    'thin_landing_strip' = 'Thin landing strip'
    'wide_landing_strip' = 'Wide landing strip'
    'trimmed'            = 'Trimmed'
    'wider_trimmed'      = 'Wider trimmed'
}

# Only these classes own their body texture, so only these can be given their own
# style. Corsair owns one too but no shipped hair bin matches its size.
$Script:PubicPrivateAtlasPrefixes = @('pbw', 'pdw', 'pew', 'pgw', 'pww')

# The 10 female classes with an authored 3D-vagina mesh in the Resorepless pack.
# A genital PAC is a whole body: it carries the mesh AND that class's skin
# material. Reusing one for another class gave the wrong body and skin (measured:
# 7 of 9 old donor mappings bound a different texture than the class really uses),
# so the newer classes are simply unsupported rather than faked.
$Script:GenitalFemalePrefixes = @(
    'pbw', 'pcw', 'pdw', 'pew', 'phw', 'pkww', 'pnw', 'psw', 'pvw', 'pww'
)

# Curated look, limited by what the assets actually allow. The other 13 classes
# all render from ONE texture, so they can only ever share a single style -- see
# Show-PubicIsolationNotice. Classes meant to read as bare are simply left out.
$Script:PubicImmersivePreset = [ordered]@{
    'pgw' = 'full_bush'
    'pew' = 'medium_bush'
    'pww' = 'medium_bush'
}
# Female class prefixes for per-class pubic/genital pickers (Shai excluded)
$Script:FemaleClasses = [ordered]@{
    'phw'  = 'Sorceress'
    'pew'  = 'Ranger'
    'pbw'  = 'Tamer'
    'pvw'  = 'Valkyrie'
    'pww'  = 'Witch'
    'pgw'  = 'Guardian [EXPER.]'
    'pnw'  = 'Kunoichi'
    'pdw'  = 'Dark Knight'
    'pcw'  = 'Mystic'
    'psw'  = 'Lahn'
    'ppw'  = 'Nova [EXPER.]'
    'pkww' = 'Maehwa'
    'pfw'  = 'Corsair [EXPER.]'
    'pqw'  = 'Drakania [EXPER.]'
    'pkow' = 'Maegu [EXPER.]'
    'pmyf' = 'Woosa [EXPER.]'
    'pnyw' = 'Scholar [EXPER.]'
    'pwge' = 'Deadeye [EXPER.]'
    'pdkl' = 'Seraph [EXPER.]'
}
$Script:NativePubicPrefixes = @('pbw', 'pdw', 'pew', 'phw', 'pww')
$Script:NewFemalePrefixes = @('pgw', 'ppw', 'pfw', 'pqw', 'pkow', 'pmyf', 'pnyw', 'pwge', 'pdkl')

# Measured from the Midnight nude PACs: these 13 all render from ONE texture,
# phw_01_nude_0001. Styling that DDS styles every one of them, which is why the
# old per-class pubic selector appeared to do nothing. Each of these needs a
# private texture copy to be styled on its own. The other six classes
# (pbw, pdw, pew, pfw, pgw, pww) own their texture and cost nothing extra.
$Script:SharedAtlasPrefixes = @(
    'phw', 'pnw', 'pcw', 'psw', 'ppw', 'pkww', 'pqw',
    'pkow', 'pmyf', 'pnyw', 'pvw', 'pwge', 'pdkl'
)
$Script:Config = $null

$Script:BodySizeSchema = 2
$Script:BodySizeAxes = @(
    'breasts.x', 'breasts.y', 'breasts.z',
    'thighs.y', 'thighs.z',
    'butt.x', 'butt.y', 'butt.z',
    'pelvis.y', 'pelvis.z',
    'belly.x', 'belly.z'
)
$Script:BodySizeAxisDefaults = [ordered]@{
    'breasts.x' = 1.55; 'breasts.y' = 1.55; 'breasts.z' = 1.55
    'thighs.y' = 1.35; 'thighs.z' = 1.35
    'butt.x' = 1.20; 'butt.y' = 1.20; 'butt.z' = 1.20
    'pelvis.y' = 1.40; 'pelvis.z' = 1.40
    'belly.x' = 1.28; 'belly.z' = 1.45
}
$Script:BodySizeRecommendedSpec = 'breasts.x:1.55,breasts.y:1.55,breasts.z:1.55,thighs.y:1.35,thighs.z:1.35,butt.x:1.20,butt.y:1.20,butt.z:1.20,pelvis.y:1.40,pelvis.z:1.40,belly.x:1.28,belly.z:1.45'
$Script:BodySizeDefaultSpec = $Script:BodySizeRecommendedSpec

# Files we may place in game root for experimental OptiScaler (uninstall list)
$Script:OptiProxyNames = @('dxgi.dll', 'winmm.dll', 'version.dll', 'd3d12.dll', 'dbghelp.dll', 'wininet.dll', 'winhttp.dll')
$Script:OptiExtraFiles = @(
    'OptiScaler.dll', 'OptiScaler.ini',
    'amd_fidelityfx_dx12.dll', 'amd_fidelityfx_framegeneration_dx12.dll',
    'amd_fidelityfx_upscaler_dx12.dll', 'amd_fidelityfx_vk.dll',
    'dlssg_to_fsr3_amd_is_better.dll', 'fakenvapi.dll', 'fakenvapi.ini',
    'libxell.dll', 'libxess.dll', 'libxess_dx11.dll', 'libxess_fg.dll',
    'setup_windows.bat', 'setup_linux.sh',
    'sl.common.dll', 'sl.deepdvc.dll', 'sl.directsr.dll', 'sl.dlss.dll',
    'sl.dlss_d.dll', 'sl.dlss_g.dll', 'sl.interposer.dll', 'sl.nis.dll',
    'sl.nvperf.dll', 'sl.pcl.dll', 'sl.reflex.dll'
)

# Bundled GameOption profiles (filename -> short description)
$Script:GraphicsProfiles = [ordered]@{
    'GameOption_Remastered_1080p.patch'       = 'Remastered 1080p - maximum-quality native gameplay'
    'GameOption_Remastered_1440p.patch'       = 'Remastered 1440p - maximum-quality native gameplay'
    'GameOption_Remastered_DLDSR_4K.patch'    = 'Remastered DLDSR 4K - maximum IQ on 1440p monitor (needs NVIDIA DSR 2.25x)'
}

$Script:GenderMap = [ordered]@{
    'F' = 'Female only'
    'M' = 'Male only'
    'B' = 'Both genders'
}
$Script:ArmorMap = [ordered]@{
    'A' = 'All armors and outfits (recommended for full nude look)'
    'P' = 'Pearl Shop outfits only'
    'F' = 'Free / non-cash outfits only'
    'U' = 'Underwear hide only (no full armor strip)'
}

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor Cyan
    Write-Host ("   BDO MODDING AIO  " + $Script:Version + '  |  Self-contained  |  2026 pipeline') -ForegroundColor White
    Write-Host '   MODERN + RESTORED options  |  [X] EXPERIMENTAL only = from-scratch' -ForegroundColor DarkCyan
    Write-Host '  ============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Write-Info([string]$msg)  { Write-Host ("  [i] " + $msg) -ForegroundColor Cyan }
function Write-Ok([string]$msg)    { Write-Host ("  [OK] " + $msg) -ForegroundColor Green }
function Write-Warn([string]$msg)  { Write-Host ("  [!] " + $msg) -ForegroundColor Yellow }
function Write-Err([string]$msg)   { Write-Host ("  [X] " + $msg) -ForegroundColor Red }

function Write-MetaInjectReport {
    param(
        [System.Collections.IDictionary]$Report,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $dir = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $tmp = $Path + '.tmp'
        $json = $Report | ConvertTo-Json -Depth 8
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tmp, $json, $utf8)
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    } catch {
        Write-Warn ('Could not write Meta Injector report: ' + $_.Exception.Message)
    }
}

function Pause-Any {
    if ($Script:DashboardAction) { return }
    Write-Host ''
    Write-Host '  Press any key to continue...' -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Read-Choice([string]$prompt, [string[]]$valid) {
    while ($true) {
        Write-Host ''
        $ans = (Read-Host ("  " + $prompt)).Trim().ToUpperInvariant()
        if ($valid -contains $ans) { return $ans }
        Write-Warn ("Pick one of: " + ($valid -join ', '))
    }
}

function Read-YesNo([string]$prompt, [bool]$defaultYes = $true) {
    $hint = if ($defaultYes) { 'Y/n' } else { 'y/N' }
    while ($true) {
        Write-Host ''
        $ans = (Read-Host ("  " + $prompt + " [" + $hint + "]")).Trim().ToLowerInvariant()
        if ([string]::IsNullOrEmpty($ans)) { return $defaultYes }
        if ($ans -in @('y', 'yes')) { return $true }
        if ($ans -in @('n', 'no'))  { return $false }
        Write-Warn 'Enter Y or N'
    }
}

function Get-FemaleClassKeys {
    return @($Script:FemaleClasses.Keys)
}

function Format-ClassList([string]$csv) {
    if ([string]::IsNullOrWhiteSpace($csv)) { return 'ALL females' }
    return $csv
}

function Select-FemaleClasses {
    param(
        [string]$Title = 'Select female classes',
        [string]$CurrentCsv = '',
        [switch]$DefaultAll,
        # When set, only these prefixes can be picked. Used by 3D vagina, where a
        # class without an authored mesh is not a worse option -- it is no option.
        [string[]]$Supported = @()
    )
    $limited = ($Supported.Count -gt 0)
    Write-Host ''
    Write-Host ("  " + $Title) -ForegroundColor White
    Write-Host '  -----------------------' -ForegroundColor DarkGray
    Write-Host ("  Current: " + (Format-ClassList $CurrentCsv)) -ForegroundColor DarkCyan
    Write-Host ''
    if ($limited) {
        Write-Host ('    [A] ALL ' + $Supported.Count + ' supported classes') -ForegroundColor Green
        Write-Host '        (classes with no authored mesh are not listed - there is' -ForegroundColor DarkGray
        Write-Host '         nothing to give them; reuse would hand over another' -ForegroundColor DarkGray
        Write-Host '         class body and skin, so it was removed in 2.1.1)' -ForegroundColor DarkGray
    } else {
        Write-Host '    [A] ALL females' -ForegroundColor Green
        Write-Host '    [N] NATIVE pubic bins only (Tamer/DK/Ranger/Sorceress/Witch)' -ForegroundColor Cyan
        Write-Host '    [E] NEW females only (Seraph/Deadeye/Woosa/… EXPERIMENTAL)' -ForegroundColor Yellow
    }
    Write-Host '    [C] CUSTOM multi-select by number' -ForegroundColor Magenta
    Write-Host '    [T] Type prefixes (e.g. phw,pdkl,pww)' -ForegroundColor Cyan
    Write-Host '    [K] Keep current' -ForegroundColor DarkGray
    $pick = (Read-Host '  Class pick').Trim().ToUpperInvariant()
    if ($limited -and $pick -in @('N', 'E')) {
        Write-Warn 'Not available here - every listed class already has an authored mesh.'
        $pick = 'C'
    }
    switch ($pick) {
        'A' { if ($limited) { return ($Supported -join ',') } else { return '' } }
        'N' { return ($Script:NativePubicPrefixes -join ',') }
        'E' { return ($Script:NewFemalePrefixes -join ',') }
        'K' { return $CurrentCsv }
        'T' {
            $raw = (Read-Host '  Prefixes comma-separated').Trim().ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($raw)) { return '' }
            $legal = if ($limited) { @($Supported) } else { @($Script:FemaleClasses.Keys) }
            $parts = @($raw -split '[,;\s]+' | Where-Object { $_ })
            $bad = @($parts | Where-Object { $_ -notin $legal })
            if ($bad.Count -gt 0) {
                if ($limited) {
                    Write-Warn ("No authored mesh, ignored: " + ($bad -join ', '))
                } else {
                    Write-Warn ("Unknown prefixes ignored: " + ($bad -join ', '))
                }
            }
            $ok = @($parts | Where-Object { $_ -in $legal } | Select-Object -Unique)
            if ($ok.Count -eq 0) {
                Write-Warn 'No valid prefixes — using ALL.'
                if ($limited) { return ($Supported -join ',') }
                return ''
            }
            return ($ok -join ',')
        }
        'C' {
            $keys = if ($limited) { @($Supported) } else { @(Get-FemaleClassKeys) }
            $on = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            if ([string]::IsNullOrWhiteSpace($CurrentCsv)) {
                if ($DefaultAll) { foreach ($k in $keys) { [void]$on.Add($k) } }
            } else {
                foreach ($p in ($CurrentCsv -split '[,;]+')) {
                    $t = $p.Trim()
                    if ($t) { [void]$on.Add($t) }
                }
            }
            while ($true) {
                Write-Host ''
                Write-Host '  Toggle classes (* = ON). Then D when done.' -ForegroundColor White
                for ($i = 0; $i -lt $keys.Count; $i++) {
                    $k = $keys[$i]
                    $mark = if ($on.Contains($k)) { '*' } else { ' ' }
                    $tag = if ($limited) { ' authored mesh' } elseif ($k -in $Script:NewFemalePrefixes) { ' EXPER' } elseif ($k -in $Script:NativePubicPrefixes) { ' native-bin' } else { '' }
                    Write-Host ("    [{0,2}] {1} {2,-6} {3}{4}" -f ($i + 1), $mark, $k, $Script:FemaleClasses[$k], $tag) -ForegroundColor Cyan
                }
                if ($limited) {
                    Write-Host '    [A] all on   [Z] all off' -ForegroundColor DarkGray
                } else {
                    Write-Host '    [A] all on   [Z] all off   [N] native bins only   [E] new females only' -ForegroundColor DarkGray
                }
                Write-Host '    [D] done' -ForegroundColor Green
                $cmd = (Read-Host '  Number(s) to toggle, or command').Trim().ToUpperInvariant()
                if ($cmd -eq 'D' -or $cmd -eq '') {
                    if ($on.Count -eq 0) {
                        Write-Warn 'None selected — using ALL females.'
                        if ($limited) { return ($Supported -join ',') }
                        return ''
                    }
                    if ($on.Count -eq $keys.Count) {
                        if ($limited) { return ($Supported -join ',') }
                        return ''
                    }
                    return (($on | Sort-Object) -join ',')
                }
                if ($cmd -eq 'A') { foreach ($k in $keys) { [void]$on.Add($k) }; continue }
                if ($cmd -eq 'Z') { $on.Clear(); continue }
                if ($limited -and $cmd -in @('N', 'E')) {
                    Write-Warn 'Not available here - every listed class already has an authored mesh.'
                    continue
                }
                if ($cmd -eq 'N') {
                    $on.Clear()
                    foreach ($k in $Script:NativePubicPrefixes) { [void]$on.Add($k) }
                    continue
                }
                if ($cmd -eq 'E') {
                    $on.Clear()
                    foreach ($k in $Script:NewFemalePrefixes) { [void]$on.Add($k) }
                    continue
                }
                foreach ($tok in ($cmd -split '[,;\s]+')) {
                    if ($tok -match '^\d+$') {
                        $idx = [int]$tok - 1
                        if ($idx -ge 0 -and $idx -lt $keys.Count) {
                            $k = $keys[$idx]
                            if ($on.Contains($k)) { [void]$on.Remove($k) } else { [void]$on.Add($k) }
                        }
                    }
                }
            }
        }
        default {
            # Say what an unrecognised key did instead of silently picking for them.
            if ($DefaultAll -or [string]::IsNullOrWhiteSpace($CurrentCsv)) {
                Write-Warn ("'" + $pick + "' is not an option here - using ALL females.")
                if ($limited) { return ($Supported -join ',') }
                return ''
            }
            Write-Warn ("'" + $pick + "' is not an option here - keeping: " + (Format-ClassList $CurrentCsv))
            return $CurrentCsv
        }
    }
}

function Load-Config {
    $Script:Config = $null
    $Script:ConfigFingerprint = $null
    if (Test-Path -LiteralPath $Script:ConfigPath) {
        try {
            $bytes = [IO.File]::ReadAllBytes($Script:ConfigPath)
            $Script:Config = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
            if ($Script:Config -isnot [pscustomobject]) { throw 'Expected a JSON object.' }
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $Script:ConfigFingerprint = [BitConverter]::ToString($hasher.ComputeHash($bytes)) } finally { $hasher.Dispose() }
        } catch {
            throw ("Cannot read settings at $($Script:ConfigPath). The file was left untouched. Repair its JSON or restore your backup. " + $_.Exception.Message)
        }
    }
    if (-not $Script:Config) {
        $Script:Config = [pscustomobject]@{
            pazFolder       = ''
            gender          = 'F'
            armor           = 'A'
            xyzwCollections = $true
            npiPath         = ''
            bodySizeSchema  = $Script:BodySizeSchema
            bodySizePreset  = 'recommended'
            bodySizeParts   = $Script:BodySizeRecommendedSpec
            hideGloves      = $false
            hideBoots       = $false
            hideHelmets     = $false
            hideWeapons     = $false
            hideStockings   = $false
            slotHideClasses = ''
            pubicHairStyle  = 'none'
            pubicHairStyles = ''
            pubicHairReuse  = $false
            pubicHairClasses = ''
            censorshipTier  = 'off'
            female3dVagina  = $false
            genitalFemaleClasses = ''
            genitalReuse    = $false
            malePenisMode   = 'none'
            penisWarrior    = 'none'
            penisBerserker  = 'none'
            penisMusa       = 'none'
            penisWizard     = 'none'
            penisNinja      = 'none'
            penisStriker    = 'none'
            heishaRoot      = ''
            lastMetaVersion = 0
            lastRun         = $null
        }
    }
    foreach ($p in @('pazFolder', 'gender', 'armor', 'xyzwCollections', 'npiPath', 'bodySizeSchema', 'bodySizePreset', 'bodySizeParts', 'hideGloves', 'hideBoots', 'hideHelmets', 'hideWeapons', 'hideStockings', 'slotHideClasses', 'pubicHairStyle', 'pubicHairStyles', 'pubicHairReuse', 'pubicHairClasses', 'censorshipTier', 'female3dVagina', 'genitalFemaleClasses', 'genitalReuse', 'malePenisMode', 'penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker', 'heishaRoot', 'lastMetaVersion', 'lastRun')) {
        if (-not ($Script:Config.PSObject.Properties.Name -contains $p)) {
            $val = switch ($p) {
                'gender' { 'F' }
                'armor'  { 'A' }
                'xyzwCollections' { $true }
                'bodySizeSchema' { 0 }
                'bodySizePreset' { 'recommended' }
                'bodySizeParts' { $Script:BodySizeDefaultSpec }
                'hideGloves' { $false }
                'hideBoots' { $false }
                'hideHelmets' { $false }
                'hideWeapons' { $false }
                'hideStockings' { $false }
                'slotHideClasses' { '' }
                'pubicHairStyle' { 'none' }
                'pubicHairStyles' { '' }
                'pubicHairReuse' { $false }
                'pubicHairClasses' { '' }
                'censorshipTier' { 'off' }
                'female3dVagina' { $false }
                'genitalFemaleClasses' { '' }
                'genitalReuse' { $false }
                'malePenisMode' { 'none' }
                'penisWarrior' { 'none' }
                'penisBerserker' { 'none' }
                'penisMusa' { 'none' }
                'penisWizard' { 'none' }
                'penisNinja' { 'none' }
                'penisStriker' { 'none' }
                'heishaRoot' { '' }
                'lastMetaVersion' { 0 }
                default { $null }
            }
            if ($null -eq $val -and $p -ne 'lastRun') {
                if ($p -match '^hide') { $val = $false } else { $val = '' }
            }
            Add-Member -InputObject $Script:Config -NotePropertyName $p -NotePropertyValue $val
        }
    }
    Update-BodySizeConfig
}

function Convert-BodySizeSpec {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $out = [ordered]@{}
    $culture = [Globalization.CultureInfo]::InvariantCulture
    foreach ($token in ($Raw -split '[,;]+')) {
        $token = $token.Trim()
        if (-not $token) { continue }
        $bits = $token -split ':', 2
        if ($bits.Count -ne 2) { return $null }
        $name = $bits[0].Trim().ToLowerInvariant()
        $value = 0.0
        if (-not [double]::TryParse($bits[1].Trim(), [Globalization.NumberStyles]::Float, $culture, [ref]$value)) { return $null }
        if ([double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -lt 1.0 -or $value -gt 99.0) { return $null }

        $expanded = [ordered]@{}
        if ($name.Contains('.')) {
            if ($name -notin $Script:BodySizeAxes) { return $null }
            $expanded[$name] = $value
        } else {
            if ($name -in @('breast')) { $name = 'breasts' }
            if ($name -in @('thigh')) { $name = 'thighs' }
            if ($name -in @('ass', 'hips', 'hip', 'pelvis')) { $name = 'butt' }
            if ($name -in @('spine', 'stomach', 'abdomen')) { $name = 'belly' }
            switch ($name) {
                'breasts' { foreach ($axis in @('x', 'y', 'z')) { $expanded['breasts.' + $axis] = $value } }
                'thighs' { foreach ($axis in @('y', 'z')) { $expanded['thighs.' + $axis] = $value } }
                'butt' {
                    foreach ($axis in @('x', 'y', 'z')) { $expanded['butt.' + $axis] = $value }
                    foreach ($axis in @('y', 'z')) { $expanded['pelvis.' + $axis] = $value }
                }
                'belly' { $expanded['belly.z'] = $value }
                { $_ -in @('legs', 'arms') } { continue }
                default { return $null }
            }
        }
        foreach ($key in $expanded.Keys) {
            if ($out.Contains($key)) { return $null }
            $out[$key] = $expanded[$key]
        }
    }
    if ($out.Count -eq 0) { return $null }
    return $out
}

function ConvertTo-BodySizeSpecString {
    param($Spec)
    if (-not $Spec -or $Spec.Count -eq 0) { return '' }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    return (($Spec.Keys | ForEach-Object { $_ + ':' + ([double]$Spec[$_]).ToString('0.##', $culture) }) -join ',')
}

# Schema 2 migration. Named presets become the new Recommended axis matrix.
# Legacy Custom scalars expand once into the exact axes they used to represent;
# belly scalar migrates to Z only and never infers the new Spine-X exception.
function Update-BodySizeConfig {
    foreach ($dead in @('bodySizeMin', 'bodySizeDefault', 'bodySizeMax')) {
        if ($Script:Config.PSObject.Properties.Name -contains $dead) {
            $Script:Config.PSObject.Properties.Remove($dead)
        }
    }
    $oldSchema = 0
    if ($Script:Config.PSObject.Properties.Name -contains 'bodySizeSchema') {
        $oldSchema = [int]$Script:Config.bodySizeSchema
    } else {
        Add-Member -InputObject $Script:Config -NotePropertyName bodySizeSchema -NotePropertyValue 0
    }
    $preset = [string]$Script:Config.bodySizePreset
    $oldSpec = [string]$Script:Config.bodySizeParts
    if ($preset -ne 'custom') {
        $Script:Config.bodySizePreset = 'recommended'
        $Script:Config.bodySizeParts = $Script:BodySizeRecommendedSpec
    } else {
        $parsed = Convert-BodySizeSpec $oldSpec
        if ($null -eq $parsed) {
            $Script:Config.bodySizePreset = 'recommended'
            $Script:Config.bodySizeParts = $Script:BodySizeRecommendedSpec
        } else {
            $Script:Config.bodySizeParts = ConvertTo-BodySizeSpecString $parsed
        }
    }
    $Script:Config.bodySizeSchema = $Script:BodySizeSchema
    if ($oldSchema -lt $Script:BodySizeSchema -and $oldSpec) {
        Write-Host ''
        Write-Host ('  [MIGRATED] Body slider schema ' + $oldSchema + ' -> ' + $Script:BodySizeSchema) -ForegroundColor Yellow
        Write-Host ('             ' + $oldSpec) -ForegroundColor DarkGray
        Write-Host ('          -> ' + [string]$Script:Config.bodySizeParts) -ForegroundColor DarkGray
        Write-Host '             Belly X is never inferred from an old scalar; configure it explicitly.' -ForegroundColor DarkGray
    }
}

function Save-Config {
    $Script:Config.lastRun = (Get-Date).ToString('s')
    # Store game path, choices, optional NPI path (NPI path is machine-local)
    $out = [pscustomobject]@{
        pazFolder       = [string]$Script:Config.pazFolder
        gender          = [string]$Script:Config.gender
        armor           = [string]$Script:Config.armor
        xyzwCollections = [bool]$Script:Config.xyzwCollections
        npiPath         = [string]$Script:Config.npiPath
        bodySizeSchema  = [int]$Script:Config.bodySizeSchema
        bodySizePreset  = [string]$Script:Config.bodySizePreset
        bodySizeParts   = [string]$Script:Config.bodySizeParts
        hideGloves      = [bool]$Script:Config.hideGloves
        hideBoots       = [bool]$Script:Config.hideBoots
        hideHelmets     = [bool]$Script:Config.hideHelmets
        hideWeapons     = [bool]$Script:Config.hideWeapons
        hideStockings   = [bool]$Script:Config.hideStockings
        slotHideClasses = [string]$Script:Config.slotHideClasses
        pubicHairStyle  = [string]$Script:Config.pubicHairStyle
        pubicHairStyles = [string]$Script:Config.pubicHairStyles
        pubicHairReuse  = [bool]$Script:Config.pubicHairReuse
        pubicHairClasses = [string]$Script:Config.pubicHairClasses
        censorshipTier  = [string]$Script:Config.censorshipTier
        female3dVagina  = [bool]$Script:Config.female3dVagina
        genitalFemaleClasses = [string]$Script:Config.genitalFemaleClasses
        genitalReuse    = [bool]$Script:Config.genitalReuse
        malePenisMode   = [string]$Script:Config.malePenisMode
        penisWarrior    = [string]$Script:Config.penisWarrior
        penisBerserker  = [string]$Script:Config.penisBerserker
        penisMusa       = [string]$Script:Config.penisMusa
        penisWizard     = [string]$Script:Config.penisWizard
        penisNinja      = [string]$Script:Config.penisNinja
        penisStriker    = [string]$Script:Config.penisStriker
        heishaRoot      = [string]$Script:Config.heishaRoot
        lastMetaVersion = [int]$Script:Config.lastMetaVersion
        lastRun         = $Script:Config.lastRun
    }
    # Preserve fields owned by newer builds and user extensions.
    foreach ($property in $Script:Config.PSObject.Properties) {
        if (-not $out.PSObject.Properties[$property.Name]) {
            $out | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
        }
    }
    if (Test-Path -LiteralPath $Script:ConfigPath) {
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $current = [BitConverter]::ToString($hasher.ComputeHash([IO.File]::ReadAllBytes($Script:ConfigPath))) } finally { $hasher.Dispose() }
        if ($current -ne $Script:ConfigFingerprint) { throw 'Settings changed in another window. Reload them before saving.' }
    } elseif ($Script:ConfigFingerprint) { throw 'Settings were removed in another window. Reload before saving.' }
    $json = $out | ConvertTo-Json -Depth 32
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    $temp = $Script:ConfigPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, $json, $utf8Bom)
        if (Test-Path -LiteralPath $Script:ConfigPath) {
            [IO.File]::Replace($temp, $Script:ConfigPath, ($Script:ConfigPath + '.bak'))
        } else { [IO.File]::Move($temp, $Script:ConfigPath) }
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $Script:ConfigFingerprint = [BitConverter]::ToString($hasher.ComputeHash([IO.File]::ReadAllBytes($Script:ConfigPath))) } finally { $hasher.Dispose() }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}

function Test-IsPazFolder([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return $false }
    return (Test-Path -LiteralPath (Join-Path $path 'pad00000.meta'))
}

function Test-PackReady {
    $need = @(
        (Join-Path $Script:PackDir 'midnight_xyzw.cmd'),
        (Join-Path $Script:PackDir 'midnight_xyzw\midnight_xyzw.py'),
        (Join-Path $Script:PackDir 'PartCutGen.exe'),
        (Join-Path $Script:PackDir 'Meta Injector.exe')
    )
    $missing = @($need | Where-Object { -not (Test-Path -LiteralPath $_) })
    return @{
        Ok      = ($missing.Count -eq 0)
        Missing = $missing
        PackDir = $Script:PackDir
    }
}

function Test-GraphicsReady {
    $missing = @($Script:GameOptionTool | Where-Object { -not (Test-Path -LiteralPath $_) })
    foreach ($name in $Script:GraphicsProfiles.Keys) {
        $p = Join-Path $Script:GraphicsDir $name
        if (-not (Test-Path -LiteralPath $p)) { $missing += $p }
    }
    return @{
        Ok           = ($missing.Count -eq 0)
        Missing      = $missing
        GraphicsDir  = $Script:GraphicsDir
    }
}

function Get-BdoDocumentsFolder {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    return (Join-Path $docs 'Black Desert')
}

function Get-BundledNipPath {
    return (Join-Path $Script:NvidiaDir $Script:NipFileName)
}

function Test-NipReady {
    $p = Get-BundledNipPath
    return @{
        Ok  = (Test-Path -LiteralPath $p)
        Path = $p
    }
}

function Find-NvidiaProfileInspector {
    # 1) User-saved path in config
    $cfg = if ($Script:Config -and $Script:Config.PSObject.Properties['npiPath']) { [string]$Script:Config.npiPath } else { '' }
    if ($cfg -and (Test-Path -LiteralPath $cfg)) { return $cfg }

    # 2) Bundled with this AIO (preferred for publish)
    $bundled = Join-Path $Script:Root 'tools\nvidiaProfileInspector\nvidiaProfileInspector.exe'
    if (Test-Path -LiteralPath $bundled) { return $bundled }

    # 3) Common install locations (this machine + generic)
    $candidates = @(
        (Join-Path $env:USERPROFILE 'Documents\Apps\NvidiaProfileInspector\nvidiaProfileInspector.exe'),
        (Join-Path $env:USERPROFILE 'Documents\Apps\NVIDIA Profile Inspector\nvidiaProfileInspector.exe'),
        (Join-Path $env:USERPROFILE 'Desktop\nvidiaProfileInspector\nvidiaProfileInspector.exe'),
        'C:\Tools\nvidiaProfileInspector\nvidiaProfileInspector.exe',
        'C:\Program Files\NVIDIA Profile Inspector\nvidiaProfileInspector.exe',
        'C:\Program Files (x86)\NVIDIA Profile Inspector\nvidiaProfileInspector.exe'
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }

    # 4) PATH
    $cmd = Get-Command nvidiaProfileInspector.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return $null
}

function Find-CommonPazCandidates {
    $hits = New-Object System.Collections.Generic.List[string]
    $roots = @(
        ${env:ProgramFiles(x86)},
        $env:ProgramFiles,
        'D:\',
        'E:\',
        'C:\Games',
        'C:\Program Files (x86)\Steam\steamapps\common',
        'C:\Program Files\Steam\steamapps\common',
        'C:\KakaoGames',
        'C:\Program Files (x86)\PearlAbyss'
    ) | Where-Object { $_ -and (Test-Path $_) }

    $names = @('BlackDesert', 'Black Desert Online', 'BlackDesertNA', 'BlackDesertEU', 'BDO')
    foreach ($root in $roots) {
        foreach ($n in $names) {
            $p = Join-Path (Join-Path $root $n) 'PAZ'
            if (Test-IsPazFolder $p) { [void]$hits.Add($p) }
        }
        try {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'BlackDesert|Black Desert|BDO' } |
                ForEach-Object {
                    $p = Join-Path $_.FullName 'PAZ'
                    if (Test-IsPazFolder $p) { [void]$hits.Add($p) }
                }
        } catch {}
    }
    return @($hits | Select-Object -Unique)
}

function Ensure-Python {
    param([switch]$ProbeOnly)
    if ($Script:PythonExe -and (Test-Path -LiteralPath $Script:PythonExe)) { return $true }

    $commands = @()
    if ($Script:Config -and $Script:Config.PSObject.Properties['pythonPath'] -and $Script:Config.pythonPath) {
        $commands += [pscustomobject]@{ Source = [string]$Script:Config.pythonPath }
    }
    $commands += @(Get-Command python.exe -All -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
        try {
            $resolved = & $command.Source -c 'import sys; print(sys.executable)' 2>$null
            $resolvedPath = [string](@($resolved)[-1])
            if ($LASTEXITCODE -eq 0 -and $resolvedPath -and (Test-Path -LiteralPath $resolvedPath)) {
                $Script:PythonExe = $resolvedPath
                Write-Ok ("Python found: " + $Script:PythonExe)
                return $true
            }
        } catch {}
    }

    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcher) {
        try {
            $resolved = & $launcher.Source -3 -c 'import sys; print(sys.executable)' 2>$null
            $resolvedPath = [string](@($resolved)[-1])
            if ($LASTEXITCODE -eq 0 -and $resolvedPath -and (Test-Path -LiteralPath $resolvedPath)) {
                $Script:PythonExe = $resolvedPath
                Write-Ok ("Python found through py launcher: " + $Script:PythonExe)
                return $true
            }
        } catch {}
    }

    $localPrograms = Join-Path $env:LOCALAPPDATA 'Programs\Python'
    if (Test-Path -LiteralPath $localPrograms) {
        $local = Get-ChildItem -LiteralPath $localPrograms -Filter python.exe -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($local) {
            $Script:PythonExe = $local.FullName
            Write-Ok ("Python found: " + $Script:PythonExe)
            return $true
        }
    }
    if ($ProbeOnly) { return $false }
    Write-Err 'Python is not installed (or not on PATH).'
    Write-Info 'Midnight deploy needs Python once (system install).'
    Write-Host '  Install with:  winget install Python.Python.3.12' -ForegroundColor White
    Write-Host '  Then close this window and run START.bat again.' -ForegroundColor White
    if (Read-YesNo 'Open winget install now?' $true) {
        try {
            Start-Process winget -ArgumentList @('install', '-e', '--id', 'Python.Python.3.12', '--accept-package-agreements', '--accept-source-agreements') -Wait
        } catch {
            Write-Warn 'Could not launch winget. Install Python from python.org or Microsoft Store.'
        }
        $py2 = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($py2) {
            $Script:PythonExe = $py2.Source
            Write-Ok ("Python is available now: " + $Script:PythonExe)
            return $true
        }
    }
    return $false
}

function Invoke-BdoPythonChecked {
    param(
        [object[]]$Arguments,
        [string]$Label = 'Python tool'
    )
    try {
        # stdout is diagnostic text, not part of this function's Boolean result.
        & $Script:PythonExe @Arguments | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Err ("$Label failed with exit code $LASTEXITCODE")
            return $false
        }
        return $true
    } catch {
        Write-Err ("$Label failed: " + $_.Exception.Message)
        return $false
    }
}

function Test-BdoToolsIdle {
    $running = @(Get-Process -Name 'BlackDesert*', 'BDOLauncher', 'PearlAbyssLauncher', 'PartCutGen', 'Meta Injector', 'Meta Patcher' -ErrorAction SilentlyContinue)
    if ($running.Count) {
        Write-Err ('Close the game, launcher and other patch tools first: ' + (($running.ProcessName | Select-Object -Unique) -join ', '))
        return $false
    }
    return $true
}

function Show-DevModeHint {
    Write-Info 'Optional: enable Windows Developer Mode for faster deploy (symlinks instead of huge copies).'
    Write-Host '  Settings -> System -> For developers -> Developer Mode = On' -ForegroundColor DarkGray
}

function Get-GenderLabel([string]$code) {
    if ($Script:GenderMap.Contains($code)) { return $Script:GenderMap[$code] }
    return $code
}

function Get-ArmorLabel([string]$code) {
    if ($Script:ArmorMap.Contains($code)) { return $Script:ArmorMap[$code] }
    return $code
}

function Get-PazStatusReport {
    param([string]$PazFolder)
    if (-not (Test-IsPazFolder $PazFolder)) { return $null }
    if (-not (Test-Path -LiteralPath $Script:PazStatusTool)) { return $null }
    if (-not (Ensure-Python)) { return $null }
    try {
        $json = & $Script:PythonExe $Script:PazStatusTool --paz $PazFolder --json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $json) { return $null }
        return ($json | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Show-PazInjectStatus {
    param(
        [string]$PazFolder,
        [switch]$Detailed
    )
    Write-Host ''
    Write-Host '  PAZ inject status (stock vs modded)' -ForegroundColor White
    Write-Host '  -----------------------------------' -ForegroundColor DarkGray
    if (-not (Test-IsPazFolder $PazFolder)) {
        Write-Warn '  Set a valid PAZ folder first (menu 1).'
        return
    }
    if (-not (Test-Path -LiteralPath $Script:PazStatusTool)) {
        Write-Warn '  paz_status_scan.py missing.'
        return
    }
    if (-not (Ensure-Python)) { return }

    if ($Detailed) {
        & $Script:PythonExe $Script:PazStatusTool --paz $PazFolder --write-status auto
        return
    }

    $rep = Get-PazStatusReport -PazFolder $PazFolder
    if (-not $rep) {
        Write-Warn '  Could not scan PAZ status.'
        return
    }

    $overall = [string]$rep.overall
    $metaState = [string]$rep.meta.state
    $col = switch -Wildcard ($overall) {
        '*STOCK*' { 'Green' }
        '*RESTORED*' { 'Green' }
        '*STAGED only*' { 'Yellow' }
        '*INJECTED*' { 'Magenta' }
        default { 'Cyan' }
    }
    Write-Host ("  OVERALL : " + $overall) -ForegroundColor $col
    if ($rep.overall_detail) {
        Write-Host ("           " + $rep.overall_detail) -ForegroundColor DarkGray
    }
    Write-Host ("  META    : " + $metaState) -ForegroundColor $(if ($metaState -eq 'MODDED') { 'Magenta' } elseif ($metaState -in @('STOCK', 'RESTORED')) { 'Green' } else { 'Yellow' })
    if ($rep.meta.detail) {
        Write-Host ("           " + $rep.meta.detail) -ForegroundColor DarkGray
    }
    $bc = 0
    if ($rep.backups) { $bc = @($rep.backups).Count }
    Write-Host ("  Backups : " + $bc + " Meta Injector *.meta.backup file(s)") -ForegroundColor Gray
    if ($rep.files_to_patch -and $rep.files_to_patch.exists) {
        Write-Host ("  Staged  : files_to_patch has " + $rep.files_to_patch.total_files + " file(s)") -ForegroundColor Gray
        if ($rep.files_to_patch.aio_packages) {
            foreach ($p in @($rep.files_to_patch.aio_packages)) {
                Write-Host ("           AIO: " + $p.name + " (" + $p.files + " files)") -ForegroundColor DarkCyan
            }
        }
    } else {
        Write-Host '  Staged  : no files_to_patch content' -ForegroundColor Gray
    }
    if ($rep.experimental_dlss -and $rep.experimental_dlss.installed) {
        Write-Host '  Exper.  : OptiScaler/DLSS inject MARKED in game root  [EXPERIMENTAL]' -ForegroundColor Red
    } else {
        Write-Host '  Exper.  : no experimental client inject marker' -ForegroundColor Gray
    }
    Write-Host '  Full report: menu [S]  |  Restore inject: Meta Injector "Restore Backup" or menu [R]' -ForegroundColor DarkGray
}

function Show-Status {
    Write-Host '  Current setup' -ForegroundColor White
    Write-Host '  -------------' -ForegroundColor DarkGray

    $pack = Test-PackReady
    if ($pack.Ok) {
        Write-Ok ("Pack      : " + $Script:PackDir + "  (bundled)")
    } else {
        Write-Err ("Pack      : incomplete under " + $Script:PackDir)
        foreach ($m in $pack.Missing) {
            Write-Warn ("  missing: " + $m)
        }
    }

    $paz = [string]$Script:Config.pazFolder
    if (Test-IsPazFolder $paz) {
        Write-Ok ("Game PAZ  : " + $paz)
        Show-PazInjectStatus -PazFolder $paz
    } elseif ($paz) {
        Write-Warn ("Game PAZ  : " + $paz + "  (pad00000.meta missing - check path)")
    } else {
        Write-Warn 'Game PAZ  : not set (user game folder only - not bundled)'
    }

    $gfx = Test-GraphicsReady
    if ($gfx.Ok) {
        Write-Ok ("Graphics  : " + $Script:GraphicsDir + "  (3 safe GameOption merge patches)")
    } else {
        Write-Warn ("Graphics  : incomplete under " + $Script:GraphicsDir)
    }

    $nip = Test-NipReady
    $npi = Find-NvidiaProfileInspector
    if ($nip.Ok) {
        Write-Ok ("NVIDIA NIP: " + $nip.Path)
    } else {
        Write-Warn ("NVIDIA NIP: missing " + $Script:NipFileName)
    }
    if ($npi) {
        Write-Ok ("NPI app   : " + $npi)
    } else {
        Write-Warn 'NPI app   : nvidiaProfileInspector.exe not found (menu N can browse)'
    }

    $optiDll = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.dll'
    if (Test-Path -LiteralPath $optiDll) {
        Write-Host '  [EXPERIMENTAL] DLSS/OptiScaler pack present  -> menu [X]  NOT SAFE' -ForegroundColor Red
    } else {
        Write-Warn 'Experimental DLSS pack missing under experimental\dlss\'
    }

    $g = [string]$Script:Config.gender
    $a = [string]$Script:Config.armor
    $x = [bool]$Script:Config.xyzwCollections
    Write-Host ("  Gender   : " + $g + " (" + (Get-GenderLabel $g) + ")") -ForegroundColor Gray
    Write-Host ("  Armor    : " + $a + " (" + (Get-ArmorLabel $a) + ")") -ForegroundColor Gray
    $xyzwText = if ($x) { 'Yes' } else { 'No' }
    Write-Host ("  Collections (XYZW outfits): " + $xyzwText) -ForegroundColor Gray
    try {
        Write-Host ("  Body size: " + [string]$Script:Config.bodySizePreset) -ForegroundColor Gray
        Write-Host ("  Body parts: " + (Format-BodySizeSpec (Get-BodySizeSpec))) -ForegroundColor Gray
    } catch {
        Write-Host '  Body size: (configure in menu 2)' -ForegroundColor Gray
    }
    Write-Host ''
}

function Set-PazFolder {
    Write-Banner
    Write-Host '  Set game PAZ folder' -ForegroundColor White
    Write-Host '  -------------------' -ForegroundColor DarkGray
    Write-Info 'This is YOUR Black Desert install (not inside this AIO folder).'
    Write-Info 'It must contain pad00000.meta'
    Write-Host ''

    $cands = @(Find-CommonPazCandidates)
    if ($cands.Count -gt 0) {
        Write-Host '  Found possible PAZ folders:' -ForegroundColor White
        for ($i = 0; $i -lt $cands.Count; $i++) {
            Write-Host ("    [" + ($i + 1) + "] " + $cands[$i]) -ForegroundColor Cyan
        }
        Write-Host '    [M] Type path manually' -ForegroundColor Cyan
        Write-Host '    [B] Browse with folder dialog' -ForegroundColor Cyan
        Write-Host '    [0] Cancel' -ForegroundColor DarkGray
        $pick = Read-Host '  Choice'
        if ($pick -eq '0') { return }
        if ($pick -match '^\d+$') {
            $idx = [int]$pick - 1
            if ($idx -ge 0 -and $idx -lt $cands.Count) {
                $Script:Config.pazFolder = $cands[$idx]
                Save-Config
                Write-Ok ("Saved PAZ: " + $Script:Config.pazFolder)
                Pause-Any
                return
            }
        }
        if ($pick -match '^[Mm]$') {
            $manual = (Read-Host '  Full path to PAZ folder').Trim().Trim('"')
            if (Test-IsPazFolder $manual) {
                $Script:Config.pazFolder = $manual
                Save-Config
                Write-Ok ("Saved PAZ: " + $Script:Config.pazFolder)
            } else {
                Write-Err 'That path does not look like a valid PAZ folder (pad00000.meta missing).'
            }
            Pause-Any
            return
        }
        if ($pick -notmatch '^[Bb]$') {
            Write-Warn 'Invalid choice.'
            Pause-Any
            return
        }
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Select your Black Desert PAZ folder (contains pad00000.meta)'
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $p = $dlg.SelectedPath
            if (Test-IsPazFolder $p) {
                $Script:Config.pazFolder = $p
                Save-Config
                Write-Ok ("Saved PAZ: " + $p)
            } else {
                Write-Err 'Selected folder is not a valid PAZ (pad00000.meta missing).'
            }
        }
    } catch {
        $manual = (Read-Host '  Folder dialog failed. Type full PAZ path').Trim().Trim('"')
        if (Test-IsPazFolder $manual) {
            $Script:Config.pazFolder = $manual
            Save-Config
            Write-Ok ("Saved PAZ: " + $Script:Config.pazFolder)
        } else {
            Write-Err 'Invalid PAZ path.'
        }
    }
    Pause-Any
}

function Configure-ModChoices {
    Write-Banner
    Write-Host '  OPTIONS HUB  (clearly labeled by origin)' -ForegroundColor White
    Write-Host '  ========================================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Labels:' -ForegroundColor White
    Write-Host '    MODERN      = current Midnight / 2026 pipeline (recommended)' -ForegroundColor Cyan
    Write-Host '    RESTORED            = classic feature with NATIVE assets only' -ForegroundColor Green
    Write-Host '    EXPERIMENTAL        = from-scratch (DLSS inject) — not a classic restore' -ForegroundColor Red
    Write-Host ''

    Write-Host '  --- MODERN (Midnight) ---' -ForegroundColor Cyan
    Write-Host '   [1] Gender + armor hide + collections' -ForegroundColor Cyan
    Write-Host ''

    Write-Host '  --- RESTORED (classic / NATIVE assets) ---' -ForegroundColor Green
    Write-Host '   [2] Body size LIMITS (Max ceilings only + custom)  [RESTORED]' -ForegroundColor Green
    Write-Host '   [3] Apply body size patch now' -ForegroundColor Green
    Write-Host '   [4] Slot hide (gloves/boots/helmets/weapons/stockings)  [RESTORED]' -ForegroundColor Green
    Write-Host '   [5] Apply slot hide patch now' -ForegroundColor Green
    Write-Host '   [6] Pubic hair style  [RESTORED = native bins only by default]' -ForegroundColor Green
    Write-Host '   [7] Apply pubic hair now' -ForegroundColor Green
    Write-Host '   [C] Censorship tier presets  [RESTORED / old outfit textures]' -ForegroundColor Green
    Write-Host '   [V] Penis / 3D vagina  [RESTORED = authored meshes only]' -ForegroundColor Green
    Write-Host ''

    Write-Host '   [X] DLSS/OptiScaler inject hub  *** NOT SAFE / FROM-SCRATCH ***' -ForegroundColor Red
    Write-Host ''

    Write-Host '  --- TOOLS / INFO ---' -ForegroundColor Yellow
    Write-Host '   [8] Feature origin matrix (modern / restored / experimental)' -ForegroundColor Yellow
    Write-Host '   [0] Back' -ForegroundColor DarkGray
    Write-Host ''
    $c = (Read-Host '  Select').Trim().ToUpperInvariant()
    switch ($c) {
        '1' { Configure-MidnightChoices }
        '2' { Configure-BodySizeLimits }
        '3' { Apply-BodySizePatch }
        '4' { Configure-SlotHide }
        '5' { Apply-SlotHidePatch }
        '6' { Configure-PubicHair }
        '7' { Apply-PubicHair }
        'C' { Configure-CensorshipTier }
        'V' { Configure-GenitalMenus }
        'X' { Show-ExperimentalDlssMenu }
        '8' { Show-OptionsMatrix }
        default { return }
    }
}

function Configure-CensorshipTier {
    Write-Banner
    Write-Host '  CENSORSHIP TIER PRESETS' -ForegroundColor Magenta
    Write-Host '  ----------------------' -ForegroundColor DarkGray
    Write-Info 'Legacy = classic Resorepless outfit textures. Expanded = live PAZ under-armor scan.'
    Write-Info 'Blanks are rebuilt from YOUR client, not from the 2018 pack, so size,'
    Write-Info 'format and mips always match. Only alpha-carrying maps (DXT5/DXT3) are'
    Write-Info 'blanked - zeroing those is transparent. DXT1 has no alpha to zero, so'
    Write-Info 'blanking one would paint BLACK over the body; those are skipped.'
    Write-Warn 'This removes painted-on underwear only. The nude body comes from Midnight'
    Write-Warn '(Suzu / TheGreatSage) + the 3D genital packs - keep those on.'
    Write-Host ''
    Write-Host '    [0] Off' -ForegroundColor DarkGray
    Write-Host '    [1] Minimal  — a few Tamer built-in panties' -ForegroundColor Cyan
    Write-Host '    [2] Medium   — + upper undercovers / more decals  (~10 files)' -ForegroundColor Green
    Write-Host '    [3] High     — same target list as medium' -ForegroundColor Cyan
    Write-Host '    [4] Expanded — medium + every *_dec* / under* map in the live PAZ' -ForegroundColor Yellow
    Write-Host '                  (~236 files, all classes; never clip masks)' -ForegroundColor DarkYellow
    $t = Read-Choice 'Tier' @('0', '1', '2', '3', '4')
    $Script:Config.censorshipTier = switch ($t) {
        '0' { 'off' }
        '1' { 'minimal' }
        '2' { 'medium' }
        '3' { 'high' }
        '4' { 'expanded' }
    }
    Save-Config
    Write-Ok ("Censorship tier: " + $Script:Config.censorshipTier)
    if ($Script:Config.censorshipTier -ne 'off' -and (Read-YesNo 'Apply censorship texture pack now?' $true)) {
        Apply-CensorshipPack
    } else {
        Pause-Any
    }
}

function Apply-CensorshipPack {
    param([switch]$NoPrompt)
    Write-Banner
    Write-Host '  Apply censorship pack' -ForegroundColor Magenta
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set PAZ first.'; if (-not $NoPrompt) { Pause-Any }; return $false }
    $tier = [string]$Script:Config.censorshipTier
    if (-not $tier -or $tier -eq 'off') { Write-Warn 'Tier is off.'; if (-not $NoPrompt) { Pause-Any }; return $false }
    if (-not (Test-Path $Script:CensorshipRoot)) { Write-Err "Missing $($Script:CensorshipRoot)"; if (-not $NoPrompt) { Pause-Any }; return $false }
    if (-not (Ensure-Python)) { if (-not $NoPrompt) { Pause-Any }; return $false }
    $out = Join-Path $Script:Config.pazFolder ("files_to_patch\_censorship_" + $tier)
    Write-Info ("tier=$tier out=$out")
    if (-not $NoPrompt -and -not (Read-YesNo 'Copy / expand texture pack?' $true)) { Pause-Any; return $false }
    $pyArgs = @(
        $Script:CensorshipTool, '--tier', $tier,
        '--pack-root', $Script:CensorshipRoot, '--out', $out,
        '--paz', [string]$Script:Config.pazFolder
    )
    if ($tier -eq 'expanded') {
        Write-Warn 'Expanded scans full meta (can take a minute)...'
    }
    $ok = Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Censorship pack'
    if ($ok) { Write-Ok 'Censorship pack ready. Meta Inject after Midnight.'; Ensure-ToolsInPaz } else { Write-Err "Exit $LASTEXITCODE" }
    if (-not $NoPrompt) { Pause-Any }
    return $ok
}

function Read-PenisStyle([string]$label, [string]$current) {
    Write-Host ''
    Write-Host ("  " + $label + " penis style  (current: " + $current + ")") -ForegroundColor White
    Write-Host '    [0] none   [1] normal   [2] hard' -ForegroundColor Cyan
    $c = Read-Choice 'Style' @('0', '1', '2')
    return $(switch ($c) { '0' { 'none' } '1' { 'normal' } '2' { 'hard' } })
}

# The [F] NEW FEMALES hub was removed in 2.1.1. Every class it targeted now has
# no supported genital path: a genital PAC carries the donor's body and skin, so
# reusing one gave those classes the wrong body. Pubic hair for them is handled
# by the normal per-class menu (shared-texture group, one style).

function Configure-GenitalMenus {
    Write-Banner
    Write-Host '  PENIS / 3D VAGINA' -ForegroundColor Magenta
    Write-Host '  ================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Authored meshes only — the classes that shipped a real Resorepless mesh.' -ForegroundColor Green
    Write-Host '  Newer classes are not offered: a genital PAC carries the donor body AND' -ForegroundColor DarkGray
    Write-Host '  skin, so reusing one gave them the wrong body. Removed in 2.1.1.' -ForegroundColor DarkGray
    Write-Warn 'Penis skin tone often mismatches. Shai never included.'
    Write-Host ''
    Write-Host '  --- FEMALE 3D vagina ---' -ForegroundColor Green
    $Script:Config.female3dVagina = Read-YesNo 'Enable female 3D vagina packs?' ([bool]$Script:Config.female3dVagina)
    if ([bool]$Script:Config.female3dVagina) {
        Write-Host ''
        Write-Host '  Only these 10 classes have an authored 3D-vagina mesh:' -ForegroundColor Gray
        Write-Host ('    ' + (($Script:GenitalFemalePrefixes | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
        Write-Host '  Newer classes are not offered: a genital PAC carries the donor body' -ForegroundColor DarkGray
        Write-Host '  AND skin, so reusing one gave them the wrong body. Removed in 2.1.1.' -ForegroundColor DarkGray
        $Script:Config.genitalFemaleClasses = Select-FemaleClasses -Title '3D vagina — which females?' -CurrentCsv ([string]$Script:Config.genitalFemaleClasses) -DefaultAll -Supported $Script:GenitalFemalePrefixes
        $asked = @(([string]$Script:Config.genitalFemaleClasses) -split '[,;]+' | Where-Object { $_ })
        $unsupported = @($asked | Where-Object { $_ -notin $Script:GenitalFemalePrefixes })
        if ($unsupported.Count -gt 0) {
            Write-Warn ('No authored mesh, skipped: ' + (($unsupported | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', '))
            $Script:Config.genitalFemaleClasses = (@($asked | Where-Object { $_ -in $Script:GenitalFemalePrefixes }) -join ',')
        }
        $Script:Config.genitalReuse = $false
    } else {
        $Script:Config.genitalFemaleClasses = ''
        $Script:Config.genitalReuse = $false
    }

    Write-Host ''
    Write-Host '  MALE — native penis meshes only (Warrior/Berserker/Musa/Wizard/Ninja/Striker)' -ForegroundColor White
    Write-Host '    [1] All native males same style' -ForegroundColor Green
    Write-Host '    [2] Per-class styles (those 6 only)' -ForegroundColor Cyan
    Write-Host '    [3] All off' -ForegroundColor DarkGray
    $m = Read-Choice 'Male mode' @('1', '2', '3')
    if ($m -eq '3') {
        $Script:Config.malePenisMode = 'none'
        foreach ($k in @('penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker')) {
            $Script:Config.$k = 'none'
        }
    } elseif ($m -eq '1') {
        $all = Read-PenisStyle 'All native males' $(if ($Script:Config.malePenisMode -in @('normal', 'hard')) { $Script:Config.malePenisMode } else { 'normal' })
        $Script:Config.malePenisMode = $all
        foreach ($k in @('penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker')) {
            $Script:Config.$k = $all
        }
    } else {
        $Script:Config.malePenisMode = 'perclass'
        $Script:Config.penisWarrior = Read-PenisStyle 'Warrior' ([string]$Script:Config.penisWarrior)
        $Script:Config.penisBerserker = Read-PenisStyle 'Berserker' ([string]$Script:Config.penisBerserker)
        $Script:Config.penisMusa = Read-PenisStyle 'Musa' ([string]$Script:Config.penisMusa)
        $Script:Config.penisWizard = Read-PenisStyle 'Wizard' ([string]$Script:Config.penisWizard)
        $Script:Config.penisNinja = Read-PenisStyle 'Ninja' ([string]$Script:Config.penisNinja)
        $Script:Config.penisStriker = Read-PenisStyle 'Striker' ([string]$Script:Config.penisStriker)
    }

    Save-Config
    Write-Ok 'Genital options saved.'
    Write-Host ("  female3dVagina         = " + $Script:Config.female3dVagina) -ForegroundColor Gray
    Write-Host ("  female classes        = " + (Format-ClassList $Script:Config.genitalFemaleClasses)) -ForegroundColor Gray
    Write-Host ("  malePenisMode         = " + $Script:Config.malePenisMode) -ForegroundColor Gray
    if (Read-YesNo 'Apply genital packs to files_to_patch now?' $true) {
        Apply-GenitalPacks
    } else {
        Pause-Any
    }
}

function Apply-GenitalPacks {
    Write-Banner
    Write-Host '  Apply genital packs' -ForegroundColor Magenta
    Write-Host '  Authored meshes only; classes without one are skipped with a reason' -ForegroundColor DarkGray
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set PAZ first.'; Pause-Any; return }
    if (-not (Test-Path $Script:GenitalRoot)) { Write-Err "Missing $($Script:GenitalRoot)"; Pause-Any; return }
    if (-not (Ensure-Python)) { Pause-Any; return }

    $f3d = if ([bool]$Script:Config.female3dVagina) { 'on' } else { 'off' }
    $maleArg = 'none'
    if ([string]$Script:Config.malePenisMode -eq 'perclass') {
        $parts = @(
            "warrior=$($Script:Config.penisWarrior)",
            "berserker=$($Script:Config.penisBerserker)",
            "musa=$($Script:Config.penisMusa)",
            "wizard=$($Script:Config.penisWizard)",
            "ninja=$($Script:Config.penisNinja)",
            "striker=$($Script:Config.penisStriker)"
        )
        $maleArg = $parts -join ','
    } elseif ([string]$Script:Config.malePenisMode -in @('normal', 'hard')) {
        $maleArg = [string]$Script:Config.malePenisMode
    }

    if ($f3d -eq 'off' -and $maleArg -eq 'none') {
        Write-Warn 'Nothing enabled.'
        Pause-Any
        return
    }

    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_genital_RESTORED_native'
    Write-Info ("female_3d=$f3d male=$maleArg")
    Write-Info 'mode=NATIVE only (authored meshes; classes without one are skipped)'
    Write-Info ("out=$out")
    if (-not (Read-YesNo 'Copy genital packs?' $true)) { Pause-Any; return }

    $fClasses = [string]$Script:Config.genitalFemaleClasses
    $pyArgs = @(
        $Script:GenitalTool,
        '--pack-root', $Script:GenitalRoot,
        '--out', $out,
        '--paz', [string]$Script:Config.pazFolder,
        '--female-3d-vagina', $f3d,
        '--male-penis', $maleArg
    )
    if ($fClasses) { $pyArgs += @('--female-classes', $fClasses) }

    Write-Info ("female classes = " + (Format-ClassList $fClasses))
    & $Script:PythonExe @pyArgs
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Err "Exit $LASTEXITCODE" } else {
        Write-Ok 'Genital packs written. Deploy Midnight underwear hide too, then Meta Inject + PartCutGen.'
        Ensure-ToolsInPaz
    }
    Pause-Any
}

function Configure-SlotHide {
    Write-Banner
    Write-Host '  SLOT HIDE TOGGLES (extra dummy-mesh hides)' -ForegroundColor White
    Write-Host '  ------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Independent of Midnight All/Pearl/Free. Hides matching .pac models from live PAZ.'
    Write-Info 'Uses gender filter from your Midnight gender setting (F/M/B).'
    Write-Host ''
    Write-Host ("  Current: gloves={0} boots={1} helmets={2} weapons={3} stockings={4}" -f `
        $Script:Config.hideGloves, $Script:Config.hideBoots, $Script:Config.hideHelmets, $Script:Config.hideWeapons, $Script:Config.hideStockings) -ForegroundColor DarkCyan
    Write-Host ("  Classes : " + $(if ([string]$Script:Config.slotHideClasses) { $Script:Config.slotHideClasses } else { 'ALL' })) -ForegroundColor DarkCyan
    Write-Host ''
    $Script:Config.hideGloves = Read-YesNo 'Hide GLOVES / hands gear?' ([bool]$Script:Config.hideGloves)
    $Script:Config.hideBoots = Read-YesNo 'Hide BOOTS / shoes?' ([bool]$Script:Config.hideBoots)
    $Script:Config.hideHelmets = Read-YesNo 'Hide HELMETS (may affect some hair/hel combos)?' ([bool]$Script:Config.hideHelmets)
    $Script:Config.hideWeapons = Read-YesNo 'Hide WEAPONS (main/sub/awakening meshes)?' ([bool]$Script:Config.hideWeapons)
    $Script:Config.hideStockings = Read-YesNo 'Hide STOCKINGS (best-effort name match)?' ([bool]$Script:Config.hideStockings)
    Write-Host ''
    Write-Host '  Optional PER-CLASS filter (leave empty = all classes):' -ForegroundColor Yellow
    Write-Host '  Examples: pdkl          (Seraph only)' -ForegroundColor DarkGray
    Write-Host '            phw,pew,pdw   (Sorceress, Ranger, Dark Knight)' -ForegroundColor DarkGray
    Write-Host '            phm,pcm       (Warrior, Striker weapons only if weapons on)' -ForegroundColor DarkGray
    $cls = Read-Host '  Class prefixes (comma-separated, blank=ALL)'
    if ($null -eq $cls) { $cls = '' }
    $Script:Config.slotHideClasses = $cls.Trim()
    Save-Config
    Write-Ok 'Slot hide flags saved.'
    if (Read-YesNo 'Apply slot hide patch now (scans live PAZ)?' $true) {
        Apply-SlotHidePatch
    } else {
        Pause-Any
    }
}

function Get-EnabledHideSlots {
    $slots = @()
    if ([bool]$Script:Config.hideGloves) { $slots += 'gloves' }
    if ([bool]$Script:Config.hideBoots) { $slots += 'boots' }
    if ([bool]$Script:Config.hideHelmets) { $slots += 'helmets' }
    if ([bool]$Script:Config.hideWeapons) { $slots += 'weapons' }
    if ([bool]$Script:Config.hideStockings) { $slots += 'stockings' }
    return $slots
}

function Apply-SlotHidePatch {
    param([switch]$NoPrompt)
    Write-Banner
    Write-Host '  Apply slot hide patch' -ForegroundColor White
    Write-Host '  ---------------------' -ForegroundColor DarkGray
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first (menu 1).'
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    $slots = @(Get-EnabledHideSlots)
    if ($slots.Count -eq 0) {
        Write-Warn 'No slots enabled. Turn some on in menu 2 option 4 first.'
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    if (-not (Test-Path -LiteralPath $Script:SlotHideTool)) {
        Write-Err ("Missing " + $Script:SlotHideTool)
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    if (-not (Ensure-Python)) { if (-not $NoPrompt) { Pause-Any }; return $false }

    $gender = [string]$Script:Config.gender
    if ($gender -notin @('F', 'M', 'B')) { $gender = 'B' }
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch'
    $cls = [string]$Script:Config.slotHideClasses
    Write-Info ("Slots  : " + ($slots -join ', '))
    Write-Info ("Gender : " + $gender)
    Write-Info ("Classes: " + $(if ($cls) { $cls } else { 'ALL' }))
    Write-Info ("Output : " + $out)
    Write-Warn 'Scans full meta (can take a minute). Then run PartCutGen + Meta Injector.'
    if (-not $NoPrompt -and -not (Read-YesNo 'Run slot hide patcher?' $true)) { Pause-Any; return $false }

    $pyArgs = @(
        $Script:SlotHideTool,
        '--paz', [string]$Script:Config.pazFolder,
        '--out', $out,
        '--slots', ($slots -join ','),
        '--gender', $gender
    )
    if ($cls) { $pyArgs += @('--classes', $cls) }
    $ok = $false
    try {
        if (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Slot hide patcher') {
            Write-Ok 'Slot hide folders written under files_to_patch\_slot_hide_*'
            Ensure-ToolsInPaz
            $ok = $true
        }
    } catch {
        Write-Err $_.Exception.Message
    }
    if (-not $NoPrompt) { Pause-Any }
    return $ok
}

function Configure-PubicHair {
    Write-Banner
    Write-Host '  PUBIC HAIR' -ForegroundColor Magenta
    Write-Host '  ==========' -ForegroundColor DarkGray
    Write-Host '  Texture-only, and what you can pick is decided by the game files:' -ForegroundColor Green
    Write-Host ''
    Write-Host '   STYLED ONE BY ONE - these 5 own their body texture:' -ForegroundColor Green
    Write-Host ('     ' + (($Script:PubicPrivateAtlasPrefixes | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor Gray
    Write-Host '   ONE STYLE FOR ALL 13 - these share a single texture (phw_01_nude_0001):' -ForegroundColor Yellow
    Write-Host ('     ' + (($Script:SharedAtlasPrefixes | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
    Write-Host '     Styling that one file styles every one of them, so they get the same' -ForegroundColor DarkGray
    Write-Host '     look or stay bare. Giving them separate textures needs a material' -ForegroundColor DarkGray
    Write-Host '     rename inside the body PAC, which is what made bodies invisible in 2.1.0.' -ForegroundColor DarkGray
    Write-Host '   Corsair owns its texture but no shipped hair bin fits it; it is offered' -ForegroundColor DarkGray
    Write-Host '   and will report "no compatible hair bin" if nothing matches.' -ForegroundColor DarkGray
    Write-Host ''
    if (-not (Test-Path -LiteralPath (Join-Path $Script:PubicHairRoot 'offsets.bin'))) {
        Write-Err ("Pubic hair pack missing: " + $Script:PubicHairRoot)
        Write-Info 'Expected tools\pubic_hair\ from Resorepless resources.'
        Pause-Any
        return
    }

    Write-Host '  Pick the classes you want, then a style for each one.' -ForegroundColor Gray
    Write-Host '  Classes you do not pick are left completely untouched.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '    [I] IMMERSIVE preset (recommended) — a different look per class' -ForegroundColor Green
    Write-Host '    [C] Choose classes and styles yourself' -ForegroundColor Cyan
    Write-Host '    [P] Open preview image first' -ForegroundColor Yellow
    Write-Host '    [X] Clear pubic hair selection' -ForegroundColor DarkGray
    $mode = (Read-Host '  Choice').Trim().ToUpperInvariant()
    if ($mode -eq 'I') {
        Write-Host ''
        Write-Host '  IMMERSIVE preset' -ForegroundColor Green
        Write-Host '  ----------------' -ForegroundColor DarkGray
        Write-Host '  Individually styled (these classes own their body texture):' -ForegroundColor Gray
        $picked = [ordered]@{}
        foreach ($p in $Script:PubicImmersivePreset.Keys) {
            $picked[$p] = $Script:PubicImmersivePreset[$p]
            $label = if ($Script:FemaleClasses.Contains($p)) { $Script:FemaleClasses[$p] } else { $p }
            Write-Host ("    {0,-20} {1}" -f $label, $Script:PubicHairStyles[$Script:PubicImmersivePreset[$p]]) -ForegroundColor Gray
        }
        Show-PubicIsolationNotice $picked
        Write-Host ''
        Write-Host '  The other 13 classes all render from ONE shared texture:' -ForegroundColor Yellow
        Write-Host ('    ' + (($Script:SharedAtlasPrefixes | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
        Write-Host '  They can only have ONE style between them, or stay bare.' -ForegroundColor DarkGray
        Write-Host ''
        if (Read-YesNo 'Give that whole group of 13 a style too?' $false) {
            $styleKeys = @($Script:PubicHairStyles.Keys | Where-Object { $_ -ne 'none' })
            for ($i = 0; $i -lt $styleKeys.Count; $i++) {
                Write-Host ("    [{0}] {1}" -f ($i + 1), $Script:PubicHairStyles[$styleKeys[$i]]) -ForegroundColor Cyan
            }
            while ($true) {
                $ans = (Read-Host '  Style number for all 13').Trim()
                if ($ans -notmatch '^\d+$') { Write-Warn 'Enter a number.'; continue }
                $n = [int]$ans
                if ($n -lt 1 -or $n -gt $styleKeys.Count) { Write-Warn 'Out of range.'; continue }
                foreach ($p in $Script:SharedAtlasPrefixes) { $picked[$p] = $styleKeys[$n - 1] }
                break
            }
        } else {
            Write-Info 'Those 13 stay bare (not touched at all).'
        }
        Write-Host ''
        if (-not (Read-YesNo 'Use this preset?' $true)) { Pause-Any; return }
        $Script:Config.pubicHairStyles = (($picked.Keys |
            ForEach-Object { '{0}={1}' -f $_, $picked[$_] }) -join ',')
        $Script:Config.pubicHairClasses = ($picked.Keys -join ',')
        $Script:Config.pubicHairStyle = @($picked.Values)[0]
        Save-Config
        Write-Ok 'Immersive preset saved.'
        if (Read-YesNo 'Apply pubic hair textures now?' $true) { Apply-PubicHair } else { Pause-Any }
        return
    }
    if ($mode -eq 'P') {
        $prev = Join-Path $Script:PubicHairRoot 'preview.jpg'
        if (Test-Path $prev) { Start-Process $prev } else { Write-Warn 'preview.jpg missing' }
        Pause-Any
        Configure-PubicHair
        return
    }
    if ($mode -eq 'X') {
        $Script:Config.pubicHairStyles = ''
        $Script:Config.pubicHairStyle = 'none'
        $Script:Config.pubicHairClasses = ''
        Save-Config
        Write-Ok 'Pubic hair selection cleared.'
        Pause-Any
        return
    }
    if ($mode -ne 'C') {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    $classes = Select-FemaleClasses -Title 'Pubic hair — pick classes' -CurrentCsv (Get-PubicClassCsv)
    if ([string]::IsNullOrWhiteSpace($classes)) {
        Write-Warn 'No classes selected — nothing will be generated.'
        $Script:Config.pubicHairStyles = ''
        $Script:Config.pubicHairStyle = 'none'
        $Script:Config.pubicHairClasses = ''
        Save-Config
        Pause-Any
        return
    }

    $existing = Get-PubicStyleMap
    $picked = [ordered]@{}
    $styleKeys = @($Script:PubicHairStyles.Keys | Where-Object { $_ -ne 'none' })
    $lastChoice = 0

    Write-Host ''
    Write-Host '  --- STYLE PER CLASS ---' -ForegroundColor White
    Write-Host '  Enter a style number for each class. Blank repeats your previous answer.' -ForegroundColor DarkGray
    Write-Host '  Enter 0 to skip that class entirely.' -ForegroundColor DarkGray
    Write-Host ''
    for ($i = 0; $i -lt $styleKeys.Count; $i++) {
        Write-Host ("    [{0}] {1}" -f ($i + 1), $Script:PubicHairStyles[$styleKeys[$i]]) -ForegroundColor Cyan
    }
    Write-Host ''

    foreach ($prefix in ($classes -split '[,;]+')) {
        $prefix = $prefix.Trim()
        if (-not $prefix) { continue }
        $label = if ($Script:FemaleClasses.Contains($prefix)) { $Script:FemaleClasses[$prefix] } else { $prefix }
        $default = $lastChoice
        if ($existing.Contains($prefix)) {
            $idx = [array]::IndexOf($styleKeys, $existing[$prefix])
            if ($idx -ge 0) { $default = $idx + 1 }
        }
        while ($true) {
            $hint = if ($default -gt 0) { " [$default]" } else { '' }
            $ans = (Read-Host ("  " + $label + " (" + $prefix + ")" + $hint)).Trim()
            if (-not $ans -and $default -gt 0) { $ans = "$default" }
            if ($ans -notmatch '^\d+$') { Write-Warn 'Enter a number.'; continue }
            $n = [int]$ans
            if ($n -eq 0) { break }
            if ($n -lt 1 -or $n -gt $styleKeys.Count) { Write-Warn 'Out of range.'; continue }
            $picked[$prefix] = $styleKeys[$n - 1]
            $lastChoice = $n
            break
        }
    }

    if ($picked.Count -eq 0) {
        Write-Warn 'Every class was skipped — nothing will be generated.'
        $Script:Config.pubicHairStyles = ''
        $Script:Config.pubicHairStyle = 'none'
        $Script:Config.pubicHairClasses = ''
        Save-Config
        Pause-Any
        return
    }

    $Script:Config.pubicHairStyles = (($picked.Keys | ForEach-Object { '{0}={1}' -f $_, $picked[$_] }) -join ',')
    # Kept in sync so older status screens and the run-all path stay meaningful.
    $Script:Config.pubicHairClasses = (($picked.Keys) -join ',')
    $Script:Config.pubicHairStyle = @($picked.Values)[0]
    Save-Config

    Write-Host ''
    Write-Ok 'Pubic hair selection saved:'
    foreach ($p in $picked.Keys) {
        $label = if ($Script:FemaleClasses.Contains($p)) { $Script:FemaleClasses[$p] } else { $p }
        Write-Host ("    {0,-14} {1}" -f $label, $Script:PubicHairStyles[$picked[$p]]) -ForegroundColor Gray
    }
    Show-PubicIsolationNotice $picked
    if (Read-YesNo 'Apply pubic hair textures now?' $true) {
        Apply-PubicHair
    } else {
        Pause-Any
    }
}

# Selected classes -> ordered map of prefix=style, from the saved config.
function Get-PubicStyleMap {
    $map = [ordered]@{}
    foreach ($token in ([string]$Script:Config.pubicHairStyles -split '[,;]+')) {
        $token = $token.Trim()
        if (-not $token) { continue }
        $bits = $token -split '=', 2
        if ($bits.Count -ne 2) { continue }
        $p = $bits[0].Trim().ToLowerInvariant()
        $s = $bits[1].Trim().ToLowerInvariant()
        if ($p -and $s -and $Script:PubicHairStyles.Contains($s)) { $map[$p] = $s }
    }
    return $map
}

function Get-PubicClassCsv {
    return ((Get-PubicStyleMap).Keys -join ',')
}

function Get-PubicStylesArg {
    $map = Get-PubicStyleMap
    if ($map.Count -eq 0) { return $null }
    return (($map.Keys | ForEach-Object { '{0}={1}' -f $_, $map[$_] }) -join ',')
}

# 13 of 19 female bodies render from ONE texture (phw_01_nude_0001). Tell the user
# what that costs before they generate, instead of surprising them with GB of files.
# Warns about selections the assets cannot satisfy, BEFORE anything is generated.
function Show-PubicIsolationNotice {
    param($Picked)
    # Corsair's texture is a size no shipped hair bin matches, so it cannot be
    # styled at all. Say so up front rather than letting it look like a failure.
    if ($Picked.Contains('pfw')) {
        Write-Host ''
        Write-Warn 'Corsair has no compatible hair bin in this pack and will be skipped.'
    }
    $shared = @($Picked.Keys | Where-Object { $_ -in $Script:SharedAtlasPrefixes })
    if ($shared.Count -eq 0) { return }

    $missing = @($Script:SharedAtlasPrefixes | Where-Object { -not $Picked.Contains($_) })
    $styles = @($shared | ForEach-Object { $Picked[$_] } | Select-Object -Unique)
    if ($missing.Count -eq 0 -and $styles.Count -eq 1) {
        Write-Host ''
        Write-Info ('All 13 shared-texture classes selected with one style — they will all get ' + $Script:PubicHairStyles[$styles[0]] + '.')
        return
    }
    Write-Host ''
    Write-Warn 'These picked classes all render from ONE shared body texture, so they'
    Write-Warn 'cannot have different styles and WILL BE SKIPPED:'
    Write-Host ('    ' + (($shared | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
    if ($styles.Count -gt 1) {
        Write-Host ('    conflicting styles requested: ' + ($styles -join ', ')) -ForegroundColor DarkGray
    }
    if ($missing.Count -gt 0) {
        Write-Host ('    not selected, would also be changed: ' + (($missing | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
    }
    Write-Host '    To style them, pick ALL 13 with the SAME style.' -ForegroundColor DarkGray
}

function Apply-PubicHair {
    Write-Banner
    Write-Host '  Apply pubic hair' -ForegroundColor Magenta
    Write-Host '  Per-class styles; unselected classes are left untouched' -ForegroundColor DarkGray
    $stylesArg = Get-PubicStylesArg
    if (-not $stylesArg) {
        Write-Warn 'No classes selected — pick classes and styles first (menu 2 option 6).'
        Pause-Any
        return
    }
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first.'
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) { Pause-Any; return }

    $baseRoots = @(
        (Join-Path $Script:Root 'pack\midnight_xyzw\_00_suzu_nude'),
        (Join-Path $Script:Root 'pack\midnight_xyzw\_00_thegreatsage_nude')
    ) -join ';'
    # One package for the whole selection: a per-style folder would leave the
    # previous run's package behind and re-inject classes you just deselected.
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_pubic_hair_perclass'
    Write-Info ("Selection : " + $stylesArg)
    Write-Info ("Out       : " + $out)
    if (-not (Read-YesNo 'Merge hair bins onto nude DDS and write files_to_patch?' $true)) {
        Pause-Any
        return
    }
    Remove-StalePubicPackages
    $pyArgs = @(
        $Script:PubicHairTool,
        '--hair-root', $Script:PubicHairRoot,
        '--base-roots', $baseRoots,
        '--out', $out,
        '--paz', [string]$Script:Config.pazFolder,
        '--styles', $stylesArg
    )
    try {
        & $Script:PythonExe @pyArgs
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Err ("Exit " + $LASTEXITCODE)
        } else {
            Write-Ok 'Pubic hair textures ready. Meta Inject after Midnight deploy (nude body first).'
            Ensure-ToolsInPaz
        }
    } catch {
        Write-Err $_.Exception.Message
    }
    Pause-Any
}

# Old builds wrote one package per style/mode, so switching style or narrowing the
# class list left the previous package in files_to_patch and it kept getting
# injected. That is the other half of "I picked two classes and got all of them".
function Remove-StalePubicPackages {
    $ftp = Join-Path $Script:Config.pazFolder 'files_to_patch'
    if (-not (Test-Path -LiteralPath $ftp)) { return }
    $resolvedStage = [IO.Path]::GetFullPath($ftp).TrimEnd('\')
    $archiveRoot = $null
    $stale = @(Get-ChildItem -LiteralPath $ftp -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '_pubic_hair_*' -and $_.Name -ne '_pubic_hair_perclass' })
    foreach ($dir in $stale) {
        try {
            $target = [IO.Path]::GetFullPath($dir.FullName)
            if ([IO.Path]::GetDirectoryName($target) -ne $resolvedStage) { throw 'Stale package is outside the staging folder.' }
            if (-not $archiveRoot) {
                $archiveRoot = Join-Path ([string]$Script:Config.pazFolder) ('BDO_AIO_STAGE_BACKUPS\stale-pubic-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
                $null = New-Item -ItemType Directory -Path $archiveRoot -Force
            }
            Move-Item -LiteralPath $target -Destination (Join-Path $archiveRoot $dir.Name) -ErrorAction Stop
            Write-Info ("Archived stale pubic package: " + $dir.Name)
        } catch {
            Write-Warn ("Could not archive " + $dir.Name + ": " + $_.Exception.Message)
        }
    }
    if ($archiveRoot) { Write-Info ("Stale pubic packages retained at: " + $archiveRoot) }
}

function Configure-MidnightChoices {
    Write-Banner
    Write-Host '  Midnight hide / nude options' -ForegroundColor White
    Write-Host '  ----------------------------' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  WHO should armor/underwear removal apply to?' -ForegroundColor White
    Write-Host '    [F] Female only     (most common)' -ForegroundColor Cyan
    Write-Host '    [M] Male only' -ForegroundColor Cyan
    Write-Host '    [B] Both genders' -ForegroundColor Cyan
    $Script:Config.gender = Read-Choice 'Gender letter' @('F', 'M', 'B')

    Write-Host ''
    Write-Host '  WHICH outfits should become transparent / stripped?' -ForegroundColor White
    Write-Host '    [A] All armors and outfits (includes gloves/boots/helmets/stockings)' -ForegroundColor Cyan
    Write-Host '    [P] Pearl Shop only' -ForegroundColor Cyan
    Write-Host '    [F] Free / non-cash only' -ForegroundColor Cyan
    Write-Host '    [U] Underwear hide only (keep armor meshes)' -ForegroundColor Cyan
    Write-Host ''
    Write-Info 'Nude base body (Suzu + TheGreatSage) is always included.'
    Write-Info 'Underwear removal for the gender you picked is always included.'
    $Script:Config.armor = Read-Choice 'Armor letter' @('A', 'P', 'F', 'U')

    Write-Host ''
    Write-Host '  EXTRA outfit packs (XYZW collections)?' -ForegroundColor White
    $Script:Config.xyzwCollections = Read-YesNo 'Include XYZW collection mods?' $true

    Save-Config
    Write-Ok 'Midnight choices saved.'
    Pause-Any
}

function Read-FloatValue {
    param(
        [string]$Prompt,
        [double]$Default,
        [double]$MinAllowed = -5.0,
        [double]$MaxAllowed = 10.0
    )
    while ($true) {
        Write-Host ''
        $raw = (Read-Host ("  " + $Prompt + " [default " + ("{0:0.##}" -f $Default) + "]")).Trim()
        if ([string]::IsNullOrEmpty($raw)) { return $Default }
        $raw = $raw.Replace(',', '.')
        $val = 0.0
        if (-not [double]::TryParse($raw, [ref]$val)) {
            Write-Warn 'Enter a number (example: 2.5 or 1.0)'
            continue
        }
        if ($val -lt $MinAllowed -or $val -gt $MaxAllowed) {
            Write-Warn ("Value out of safe range " + $MinAllowed + " .. " + $MaxAllowed + " (you can still type again)")
            if (-not (Read-YesNo ("Use " + $val + " anyway?") $false)) { continue }
        }
        return $val
    }
}

# The schema-2 string is the single source of truth: region.axis:max pairs.
function Get-BodySizeSpec {
    return Convert-BodySizeSpec ([string]$Script:Config.bodySizeParts)
}

function Format-BodySizeSpec {
    param($Spec)
    if (-not $Spec) { return '(none)' }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    return (($Spec.Keys | ForEach-Object { $_ + ' max ' + ([double]$Spec[$_]).ToString('0.##', $culture) }) -join ', ')
}

function Get-BodySizeArg {
    $spec = Get-BodySizeSpec
    if (-not $spec) { return $null }
    return ConvertTo-BodySizeSpecString $spec
}



function Configure-BodySizeLimits {
    Write-Banner
    Write-Host '  BODY SIZE MAX CEILINGS  [axis-aware, all classes]' -ForegroundColor White
    Write-Host '  -------------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Raises selected Max slider ceilings only. It never forces a body shape.'
    Write-Info 'Min and Default remain exactly as authored by the game.'
    Write-Warn 'After injection, test in Beauty Salon or on a new character.'
    Write-Host ''
    Write-BodySizeRestoreSafetyNotice -Context 'body-size'
    Write-Host ''
    Write-Host '  RECOMMENDED AXES' -ForegroundColor White
    Write-Host '    Breasts          X/Y/Z  1.55' -ForegroundColor Green
    Write-Host '    Thighs            Y/Z    1.35  (X leg length untouched)' -ForegroundColor Green
    Write-Host '    Butt cheeks       X/Y/Z  1.20  (cheek shape / roundness, not overall ass size)' -ForegroundColor Green
    Write-Host '    Front pelvis      Y/Z    1.40  (Z drives overall pelvis / ass size; X untouched)' -ForegroundColor Green
    Write-Host '    Belly/lower back  X      1.28  (intentional HeightAxis exception)' -ForegroundColor Yellow
    Write-Host '                       Z      1.45  (last belly-depth slider; Y untouched)' -ForegroundColor Green
    Write-Host ''
    Write-Host '  [1] RECOMMENDED' -ForegroundColor Green
    Write-Host '  [2] CUSTOM       choose every supported axis separately' -ForegroundColor Magenta
    Write-Host '  [3] Keep current' -ForegroundColor DarkGray
    $choice = Read-Choice 'Choice' @('1', '2', '3')

    switch ($choice) {
        '1' {
            $Script:Config.bodySizeSchema = $Script:BodySizeSchema
            $Script:Config.bodySizePreset = 'recommended'
            $Script:Config.bodySizeParts = $Script:BodySizeRecommendedSpec
        }
        '2' {
            Write-Host ''
            Write-Host '  Butt cheeks change cheek shape / roundness, not overall ass size.' -ForegroundColor Cyan
            Write-Host '  pelvis.z is the main overall pelvis / ass-size control; it affects front groin and rear.' -ForegroundColor Cyan
            Write-Host ''
            Write-Host '  CUSTOM BREAST AXES' -ForegroundColor White
            Write-Host '    X = length / forward projection' -ForegroundColor Cyan
            Write-Host '    Y = width' -ForegroundColor Cyan
            Write-Host '    Z = height' -ForegroundColor Cyan
            Write-Host '    Observed stock peak is uneven: X 1.30, Y/Z 1.55.' -ForegroundColor Yellow
            Write-Host '    These are independent ceilings, not a required anatomical ratio.' -ForegroundColor Gray
            Write-Host '    Balanced absolute:  1.55 / 1.55 / 1.55' -ForegroundColor Green
            Write-Host '    Equal +0.20 test:   1.50 / 1.75 / 1.75' -ForegroundColor Cyan
            Write-Host '    Equal +0.25 test:   1.55 / 1.80 / 1.80' -ForegroundColor Cyan
            Write-Host '    Different classes and meshes can react differently.' -ForegroundColor Yellow
            Write-Host ''

            $current = Get-BodySizeSpec
            $chosen = [ordered]@{}
            $groups = [ordered]@{
                'Breasts' = @('breasts.x', 'breasts.y', 'breasts.z')
                'Thighs (X leg length is protected)' = @('thighs.y', 'thighs.z')
                'Butt cheeks' = @('butt.x', 'butt.y', 'butt.z')
                'Front pelvis / groin (X length is protected)' = @('pelvis.y', 'pelvis.z')
                'Belly / lower back (Y is untouched)' = @('belly.x', 'belly.z')
            }
            foreach ($group in $groups.Keys) {
                Write-Host ('  ' + $group) -ForegroundColor White
                foreach ($axisKey in $groups[$group]) {
                    $default = [double]$Script:BodySizeAxisDefaults[$axisKey]
                    if ($current -and $current.Contains($axisKey)) { $default = [double]$current[$axisKey] }
                    if (-not (Read-YesNo ('Patch ' + $axisKey + '?') $true)) { continue }
                    $value = Read-FloatValue -Prompt ($axisKey + ' Max ceiling') -Default $default -MinAllowed 1.0 -MaxAllowed 5.0
                    if ($axisKey -eq 'belly.x') {
                        Write-Warn 'belly.x intentionally changes the Spine X HeightAxis; it can lengthen the lower torso and move the groin down.'
                        if ($value -gt 1.28 -and -not (Read-YesNo ('Keep belly.x ' + $value + ' above Recommended 1.28?') $false)) {
                            $value = 1.28
                        }
                    }
                    if ($axisKey -eq 'pelvis.z') {
                        Write-Info 'pelvis.z mainly controls overall pelvis / ass size; it affects the front groin and rear.'
                    }
                    if ($axisKey.StartsWith('butt.') -and $value -gt 1.20) {
                        Write-Warn 'Butt values above 1.20 can pyramid-spike lower-cheek polygons on some classes.'
                        if (-not (Read-YesNo ('Keep ' + $axisKey + ' ' + $value + '?') $false)) { $value = 1.20 }
                    }
                    $chosen[$axisKey] = $value
                }
                Write-Host ''
            }
            if ($chosen.Count -eq 0) {
                Write-Err 'Nothing selected - keeping the previous body-size settings.'
            } else {
                $Script:Config.bodySizeSchema = $Script:BodySizeSchema
                $Script:Config.bodySizePreset = 'custom'
                $Script:Config.bodySizeParts = ConvertTo-BodySizeSpecString $chosen
                Write-Ok ('Custom saved: ' + (Format-BodySizeSpec $chosen))
            }
        }
        '3' { Write-Info 'Keeping existing settings.' }
    }

    Save-Config
    Write-Host ''
    Write-Ok 'Body size settings saved.'
    Write-Host ('  Preset : ' + [string]$Script:Config.bodySizePreset) -ForegroundColor Gray
    Write-Host ('  Applies: ' + (Format-BodySizeSpec (Get-BodySizeSpec))) -ForegroundColor Gray
    Write-Host '  Restore is unnecessary when keeping/raising the same axes.' -ForegroundColor DarkGray
    Write-Host '  Restore once before an exact Recommended test if an older injection used' -ForegroundColor Yellow
    Write-Host '  breasts above 1.55 or widened Belly Y, because widen-only cannot undo them.' -ForegroundColor Yellow
    Write-Host ''
    if (Read-YesNo 'Apply body size patch to game files_to_patch now?' $true) {
        Apply-BodySizePatch
    } else {
        Pause-Any
    }
}

function Apply-BodySizePatch {
    Write-Banner
    Write-Host '  Apply body size limit patch' -ForegroundColor White
    Write-Host '  ---------------------------' -ForegroundColor DarkGray

    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set game PAZ first (menu 1).'
        Pause-Any
        return
    }
    if (-not (Test-Path -LiteralPath $Script:BodySizeTool)) {
        Write-Err ("Missing tool: " + $Script:BodySizeTool)
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) {
        Pause-Any
        return
    }

    $parts = Get-BodySizeArg
    if (-not $parts) {
        Write-Err 'No usable body parts configured. Re-run menu 2 body size config.'
        Pause-Any
        return
    }
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_body_size_limits'

    Write-Info ("PAZ     : " + $Script:Config.pazFolder)
    Write-Info ("Preset  : " + $Script:Config.bodySizePreset)
    Write-Info ("Applies : " + (Format-BodySizeSpec (Get-BodySizeSpec)))
    Write-Info ("Output  : " + $out)
    Write-Warn 'Extracts ~75 customizationboneparamdesc.xml from live game (takes a minute).'
    if (-not (Read-YesNo 'Run body size patcher with these values?' $true)) {
        Pause-Any
        return
    }

    # The parts string carries each part's own max, so this is the only knob.
    $pyArgs = @(
        $Script:BodySizeTool,
        '--paz', [string]$Script:Config.pazFolder,
        '--out', $out,
        '--parts', $parts
    )
    try {
        & $Script:PythonExe @pyArgs
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Err ("Patcher exit code " + $LASTEXITCODE)
        } else {
            Write-Ok 'Body size files written under files_to_patch\_body_size_limits'
            Write-Info 'Next: Meta Injector, then beauty salon or new character to use the new max.'
            Ensure-ToolsInPaz
        }
    } catch {
        Write-Err $_.Exception.Message
    }
    Pause-Any
}

function Show-OptionsMatrix {
    Write-Banner
    Write-Host '  FEATURE ORIGIN MATRIX' -ForegroundColor White
    Write-Host '  =====================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  MODERN (Midnight / recommended pipeline)' -ForegroundColor Cyan
    Write-Host '  ---------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Gender F/M/Both; armor All/Pearl/Free/Underwear-only'
    Write-Host '  Nude body through Seraph; live-regenerated armor/underwear hide includes Wukong (not Shai)'
    Write-Host '  XYZW collections; PartCutGen + Meta Injector'
    Write-Host '  GameOption profiles [G]; NVIDIA .nip [N]'
    Write-Host ''
    Write-Host '  RESTORED (classic Resorepless-era, re-wired in this AIO)' -ForegroundColor Green
    Write-Host '  -------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Body size min/default/max (presets + custom numbers)'
    Write-Host '  Slot hide: gloves / boots / helmets / weapons / stockings'
    Write-Host '  Pubic hair styles (old texture bins)'
    Write-Host '  Censorship tiers minimal/medium/high (old outfit textures)'
    Write-Host '  Penis none/normal/hard + 3D vagina (old class meshes)'
    Write-Host '  Old Resorepless UI omitted: its restored features are native AIO options'
    Write-Host ''
    Write-Host '  EXPERIMENTAL (from-scratch in BDO-AIO — NOT a classic restore)' -ForegroundColor Red
    Write-Host '  -------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  [X] OptiScaler / Streamline / DLSS-style inject  *** NOT SAFE ***'
    Write-Host '      Lives under experimental\dlss\ only. Separate from RESTORED packs.'
    Write-Host '      May be flagged by anti-cheat. Not from Resorepless/Midnight.'
    Write-Host ''
    Write-Host '  RESTORED but LIMITED on modern content' -ForegroundColor Yellow
    Write-Host '  --------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Genital / pubic / censorship packs: best on older classes/outfits'
    Write-Host '  Penis skin-tone mismatch (classic issue)'
    Write-Host ''
    Write-Host '  Not supported on newer classes' -ForegroundColor Yellow
    Write-Host '  ------------------------------' -ForegroundColor DarkGray
    Write-Host '  Seraph / Deadeye / Woosa / Maegu / Scholar / Nova / Corsair /'
    Write-Host '  Drakania / Guardian have no authored genital mesh. Reusing another'
    Write-Host '  class''s gave them that class''s body AND skin, so it was removed in 2.1.1.'
    Write-Host ''
    Write-Host '  NOT SUPPORTED' -ForegroundColor DarkGray
    Write-Host '  -------------' -ForegroundColor DarkGray
    Write-Host '  Shai nude; anti-cheat stealth; inventing new high-quality body meshes'
    Write-Host '  Dosa/Wukong male genital donor reuse (no verified compatible mesh)'
    Write-Host ''
    Pause-Any
}

function Ensure-ToolsInPaz {
    $paz = [string]$Script:Config.pazFolder
    if (-not (Test-IsPazFolder $paz)) { return }

    foreach ($name in @('PartCutGen.exe', 'Meta Injector.exe')) {
        $dest = Join-Path $paz $name
        $src = Join-Path $Script:PackDir $name
        if (Test-Path -LiteralPath $dest) {
            Write-Ok ("Tool present in game PAZ: " + $name)
            continue
        }
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $dest -Force
            Write-Ok ("Copied " + $name + " from pack into game PAZ")
        } else {
            Write-Warn ("Missing in pack: " + $src)
        }
    }
}

function Test-BdoToolkitInstalled {
    $gac = Join-Path $env:windir 'Microsoft.NET\assembly\GAC_MSIL\BDOToolkit\v4.0_1.3.0.0__e09839e68adb5566\BDOToolkit.dll'
    if (Test-Path -LiteralPath $gac) { return $true }
    if (-not $Script:Config.pazFolder) { return $false }
    $local = Join-Path ([string]$Script:Config.pazFolder) 'BDOToolkit.dll'
    return (Test-Path -LiteralPath $local)
}

function Deploy-Midnight {
    param([switch]$NoPrompt)
    if (-not (Test-BdoToolsIdle)) { Pause-Any; return $false }
    Write-Banner
    Write-Host '  Step 1 - Deploy mods to files_to_patch' -ForegroundColor White
    Write-Host '  --------------------------------------' -ForegroundColor DarkGray

    $pack = Test-PackReady
    if (-not $pack.Ok) {
        Write-Err 'Bundled pack is incomplete. Re-download the full AIO release zip.'
        foreach ($m in $pack.Missing) { Write-Warn ("  " + $m) }
        Pause-Any
        return $false
    }

    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set a valid game PAZ folder first (menu option 1).'
        Pause-Any
        return $false
    }
    if (-not (Ensure-Python)) {
        Pause-Any
        return $false
    }
    Show-DevModeHint
    Write-Host ''

    $pyScript = Join-Path $Script:PackDir 'midnight_xyzw\midnight_xyzw.py'
    $g = [string]$Script:Config.gender
    $a = [string]$Script:Config.armor
    $xyzwArg = if ([bool]$Script:Config.xyzwCollections) { '--xyzw' } else { '--no-xyzw' }

    Write-Info ("Pack     : " + $Script:PackDir)
    Write-Info ("Target   : " + $Script:Config.pazFolder)
    Write-Info ("Args     : -g " + $g + " -a " + $a + " " + $xyzwArg + " --yes")
    Write-Host ''
    if (-not $NoPrompt -and -not (Read-YesNo 'Deploy now?' $true)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return $false
    }

    $pyArgs = @(
        '-x', $pyScript,
        '-g', $g,
        '-a', $a,
        $xyzwArg,
        '--yes',
        [string]$Script:Config.pazFolder
    )

    Write-Host ''
    Write-Info 'Running Midnight deploy (first run can take a while)...'
    try {
        if (-not (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Midnight deploy')) {
            Pause-Any
            return $false
        }
    } catch {
        Write-Err $_.Exception.Message
        Pause-Any
        return $false
    }

    $ftp = Join-Path $Script:Config.pazFolder 'files_to_patch'
    if (Test-Path -LiteralPath $ftp) {
        Write-Ok ("Deployed. Folder ready: " + $ftp)
    } else {
        Write-Warn 'files_to_patch not found after deploy - check console output above.'
        return $false
    }

    Ensure-ToolsInPaz
    Save-Config
    Pause-Any
    return $true
}

function Run-PartCutGen {
    Write-Banner
    Write-Host '  PartCutGen - rebuild part-cut exclusions' -ForegroundColor White
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set PAZ first.'; Pause-Any; return $false }
    if (-not (Test-BdoToolsIdle)) { Pause-Any; return $false }
    Ensure-ToolsInPaz
    $exe = Join-Path $Script:Config.pazFolder 'PartCutGen.exe'
    if (-not (Test-Path -LiteralPath $exe)) { Write-Err ("Missing: " + $exe); Pause-Any; return $false }
    Write-Info 'Follow the prompts in PartCutGen. This step waits for it to finish.'
    $ok = $false
    try {
        # PartCutGen requires a real console; redirected input/output breaks it.
        $process = Start-Process -FilePath $exe -WorkingDirectory $Script:Config.pazFolder -PassThru -Wait
        try {
            if ($process.ExitCode -ne 0) { throw ("PartCutGen exited with code " + $process.ExitCode + '. Do not inject.') }
        } finally { $process.Dispose() }
        $output = Join-Path $Script:Config.pazFolder 'files_to_patch\_PartCutGen\character\partcutdesc.xml'
        if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { throw 'PartCutGen produced no partcutdesc.xml. Do not inject.' }
        # Exit zero alone cannot distinguish generation from choosing Quit.
        $ok = Read-YesNo 'Did PartCutGen report successful generation (no error)?' $false
        if ($ok) { Write-Ok 'PartCutGen finished; you can proceed to injection.' }
        else { Write-Warn 'Apply stopped before injection. Check the PartCutGen output.' }
    } catch { Write-Err $_.Exception.Message }
    Pause-Any
    return $ok
}

function Get-FreeBdoDriveLetter {
    foreach ($code in 90..68) {
        $drive = ([char]$code).ToString() + ':'
        if (-not (Test-Path -LiteralPath ($drive + '\'))) { return $drive }
    }
    throw 'No free temporary drive letter is available.'
}

function Mount-BdoTemporaryDrive {
    param([string]$Target)
    $drive = Get-FreeBdoDriveLetter
    & "$env:SystemRoot\System32\subst.exe" $drive $Target | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath ($drive + '\'))) {
        throw "Could not create temporary short-path drive $drive for $Target"
    }
    return $drive
}

function Dismount-BdoTemporaryDrive {
    param([string]$Drive)
    if ($Drive) { & "$env:SystemRoot\System32\subst.exe" $Drive /D 2>$null | Out-Null }
}

function Prepare-BdoInjectStage {
    param(
        [string]$PazDrive,
        [string]$SourceDrive,
        [string]$ReportPath = ''
    )
    if (-not (Test-Path -LiteralPath $Script:InjectStageTool)) {
        throw "Missing canonical stage builder: $Script:InjectStageTool"
    }
    $stage = $PazDrive + '\BDO_AIO_INJECT'
    Write-Info 'Building canonical injection tree (all collections kept; organizer folders flattened)...'
    $builderArgs = @(
        $Script:InjectStageTool,
        '--paz', ($PazDrive + '\'),
        '--source', ($SourceDrive + '\'),
        '--stage', $stage
    )
    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        $builderArgs += @('--report', $ReportPath)
    }
    & $Script:PythonExe @builderArgs | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "Canonical injection stage failed with exit code $LASTEXITCODE. No injection was started."
    }
    return $stage
}

function Run-MetaInjector {
    Write-Banner
    Write-Host '  Meta Injector - apply and verify' -ForegroundColor White
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set a valid PAZ folder first.'; Pause-Any; return $false }
    if (-not (Test-BdoToolsIdle)) { Pause-Any; return $false }
    if (-not (Ensure-Python)) { Pause-Any; return $false }
    Ensure-ToolsInPaz
    $paz = [string]$Script:Config.pazFolder
    $source = Join-Path $paz 'files_to_patch'
    $exe = Join-Path $paz 'Meta Injector.exe'
    if (-not (Test-Path -LiteralPath $exe)) { Write-Err ("Missing: " + $exe); Pause-Any; return $false }
    if (-not (Test-BdoToolkitInstalled)) {
        Write-Err 'Meta Injector requires BDO Toolkit. Install it before applying.'
        Pause-Any
        return $false
    }
    if (-not (Test-Path -LiteralPath $source)) { Write-Err ("Missing: " + $source); Pause-Any; return $false }

    # A modified meta cannot tell us whether the user's choices changed.
    # Do not block reinjection or silently reuse a stage on that signal alone.
    $runId = [guid]::NewGuid().ToString('N')
    $reportDir = Join-Path $Script:Root 'logs'
    $reportPath = Join-Path $reportDir ('meta-inject-' + $runId + '.json')
    $Script:LastMetaInjectReportPath = $reportPath
    $stageReportPath = Join-Path $reportDir ('meta-inject-' + $runId + '-stage.json')
    $report = [ordered]@{
        schema = 1; launcherVersion = [string]$Script:Version
        runId = $runId; action = 'meta-inject'; state = 'started'
        startedAt = [DateTime]::UtcNow.ToString('o'); finishedAt = $null
        reportPath = $reportPath; targetPaz = $paz; source = $source
        stagePath = $null; stageReportPath = $stageReportPath
        clientVersionBefore = $null; clientVersionAfter = $null
        backupStartedAt = $null; backupFinishedAt = $null
        stageStartedAt = $null; stageFinishedAt = $null
        injectorStartedAt = $null; injectorFinishedAt = $null
        verifyStartedAt = $null; verifyFinishedAt = $null
        backupMs = $null; stageBuildMs = $null; injectorMs = $null; verifyMs = $null
        injectorExitCode = $null; verifyPassed = $null; error = $null
    }
    Write-Info ('Run report: ' + $reportPath)
    $pazDrive = $null
    $sourceDrive = $null
    $process = $null
    $passed = $false
    try {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $report['state'] = 'backup'
        $report['backupStartedAt'] = [DateTime]::UtcNow.ToString('o')
        Write-MetaInjectReport -Report $report -Path $reportPath
        $backupPassed = Invoke-VanillaRestoreTool @('backup')
        $report['backupFinishedAt'] = [DateTime]::UtcNow.ToString('o')
        $report['backupMs'] = $timer.ElapsedMilliseconds
        if (-not $backupPassed) {
            $report['state'] = 'backup-failed'
            throw 'No current-version vanilla snapshot is available. Injection was not started.'
        }
        $metaVersionBefore = Get-BdoMetaVersion -PazFolder $paz
        if (-not $metaVersionBefore) { throw 'Cannot read the current client version. Injection was not started.' }
        $report['clientVersionBefore'] = $metaVersionBefore
        Write-Info ("Client version before inject: " + $metaVersionBefore)
        $pazDrive = Mount-BdoTemporaryDrive -Target $paz
        $sourceDrive = Mount-BdoTemporaryDrive -Target $source
        $timer.Restart()
        $report['state'] = 'staging'
        $report['stageStartedAt'] = [DateTime]::UtcNow.ToString('o')
        Write-MetaInjectReport -Report $report -Path $reportPath
        $stage = [string](Prepare-BdoInjectStage -PazDrive $pazDrive -SourceDrive $sourceDrive -ReportPath $stageReportPath)
        $report['stagePath'] = $stage
        $report['stageFinishedAt'] = [DateTime]::UtcNow.ToString('o')
        $report['stageBuildMs'] = $timer.ElapsedMilliseconds
        $shortExe = $pazDrive + '\Meta Injector.exe'
        Write-Info 'Opening Meta Injector. Follow its prompts; archive saving can take time.'
        $timer.Restart()
        $report['state'] = 'injecting'
        $report['injectorStartedAt'] = [DateTime]::UtcNow.ToString('o')
        Write-MetaInjectReport -Report $report -Path $reportPath
        $process = Start-Process -FilePath $shortExe -WorkingDirectory ($pazDrive + '\') -ArgumentList ('-files "{0}"' -f $stage) -PassThru
        while (-not $process.WaitForExit(5000)) {
            Write-Info ("Meta Injector is running: {0}s elapsed. Check its window for prompts." -f [int]$timer.Elapsed.TotalSeconds)
        }
        $process.WaitForExit()
        $report['injectorFinishedAt'] = [DateTime]::UtcNow.ToString('o')
        $report['injectorMs'] = $timer.ElapsedMilliseconds
        $report['injectorExitCode'] = [int]$process.ExitCode
        $report['clientVersionAfter'] = Get-BdoMetaVersion -PazFolder $paz
        if ($process.ExitCode -ne 0) {
            $report['state'] = 'injector-failed'
            throw ("Meta Injector exited with code " + $process.ExitCode + '. Verify or restore the game before continuing.')
        }
        $timer.Restart()
        $report['state'] = 'verifying'
        $report['verifyStartedAt'] = [DateTime]::UtcNow.ToString('o')
        Write-MetaInjectReport -Report $report -Path $reportPath
        $verifyPassed = Invoke-VanillaRestoreTool @('verify', '--expect-version', [string]$metaVersionBefore)
        $report['verifyFinishedAt'] = [DateTime]::UtcNow.ToString('o')
        $report['verifyMs'] = $timer.ElapsedMilliseconds
        $report['verifyPassed'] = $verifyPassed
        if (-not $verifyPassed) {
            $report['state'] = 'verify-failed'
            throw 'The injected meta did not verify. Do not launch the game. Use Recovery to inspect or restore it.'
        }
        $Script:Config.lastMetaVersion = $metaVersionBefore
        Save-Config
        $region = Get-BdoClientRegion
        $metaPatcher = $pazDrive + '\Meta Patcher.exe'
        if ($region -in @('NA', 'EU')) {
            Write-Info ("Meta Patcher is not required for " + $region + '.')
        } elseif ($region) {
            Write-Warn ("Region " + $region + ': check the Meta Patcher requirements.')
            if (Test-Path -LiteralPath $metaPatcher) {
                if (Read-YesNo 'Run Meta Patcher now?' $true) {
                    $patcherProcess = Start-Process -FilePath $metaPatcher -WorkingDirectory ($pazDrive + '\') -PassThru -Wait
                    try {
                        if ($patcherProcess.ExitCode -ne 0) { throw ("Meta Patcher exited with code " + $patcherProcess.ExitCode) }
                    } finally { $patcherProcess.Dispose() }
                    # The patcher also writes the meta, invalidating the earlier check.
                    $report['verifyPassed'] = Invoke-VanillaRestoreTool @('verify', '--expect-version', [string]$metaVersionBefore)
                    if (-not $report['verifyPassed']) { $report['state'] = 'verify-failed'; throw 'Meta verification failed after Meta Patcher.' }
                }
            } else { Write-Warn 'Meta Patcher is not installed; confirm your regional requirements before launching.' }
        } else { Write-Warn 'Region is unknown. Meta Patcher was not run.' }
        $report['state'] = 'completed'
        $passed = $true
        Write-Ok 'Injector exited successfully; client version and archive references verified.'
        Write-Info 'This does not verify the appearance of mods in game.'
    } catch {
        if ($report['state'] -notlike '*-failed') { $report['state'] = 'error' }
        $report['error'] = $_.Exception.Message
        Write-Err $_.Exception.Message
        if ($report['injectorStartedAt']) { Write-Warn 'The external tool may have changed game files. Read the report before retrying.' }
    } finally {
        if ($process) { $process.Dispose() }
        Dismount-BdoTemporaryDrive -Drive $sourceDrive
        Dismount-BdoTemporaryDrive -Drive $pazDrive
        $report['finishedAt'] = [DateTime]::UtcNow.ToString('o')
        Write-MetaInjectReport -Report $report -Path $reportPath
    }
    Pause-Any
    return $passed
}

function Apply-AllRestoredChoices {
    param([switch]$NoPrompt)
    if (-not (Test-BdoToolsIdle)) { if (-not $NoPrompt) { Pause-Any }; return $false }
    Write-Banner
    Write-Host '  APPLY ALL RESTORED CHOICES' -ForegroundColor Green
    Write-Host '  ==========================' -ForegroundColor DarkGray
    Write-Info 'Runs enabled RESTORED options from config in order:'
    Write-Host '    body size -> slot hide -> pubic -> censorship -> genitals' -ForegroundColor Gray
    Write-Host ''
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first (menu 1).'
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    if (-not (Ensure-Python)) { if (-not $NoPrompt) { Pause-Any }; return $false }

    Write-Host '  From config:' -ForegroundColor White
    Write-Host ("    bodySizePreset = " + $Script:Config.bodySizePreset) -ForegroundColor Gray
    Write-Host ("    slots          = " + ((Get-EnabledHideSlots) -join ', ')) -ForegroundColor Gray
    Write-Host ("    slot classes   = " + $(if ($Script:Config.slotHideClasses) { $Script:Config.slotHideClasses } else { 'ALL' })) -ForegroundColor Gray
    Write-Host ("    pubic          = " + $(if (Get-PubicStylesArg) { Get-PubicStylesArg } else { 'none' })) -ForegroundColor Gray
    Write-Host ("    censorship     = " + $Script:Config.censorshipTier) -ForegroundColor Gray
    Write-Host ("    female3d       = " + $Script:Config.female3dVagina) -ForegroundColor Gray
    Write-Host ("    malePenisMode  = " + $Script:Config.malePenisMode) -ForegroundColor Gray
    Write-Host ''
    if (-not $NoPrompt -and -not (Read-YesNo 'Apply all enabled RESTORED packs now (no further prompts)?' $true)) {
        Pause-Any
        return $false
    }

    $paz = [string]$Script:Config.pazFolder
    $ftp = Join-Path $paz 'files_to_patch'
    if (-not (Test-Path $ftp)) { New-Item -ItemType Directory -Path $ftp -Force | Out-Null }
    # Rebuild the complete selected set: otherwise disabled options remain staged.
    # Keep previous generated packages outside the injector's input for recovery.
    [void](Clear-AioGenerated -Archive)
    $allOk = $true

    # 1) Body size — same single --parts argument as Apply-BodySizePatch
    if ($Script:Config.bodySizePreset -and $Script:Config.bodySizePreset -ne '') {
        Write-Info '--- Body size limits ---'
        $parts = Get-BodySizeArg
        if (-not $parts) {
            Write-Err 'Body size config is unusable.'
            $allOk = $false
        } else {
            Write-Info ("Applies : " + (Format-BodySizeSpec (Get-BodySizeSpec)))
            $out = Join-Path $ftp '_body_size_limits'
            $pyArgs = @(
                $Script:BodySizeTool, '--paz', $paz, '--out', $out,
                '--parts', $parts
            )
            if (-not (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Body size patcher')) { $allOk = $false }
        }
    }

    # 2) Slot hide
    $slots = @(Get-EnabledHideSlots)
    if ($slots.Count -gt 0) {
        Write-Info '--- Slot hide ---'
        if (-not (Apply-SlotHidePatch -NoPrompt)) { $allOk = $false }
    }

    # 3) Pubic hair — one package for the whole per-class selection
    $stylesArg = Get-PubicStylesArg
    if ($stylesArg) {
        Write-Info '--- Pubic hair ---'
        Write-Info ("  selection = " + $stylesArg)
        Remove-StalePubicPackages
        $out = Join-Path $ftp '_pubic_hair_perclass'
        $baseRoots = @(
            (Join-Path $Script:Root 'pack\midnight_xyzw\_00_suzu_nude'),
            (Join-Path $Script:Root 'pack\midnight_xyzw\_00_thegreatsage_nude')
        ) -join ';'
        $pyArgs = @(
            $Script:PubicHairTool, '--hair-root', $Script:PubicHairRoot,
            '--base-roots', $baseRoots, '--out', $out, '--paz', $paz,
            '--styles', $stylesArg
        )
        if (-not (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Pubic hair patcher')) { $allOk = $false }
    }


    # 5) Censorship
    if ([string]$Script:Config.censorshipTier -and $Script:Config.censorshipTier -ne 'off') {
        Write-Info '--- Censorship ---'
        if (-not (Apply-CensorshipPack -NoPrompt)) { $allOk = $false }
    }

    # 6) Genitals (native / all-class reuse)
    $f3d = [bool]$Script:Config.female3dVagina
    $maleMode = [string]$Script:Config.malePenisMode
    if (($f3d -or ($maleMode -and $maleMode -ne 'none')) -and (Test-Path -LiteralPath $Script:GenitalRoot)) {
        Write-Info '--- Genitals ---'
        $maleArg = 'none'
        if ($maleMode -eq 'perclass') {
            $maleArg = @(
                "warrior=$($Script:Config.penisWarrior)",
                "berserker=$($Script:Config.penisBerserker)",
                "musa=$($Script:Config.penisMusa)",
                "wizard=$($Script:Config.penisWizard)",
                "ninja=$($Script:Config.penisNinja)",
                "striker=$($Script:Config.penisStriker)"
            ) -join ','
        } elseif ($maleMode -in @('normal', 'hard')) {
            $maleArg = $maleMode
        }
        $out = Join-Path $ftp '_genital_RESTORED_native'
        $fClasses = [string]$Script:Config.genitalFemaleClasses
        $pyArgs = @(
            $Script:GenitalTool, '--pack-root', $Script:GenitalRoot, '--out', $out,
            '--paz', $paz,
            '--female-3d-vagina', $(if ($f3d) { 'on' } else { 'off' }),
            '--male-penis', $maleArg
        )
        if ($fClasses) { $pyArgs += @('--female-classes', $fClasses) }
        if (-not (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Genital patcher')) { $allOk = $false }
    } elseif ($f3d -or ($maleMode -and $maleMode -ne 'none')) {
        Write-Warn "Genital pack missing: $Script:GenitalRoot"
        $allOk = $false
    }

    # The old "new females EXPERIMENTAL genitals" pass is gone: it copied a donor
    # class's whole body PAC under a new class's name, giving that class the
    # donor's mesh and skin. Only authored meshes are generated now.

    # The old "new females EXPERIMENTAL pubic" pass wrote a SECOND pubic package
    # with its own class list in the same run, which re-applied hair to classes the
    # main pass had deliberately skipped. Every class now goes through step 3.

    Ensure-ToolsInPaz
    if ($allOk) {
        Write-Ok 'RESTORED batch finished. Run PartCutGen then Meta Injector.'
    } else {
        Write-Err 'RESTORED batch completed with one or more failed generators. Do not inject until fixed.'
    }
    if (-not $NoPrompt) { Pause-Any }
    return $allOk
}

function Get-HeishaRoot {
    $c = [string]$Script:Config.heishaRoot
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    if (Test-Path -LiteralPath $Script:DefaultHeishaRoot) { return $Script:DefaultHeishaRoot }
    $local = Join-Path $Script:Root 'heisha'
    if (Test-Path -LiteralPath $local) { return $local }
    return $null
}

function Show-HeishaRegenHelper {
    Write-Banner
    Write-Host '  POST-PATCH REGEN HELPER (heisha / Midnight)' -ForegroundColor Yellow
    Write-Host '  ===========================================' -ForegroundColor DarkGray
    Write-Info 'After a BDO client patch, Meta Injector may fail until packs are regenerated.'
    Write-Host ''
    Write-Host '  Recommended flow:' -ForegroundColor White
    Write-Host '    1. Open heisha (Midnight regenerator)' -ForegroundColor Cyan
    Write-Host '    2. setupenv.cmd  (once per machine)' -ForegroundColor Cyan
    Write-Host '    3. run.cmd -i <game\PAZ> -o .\PAZ\midnight_xyzw -m all' -ForegroundColor Cyan
    Write-Host '    4. Copy regenerated pack into this AIO pack\midnight_xyzw  (or re-point)' -ForegroundColor Cyan
    Write-Host '    5. AIO menu 3 deploy -> 4 PartCutGen -> 5 Meta Injector' -ForegroundColor Cyan
    Write-Host '    6. Optional: menu A apply all RESTORED choices' -ForegroundColor Cyan
    Write-Host ''

    $root = Get-HeishaRoot
    if ($root) {
        Write-Ok ("heisha root: " + $root)
    } else {
        Write-Warn 'heisha not found in the saved path or this AIO folder.'
        if (Read-YesNo 'Browse for heisha folder now?' $true) {
            Add-Type -AssemblyName System.Windows.Forms
            $d = New-Object System.Windows.Forms.FolderBrowserDialog
            $d.Description = 'Select heisha (midnightxyzw) folder'
            if ($d.ShowDialog() -eq 'OK') {
                $Script:Config.heishaRoot = $d.SelectedPath
                Save-Config
                $root = $d.SelectedPath
                Write-Ok ("Saved heishaRoot = " + $root)
            }
        }
    }

    Write-Host ''
    Write-Host '   [1] Open heisha folder in Explorer' -ForegroundColor Cyan
    Write-Host '   [2] Open run.cmd in notepad (read flags)' -ForegroundColor Cyan
    Write-Host '   [3] Print suggested run.cmd line for your PAZ' -ForegroundColor Green
    Write-Host '   [4] Open AIO pack\midnight_xyzw folder' -ForegroundColor Cyan
    Write-Host '   [0] Back' -ForegroundColor DarkGray
    $c = (Read-Host '  Select').Trim()
    switch ($c) {
        '1' {
            if ($root -and (Test-Path $root)) { Start-Process explorer.exe -ArgumentList $root }
            else { Write-Warn 'No heisha root.' }
        }
        '2' {
            $run = if ($root) { Join-Path $root 'run.cmd' } else { $null }
            if ($run -and (Test-Path $run)) { Start-Process notepad.exe -ArgumentList $run }
            else { Write-Warn 'run.cmd not found.' }
        }
        '3' {
            $paz = [string]$Script:Config.pazFolder
            if (-not (Test-IsPazFolder $paz)) { Write-Warn 'Set PAZ first.' }
            else {
                Write-Host ''
                Write-Host '  Suggested (from heisha folder after setupenv):' -ForegroundColor Yellow
                Write-Host ("  run.cmd -i `"$paz`" -o .\PAZ\midnight_xyzw -m all") -ForegroundColor White
                Write-Host ''
                Write-Info 'Then copy regenerated files into BDO-AIO\pack\midnight_xyzw and redeploy.'
            }
        }
        '4' {
            $p = Join-Path $Script:PackDir 'midnight_xyzw'
            if (Test-Path $p) { Start-Process explorer.exe -ArgumentList $p } else { Write-Warn 'pack\midnight_xyzw missing.' }
        }
    }
    Pause-Any
}

# Remove only AIO-generated packages; user-created folders and the Midnight
# deploy are left alone. Archive is the default; deletion requires an explicit
# -Delete switch so a future caller cannot regress the recoverable behavior.
function Clear-AioGenerated {
    param([switch]$Archive, [switch]$Delete)
    if (-not $Archive -and -not $Delete) { $Archive = $true }
    $ftp = Join-Path ([string]$Script:Config.pazFolder) 'files_to_patch'
    if (-not (Test-Path -LiteralPath $ftp)) { Write-Warn 'No files_to_patch.'; return 0 }
    $resolvedStage = [IO.Path]::GetFullPath($ftp).TrimEnd('\')
    $archiveRoot = Join-Path ([string]$Script:Config.pazFolder) ('BDO_AIO_STAGE_BACKUPS\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $n = 0
    Get-ChildItem -LiteralPath $ftp -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.Name
        $hit = $false
        foreach ($p in $Script:AioPatchFolderPrefixes) {
            if ($name -eq $p.TrimEnd('_') -or $name.StartsWith($p)) { $hit = $true; break }
        }
        if ($hit) {
            $target = [IO.Path]::GetFullPath($_.FullName)
            if ([IO.Path]::GetDirectoryName($target) -ne $resolvedStage) { throw 'Generated package is outside the staging folder.' }
            if ($Archive -and -not $Delete) {
                $null = New-Item -ItemType Directory -Path $archiveRoot -Force
                Move-Item -LiteralPath $target -Destination (Join-Path $archiveRoot $name) -ErrorAction Stop
            } else {
                Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
                Write-Host ("  removed: files_to_patch\" + $name) -ForegroundColor DarkGray
            }
            $n++
        }
    }
    if ($Archive -and $n) { Write-Info ("Previous generated packages retained at: " + $archiveRoot) }
    return $n
}

# Body-size Max caps raise slider ceilings only. When the client is restored to
# stock Max, the GAME clamps any character saved above that ceiling and re-saves
# the clamped body (server + often local Beauty Album / Customization presets).
# Salon re-edits cost pearls; this notice exists so users never learn that the hard way.
function Write-BodySizeRestoreSafetyNotice {
    param(
        # body-size | restore-menu | restore-confirm | restore-done
        [string]$Context = 'restore-menu'
    )

    Write-Host '  BODY SIZE + VANILLA RESTORE  (read before game updates)' -ForegroundColor Yellow
    Write-Host '  -------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Why restore is sometimes REQUIRED' -ForegroundColor White
    Write-Host '    Pearl Abyss / Steam updates often fail or "wall" if pad00000.meta' -ForegroundColor Gray
    Write-Host '    and injected PAZ files are still modded. Menu [R] -> [1] is the' -ForegroundColor Gray
    Write-Host '    supported way to go vanilla so the launcher can update, then re-mod.' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  What the game will destroy if you load a character under stock Max' -ForegroundColor Red
    Write-Host '    Characters saved ABOVE vanilla Max get CLAMPED on load. The clamped' -ForegroundColor Gray
    Write-Host '    shape is re-saved (server-side). Re-raising caps later does NOT restore' -ForegroundColor Gray
    Write-Host '    the old size or shape (long vs round, width axes, etc.).' -ForegroundColor Gray
    Write-Host '    Local Beauty Album / Customization presets can be OVERWRITTEN with' -ForegroundColor Gray
    Write-Host '    that same clamped data when the game re-saves them. Loading a preset' -ForegroundColor Gray
    Write-Host '    after clamp often does nothing useful — it is already the bad data.' -ForegroundColor Gray
    Write-Host '    Rebuilding the look usually needs Beauty Salon (pearls / coupons).' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  SAFE order (free — avoids salon)' -ForegroundColor Green
    Write-Host '    1. While STILL modded: save Beauty Album / Customization presets you care about.' -ForegroundColor Cyan
    Write-Host '    2. [R] -> [1] restore vanilla  (AIO also copies Customization\ into backup\).' -ForegroundColor Cyan
    Write-Host '    3. Let the game launcher update / verify.' -ForegroundColor Cyan
    Write-Host '    4. Do NOT log into characters that were above stock Max while vanilla.' -ForegroundColor Cyan
    Write-Host '       Prefer alts, or stay at character select, until step 5 is done.' -ForegroundColor Cyan
    Write-Host '    5. Re-apply body size (and other packs) + PartCutGen + Meta Inject FIRST.' -ForegroundColor Cyan
    Write-Host '    6. Only THEN log those characters. Caps must be live before they load.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  If you already loaded them under vanilla: values are gone. AIO cannot recover' -ForegroundColor DarkYellow
    Write-Host '  server data. backup\Customization-* only helps if it was taken BEFORE clamp' -ForegroundColor DarkYellow
    Write-Host '  AND you re-inject caps, restore those files, then load the preset (salon).' -ForegroundColor DarkYellow

    if ($Context -eq 'body-size') {
        Write-Host ''
        Write-Host '  Tip: keep body-size caps injected whenever you play oversized characters.' -ForegroundColor DarkGray
        Write-Host '  Only strip them for updates / troubleshooting, using the order above.' -ForegroundColor DarkGray
    }
}

function Backup-BdoCustomizationPresets {
    param([switch]$Required, [string]$CustomizationPath)
    # Copy-only snapshot. Never deletes live presets. Used before vanilla restore.
    $custom = if ($CustomizationPath) { $CustomizationPath } else { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Black Desert\Customization' }
    if (-not (Test-Path -LiteralPath $custom)) {
        Write-Warn 'No Documents\Black Desert\Customization folder — nothing to snapshot.'
        Write-Warn 'If you use Beauty Album presets, save them in-game while STILL modded next time.'
        return $null
    }
    $dest = Join-Path $Script:Root ('backup\Customization-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    try {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Get-ChildItem -LiteralPath $custom -Force -ErrorAction Stop | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
        }
        Write-Ok ('Saved Beauty Album / Customization presets to:')
        Write-Host ("    " + $dest) -ForegroundColor Cyan
        Write-Host '  These files are only useful if the character was NOT already clamped.' -ForegroundColor DarkGray
        Write-Host '  After re-injecting body size caps, you may copy them back over' -ForegroundColor DarkGray
        Write-Host '  Documents\Black Desert\Customization\ then load the preset in-game.' -ForegroundColor DarkGray
        return $dest
    } catch {
        if ($Required) { throw ('Preset backup failed; recovery was not started. ' + $_.Exception.Message) }
        Write-Warn ('Could not back up character presets: ' + $_.Exception.Message)
        return $null
    }
}

# Runs tools\bdo_meta\vanilla_restore.py against the configured PAZ folder.
# Returns $true when the tool reported success.
function Invoke-VanillaRestoreTool {
    param([string[]]$ToolArgs)

    $isRestore = $false
    foreach ($a in @($ToolArgs)) {
        if ([string]$a -eq 'restore' -and '--apply' -in $ToolArgs) { $isRestore = $true; break }
    }

    # Character / preset risk only applies when actually restoring game files.
    # Full safety wall is shown by Restore-UneditedGameFiles / body-size menu —
    # here we only snapshot presets and print a short reminder (scan/backup stay quiet).
    if ($isRestore) {
        if ([string]$Script:Config.bodySizeParts) {
            Write-Warn 'Body size caps are configured. Do NOT load oversized characters while vanilla.'
            Write-Warn 'Re-inject body size + Meta Inject BEFORE those characters log in.'
        } else {
            Write-Warn 'After restore: update the game if needed, then re-apply AIO before playing modded looks.'
        }
        Write-Host ''
        Write-Host '  Snapshotting Beauty Album / Customization presets (copy-only)...' -ForegroundColor Yellow
        [void](Backup-BdoCustomizationPresets -Required)
        Write-Host ''
    }

    if (-not (Ensure-Python)) { return $false }
    $tool = Join-Path $Script:Root 'tools\bdo_meta\vanilla_restore.py'
    if (-not (Test-Path -LiteralPath $tool)) {
        Write-Err ("Missing tool: " + $tool)
        return $false
    }
    $pyArgs = @($tool) + $ToolArgs + @('--paz', [string]$Script:Config.pazFolder)
    return (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Vanilla restore tool')
}

function Invoke-RecoveryJson {
    param([string[]]$Arguments)
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { throw 'Set and save the game PAZ folder first.' }
    if (-not (Ensure-Python -ProbeOnly)) { throw 'Choose a Python 3 interpreter in Overview first.' }
    $tool = Join-Path $Script:Root 'tools\bdo_meta\vanilla_restore.py'
    $output = & $Script:PythonExe -B $tool @Arguments --paz ([string]$Script:Config.pazFolder) | Out-String
    $code = $LASTEXITCODE
    try { $data = $output | ConvertFrom-Json } catch { throw ('Recovery returned no readable result. ' + $output) }
    if ($code -ne 0) { throw $(if ($data.PSObject.Properties['error']) { $data.error } else { 'Recovery check failed.' }) }
    return $data
}

function Invoke-NativeRecovery {
    param([ValidateSet('restore','snapshot','cleanup')][string]$Operation, [string]$Token, [switch]$Confirmed)
    if (-not $Confirmed -or $Token -notmatch '^[0-9a-f]{64}$') { throw 'Preview and explicitly confirm recovery first.' }
    if (-not (Test-BdoToolsIdle)) { throw 'Close the game, launcher and patch tools before recovery.' }
    $presetBackup = $null
    if ($Operation -eq 'restore') { $presetBackup = Backup-BdoCustomizationPresets -Required }
    $result = Invoke-RecoveryJson @('recover', '--operation', $Operation, '--preview-token', $Token, '--confirmed')
    if ($result.state -ne 'completed') { throw 'Recovery did not report completion.' }
    $result | Add-Member -NotePropertyName presetBackup -NotePropertyValue $presetBackup -Force
    return $result
}

function Restore-UneditedGameFiles {
    Write-Banner
    Write-Host '  RESTORE / CLEAN AIO CHANGES' -ForegroundColor Yellow
    Write-Host '  ===========================' -ForegroundColor DarkGray
    Write-Info 'For game updates, troubleshooting, and making changes easily.'
    Write-Warn 'True vanilla meta may still need Pearl Abyss launcher Verify/Repair.'
    Write-Host ''
    Write-Host '  GAME UPDATES - ORDER MATTERS' -ForegroundColor Yellow
    Write-Host '  A client patch replaces Paz\pad00000.meta outright, so any injection made' -ForegroundColor Yellow
    Write-Host '  before the patch is wiped and its archives are left orphaned. Also: the meta' -ForegroundColor Yellow
    Write-Host '  header carries the client version, so restoring a snapshot taken on an OLDER' -ForegroundColor Yellow
    Write-Host '  client makes the launcher think you are out of date and re-download it.' -ForegroundColor Yellow
    Write-Host '    1. Let the launcher finish patching and start the game once.' -ForegroundColor Cyan
    Write-Host '    2. [2] Re-snapshot vanilla on the NEW client version.' -ForegroundColor Cyan
    Write-Host '    3. Re-apply AIO, PartCutGen, Meta Injector.' -ForegroundColor Cyan
    Write-Host '  Body-size users: do NOT load oversized characters while the client is vanilla.' -ForegroundColor Yellow
    Write-Host ''
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first.'
        Pause-Any
        return
    }
    $paz = [string]$Script:Config.pazFolder
    $gameRoot = Get-GameRootFromPaz
    $ftp = Join-Path $paz 'files_to_patch'

    Show-PazInjectStatus -PazFolder $paz
    Write-Host ''

    Write-Host '   The game and the build folder are two separate things:' -ForegroundColor White
    Write-Host ''
    Write-Host '   [1] RESTORE GAME TO VANILLA' -ForegroundColor Green
    Write-Host '       Needed before many game updates. Dry run first. Snapshots presets.' -ForegroundColor DarkGray
    Write-Host '   [2] CLEAR STAGED MOD FILES' -ForegroundColor Yellow
    Write-Host '       Empty files_to_patch, the folder AIO builds into before injecting.' -ForegroundColor DarkGray
    Write-Host '       Does not touch the game -- run [1] for that.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '   [3] Vanilla meta backup / scan' -ForegroundColor Cyan
    Write-Host '   [4] Undo experimental graphics (OptiScaler / DLSS)' -ForegroundColor Cyan
    Write-Host '   [0] Back' -ForegroundColor DarkGray
    $c = (Read-Host '  Select').Trim().ToUpperInvariant()
    if ($c -eq '0' -or [string]::IsNullOrWhiteSpace($c)) { return }

    if ($c -eq '3') {
        Write-Host ''
        Write-Host '    [S] Scan meta / backup state' -ForegroundColor Cyan
        Write-Host '    [B] Make a vanilla meta backup now (best done while unmodded)' -ForegroundColor Cyan
        $s = (Read-Host '  Select').Trim().ToUpperInvariant()
        if ($s -eq 'S') { Invoke-VanillaRestoreTool @('scan') }
        elseif ($s -eq 'B') { Invoke-VanillaRestoreTool @('backup') }
        else { Write-Info 'Cancelled.' }
        Pause-Any
        return
    }
    if ($c -eq '1') {
        Write-Host ''
        Write-BodySizeRestoreSafetyNotice -Context 'restore-menu'
        Write-Host ''
        if (-not (Read-YesNo 'I understand: re-inject body size BEFORE loading oversized characters. Continue to dry run?' $false)) {
            Write-Info 'Cancelled — nothing changed.'
            Pause-Any
            return
        }
        Write-Host ''
        Write-Info 'DRY RUN first — nothing is changed yet:'
        Write-Host ''
        if (-not (Invoke-VanillaRestoreTool @('restore'))) { Pause-Any; return }
        Write-Host ''
        Write-Warn 'This restores pad00000.meta from the oldest backup and deletes the'
        Write-Warn 'injected PAZ files listed above. Your AIO settings are NOT touched.'
        Write-Warn 'After apply: update the game if needed, then re-mod BEFORE playing mains.'
        if (-not (Read-YesNo 'Restore the game to vanilla now?' $false)) {
            Write-Info 'Cancelled — nothing changed.'
            Pause-Any
            return
        }
        $keepPaz = -not (Read-YesNo 'Also delete the injected PAZ files (frees the space)?' $false)
        $restoreArgs = @('restore', '--apply')
        if ($keepPaz) { $restoreArgs += '--keep-paz' }
        if (Invoke-VanillaRestoreTool $restoreArgs) {
            Write-Host ''
            Write-Ok 'Game restored to vanilla.'
            if (Read-YesNo 'Also archive AIO-generated files_to_patch folders?' $false) {
                $n = Clear-AioGenerated -Archive
                Write-Ok ("Archived $n AIO folder(s).")
            }
            Write-Host ''
            Write-Host '  NEXT STEPS (order matters — do not skip)' -ForegroundColor Yellow
            Write-Host '  1. Close BDO if open. Run Pearl Abyss / Steam update or verify if needed.' -ForegroundColor Cyan
            Write-Host '  2. Do NOT log oversized body characters while still vanilla.' -ForegroundColor Red
            Write-Host '  3. Re-open AIO: re-apply body size + other packs, PartCutGen, Meta Inject.' -ForegroundColor Cyan
            Write-Host '  4. Only after inject succeeds, log those characters again.' -ForegroundColor Cyan
            Write-Host '  Config (pubic/slider choices) is kept in config.json for re-apply.' -ForegroundColor DarkGray
            Write-Host '  Preset snapshots (if any): backup\Customization-* under this AIO folder.' -ForegroundColor DarkGray
        } else {
            Write-Host ''
            Write-Warn 'If the meta cannot be restored from a backup, verify the game files:'
            Write-Host '    1. Close BDO + launcher helpers' -ForegroundColor Cyan
            Write-Host '    2. Open Pearl Abyss / Steam / game launcher' -ForegroundColor Cyan
            Write-Host '    3. Use Verify / Repair / Check integrity of game files' -ForegroundColor Cyan
            Write-Info ("PAZ: " + $paz)
        }
        Pause-Any
        return
    }

    if ($c -eq '2') {
        Write-Host ''
        Write-Host '    [A] Archive AIO-generated folders only  (recommended)' -ForegroundColor Green
        Write-Host '        _body_size, _slot_hide_*, _pubic_*, _censorship_*, _genital_*' -ForegroundColor DarkGray
        Write-Host '        Keeps the Midnight deploy, so you only re-apply AIO options.' -ForegroundColor DarkGray
        Write-Host '    [E] EVERYTHING, including the Midnight deploy' -ForegroundColor Yellow
        Write-Host '        Full rebuild: you must re-deploy Midnight afterwards.' -ForegroundColor DarkGray
        $s = (Read-Host '  Select').Trim().ToUpperInvariant()
        if ($s -eq 'A') {
            $n = Clear-AioGenerated -Archive
            Write-Ok ("Archived $n AIO folder(s).")
            Write-Info 'Re-apply the options you want, then PartCutGen + Meta Injector.'
        } elseif ($s -eq 'E') {
            if (Read-YesNo 'DELETE the entire files_to_patch folder?' $false) {
                if (Test-Path -LiteralPath $ftp) {
                    Remove-Item -LiteralPath $ftp -Recurse -Force
                    Write-Ok 'files_to_patch removed.'
                } else {
                    Write-Warn 'No files_to_patch to remove.'
                }
                Write-Info 'Next: deploy Midnight, re-apply options, PartCutGen, Meta Injector.'
            } else {
                Write-Info 'Cancelled.'
            }
        } else {
            Write-Info 'Cancelled.'
        }
        Write-Warn 'This changed only the build folder. The game itself is still patched'
        Write-Warn 'until you run [1] or inject again.'
    }

    if ($c -eq '4') {
        if (-not $gameRoot) { Write-Err 'No game root.'; Pause-Any; return }
        Write-Host ''
        Write-Host '    [U] Uninstall AIO-marked OptiScaler files from the game root' -ForegroundColor Cyan
        Write-Host '    [R] Restore the latest BDO-AIO-backup-dlss-* folder' -ForegroundColor Cyan
        $s = (Read-Host '  Select').Trim().ToUpperInvariant()
        if ($s -eq 'U') {
            Uninstall-ExperimentalDlss
        } elseif ($s -eq 'R') {
            $backs = @(Get-ChildItem -LiteralPath $gameRoot -Directory -Filter 'BDO-AIO-backup-dlss-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
            if ($backs.Count -eq 0) { Write-Warn 'No BDO-AIO-backup-dlss-* folders found.'; Pause-Any; return }
            Write-Info ("Using latest: " + $backs[0].Name)
            if (Read-YesNo 'Copy backup contents back into game root?' $true) {
                Get-ChildItem -LiteralPath $backs[0].FullName -Force | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $gameRoot $_.Name) -Recurse -Force
                    Write-Host ("  restored: " + $_.Name) -ForegroundColor DarkGray
                }
                Write-Ok 'Backup restored into game root.'
            }
        } else {
            Write-Info 'Cancelled.'
        }
    }

    Write-Host ''
    Write-Ok 'Restore menu step finished.'
    Pause-Any
}

function Run-FullWizard {
    param([switch]$NoPrompt)
    Write-Banner
    Write-Host '  Apply saved choices' -ForegroundColor White
    if (-not (Test-BdoToolsIdle)) { Pause-Any; return $false }
    $pack = Test-PackReady
    if (-not $pack.Ok) {
        Write-Err 'The full mod pack is missing or incomplete.'
        foreach ($missing in $pack.Missing) { Write-Warn $missing }
        Pause-Any
        return $false
    }
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        if (-not $NoPrompt) { Set-PazFolder }
        if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set PAZ first.'; Pause-Any; return $false }
    }
    if (-not $NoPrompt -and (Read-YesNo 'Change options before applying?' $false)) { Configure-ModChoices }
    if (-not (Deploy-Midnight -NoPrompt:$NoPrompt)) { return $false }
    if (-not (Apply-AllRestoredChoices -NoPrompt)) { Pause-Any; return $false }
    if (-not (Run-PartCutGen)) { return $false }
    if (-not (Run-MetaInjector)) { return $false }
    Write-Ok 'Apply sequence completed and meta verified.'
    Pause-Any
    return $true
}

function Open-FilesToPatch {
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first.'
        Pause-Any
        return
    }
    $ftp = Join-Path $Script:Config.pazFolder 'files_to_patch'
    if (-not (Test-Path -LiteralPath $ftp)) {
        New-Item -ItemType Directory -Path $ftp -Force | Out-Null
        Write-Info 'Created empty files_to_patch (deploy Midnight first for full mods).'
    }
    Start-Process explorer.exe -ArgumentList $ftp
    Write-Ok ("Opened: " + $ftp)
    Write-Info 'Drop extra Meta-Injector style mods here (character/model, character/texture), then re-run PartCutGen + Injector.'
    Pause-Any
}

function Apply-GraphicsProfile {
    Write-Banner
    Write-Host '  Graphics profile pack (GameOption)' -ForegroundColor White
    Write-Host '  ----------------------------------' -ForegroundColor DarkGray
    Write-Info 'Merges verified max-quality keys into Documents\Black Desert\GameOption.txt'
    Write-Info 'Display adapter, window mode, HDR, audio, UI, gamma, and every unknown/current key are preserved.'
    Write-Warn 'Close Black Desert completely before applying.'
    Write-Host ''

    $gfx = Test-GraphicsReady
    if (-not $gfx.Ok) {
        Write-Err 'Graphics pack incomplete in this AIO folder.'
        foreach ($m in $gfx.Missing) { Write-Warn ("  " + $m) }
        Pause-Any
        return
    }

    $bdoDocs = Get-BdoDocumentsFolder
    $target = Join-Path $bdoDocs 'GameOption.txt'
    Write-Info ("Target folder : " + $bdoDocs)
    Write-Info ("Target file   : " + $target)
    Write-Host ''

    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        Write-Err 'GameOption.txt does not exist. Start BDO once, close it completely, then retry.'
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) {
        Pause-Any
        return
    }

    Write-Host '  PROFILES' -ForegroundColor White
    Write-Host '  --------' -ForegroundColor DarkGray
    $keys = @($Script:GraphicsProfiles.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $k = $keys[$i]
        Write-Host ("    [" + ($i + 1) + "] " + $Script:GraphicsProfiles[$k]) -ForegroundColor Cyan
        Write-Host ("        file: " + $k) -ForegroundColor DarkGray
    }
    Write-Host '    [R] Open graphics README' -ForegroundColor Yellow
    Write-Host '    [O] Open Documents\Black Desert folder' -ForegroundColor Yellow
    Write-Host '    [0] Cancel' -ForegroundColor DarkGray
    Write-Host ''

    $pick = (Read-Host '  Select profile').Trim().ToUpperInvariant()
    if ($pick -eq '0' -or [string]::IsNullOrEmpty($pick)) { return }

    if ($pick -eq 'R') {
        $readme = Join-Path $Script:GraphicsDir 'README.txt'
        if (Test-Path -LiteralPath $readme) {
            Start-Process notepad.exe -ArgumentList $readme
            Write-Ok 'Opened graphics README.'
        } else {
            Write-Warn 'README.txt missing from graphics folder.'
        }
        Pause-Any
        return
    }
    if ($pick -eq 'O') {
        if (-not (Test-Path -LiteralPath $bdoDocs)) {
            New-Item -ItemType Directory -Path $bdoDocs -Force | Out-Null
        }
        Start-Process explorer.exe -ArgumentList $bdoDocs
        Write-Ok ("Opened: " + $bdoDocs)
        Pause-Any
        return
    }

    if ($pick -notmatch '^\d+$') {
        Write-Warn 'Invalid choice.'
        Pause-Any
        return
    }
    $idx = [int]$pick - 1
    if ($idx -lt 0 -or $idx -ge $keys.Count) {
        Write-Warn 'Invalid profile number.'
        Pause-Any
        return
    }

    $fileName = $keys[$idx]
    $src = Join-Path $Script:GraphicsDir $fileName
    Write-Host ''
    Write-Host ("  Selected: " + $Script:GraphicsProfiles[$fileName]) -ForegroundColor White
    Write-Host ("  Source  : " + $src) -ForegroundColor Gray

    if ($fileName -match 'DLDSR') {
        Write-Host ''
        Write-Warn 'DLDSR profiles need NVIDIA Control Panel first:'
        Write-Host '  Manage 3D Settings -> DSR Factors -> DL scaling 2.25x' -ForegroundColor Yellow
        Write-Host '  Then in BDO fullscreen pick 3840x2160' -ForegroundColor Yellow
        Write-Host '  Start DSR Smoothness around 50%' -ForegroundColor Yellow
    }
    Write-Host ''
    if (-not (Read-YesNo 'Merge this profile now? (backs up the complete existing file)' $false)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    if (-not (Test-BdoToolsIdle)) {
        Pause-Any
        return
    }

    try {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $backup = Join-Path $bdoDocs ("GameOption.backup." + $stamp + "-" + [guid]::NewGuid().ToString('N').Substring(0,8) + ".txt")
        Copy-Item -LiteralPath $target -Destination $backup
        Write-Ok ("Backed up complete file -> " + [IO.Path]::GetFileName($backup))

        $ok = Invoke-BdoPythonChecked -Arguments @(
            $Script:GameOptionTool,
            '--game-option', $target,
            '--profile', $src,
            '--output', $target
        ) -Label 'GameOption merge'
        if (-not $ok) { throw 'GameOption merge failed; the original target was not replaced.' }
        Write-Ok ("Merged verified keys into: " + $target)
        Write-Info 'Do NOT mark GameOption.txt read-only (game/patches may update it).'
        Write-Info 'Start the game and verify: Texture High, Remastered, TAA, Upscale Off.'
    } catch {
        Write-Err $_.Exception.Message
    }
    Pause-Any
}

function Resolve-GraphicsProfilePath {
    param([string]$Profile)
    if ([string]::IsNullOrWhiteSpace($Profile) -or -not $Script:GraphicsProfiles.Contains($Profile)) {
        throw 'Choose one of the bundled graphics profiles.'
    }
    $path = Join-Path $Script:GraphicsDir $Profile
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('Graphics profile is missing: ' + $Profile)
    }
    return $path
}

function Get-GraphicsTargetPath {
    return (Join-Path (Get-BdoDocumentsFolder) 'GameOption.txt')
}

function Get-GraphicsToken {
    param([string]$Target, [string]$ProfilePath)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $material = [Text.Encoding]::UTF8.GetBytes((Get-FileHash -LiteralPath $Target).Hash + '|' + (Get-FileHash -LiteralPath $ProfilePath).Hash + '|' + $Target)
        return ([BitConverter]::ToString($hasher.ComputeHash($material))).Replace('-', '').ToLowerInvariant()
    } finally { $hasher.Dispose() }
}

function Invoke-GraphicsJson {
    param([string]$Profile, [switch]$Write)
    $profilePath = Resolve-GraphicsProfilePath $Profile
    $target = Get-GraphicsTargetPath
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw ('GameOption.txt was not found at ' + $target + '. Start BDO once, close it, then preview again.')
    }
    if (-not (Ensure-Python -ProbeOnly)) { throw 'Choose a Python 3 interpreter in Overview first.' }
    $args = @('-B', $Script:GameOptionTool, '--game-option', $target, '--profile', $profilePath)
    if ($Write) { $args += @('--output', $target) }
    $output = & $Script:PythonExe @args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw ('GameOption profile failed: ' + $output.Trim()) }
    try { return ($output | ConvertFrom-Json) } catch { throw ('GameOption returned no readable result. ' + $output.Trim()) }
}

function Get-NativeGraphicsPlan {
    param([string]$Profile)
    $profilePath = Resolve-GraphicsProfilePath $Profile
    $target = Get-GraphicsTargetPath
    $preview = Invoke-GraphicsJson -Profile $Profile
    $nip = Test-NipReady
    $npi = Find-NvidiaProfileInspector
    return [pscustomobject]@{
        profile = $Profile
        description = [string]$Script:GraphicsProfiles[$Profile]
        target = $target
        profilePath = $profilePath
        token = Get-GraphicsToken -Target $target -ProfilePath $profilePath
        sourceBytes = (Get-Item -LiteralPath $target).Length
        changed = @($preview.changed | ForEach-Object { [string]$_ })
        preservedLines = [int]$preview.preserved_lines
        canApply = (@($preview.changed).Count -gt 0)
        nvidia = [pscustomobject]@{
            bundledProfile = $nip.Path
            bundledAvailable = [bool]$nip.Ok
            inspector = $npi
            inspectorAvailable = [bool]$npi
        }
    }
}

function Invoke-NativeGraphics {
    param([string]$Profile, [string]$Token, [switch]$Confirmed)
    if (-not $Confirmed -or $Token -notmatch '^[0-9a-f]{64}$') { throw 'Preview and explicitly confirm a graphics profile first.' }
    if (-not (Test-BdoToolsIdle)) { throw 'Close Black Desert and its launcher before changing GameOption.txt.' }
    $plan = Get-NativeGraphicsPlan -Profile $Profile
    if ($plan.token -ne $Token) { throw 'GameOption.txt or the selected profile changed after preview. Preview again.' }
    if (-not $plan.canApply) { throw 'The selected profile already matches the current GameOption.txt.' }
    $backup = Join-Path (Split-Path -Parent $plan.target) ('GameOption.backup.' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.txt')
    Copy-Item -LiteralPath $plan.target -Destination $backup -Force -ErrorAction Stop
    $written = Invoke-GraphicsJson -Profile $Profile -Write
    $verify = Invoke-GraphicsJson -Profile $Profile
    if (@($verify.changed).Count) { throw ('GameOption verification still reports changed keys. Restore from: ' + $backup) }
    return [pscustomobject]@{
        operation = 'graphics'
        profile = $Profile
        target = $plan.target
        backup = $backup
        changed = @($written.changed | ForEach-Object { [string]$_ })
        preservedLines = [int]$written.preserved_lines
    }
}

function Get-GameRootFromPaz {
    $paz = [string]$Script:Config.pazFolder
    if (-not (Test-IsPazFolder $paz)) { return $null }
    $root = Split-Path -Parent $paz
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $null }
    return $root
}

function Get-BdoClientRegion {
    $gameRoot = Get-GameRootFromPaz
    if (-not $gameRoot) { return '' }
    $serviceIni = Join-Path $gameRoot 'service.ini'
    if (-not (Test-Path -LiteralPath $serviceIni -PathType Leaf)) { return '' }
    foreach ($line in Get-Content -LiteralPath $serviceIni -ErrorAction Stop) {
        if ($line -match '^\s*TYPE\s*=\s*(.*?)\s*$') {
            return $Matches[1].Trim().ToUpperInvariant()
        }
    }
    return ''
}

function Test-ExperimentalDlssReady {
    $opti = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.dll'
    $ini  = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.ini'
    $sl   = Join-Path $Script:ExperimentalDlssDir 'Streamline\sl.dlss.dll'
    $missing = @()
    if (-not (Test-Path -LiteralPath $opti)) { $missing += $opti }
    if (-not (Test-Path -LiteralPath $ini))  { $missing += $ini }
    if (-not (Test-Path -LiteralPath $sl))   { $missing += $sl }
    return @{
        Ok      = ($missing.Count -eq 0)
        Missing = $missing
        OptiDir = (Join-Path $Script:ExperimentalDlssDir 'OptiScaler')
        StreamDir = (Join-Path $Script:ExperimentalDlssDir 'Streamline')
    }
}

function Confirm-ExperimentalDanger {
    Write-Host ''
    Write-Host '  ############################################################' -ForegroundColor Red
    Write-Host '  #   EXPERIMENTAL  /  NOT SAFE  /  OWN RISK ONLY            #' -ForegroundColor Red
    Write-Host '  #   Unofficial DLL inject for DLSS-style upscaling         #' -ForegroundColor Red
    Write-Host '  #   Ban / crash / black screen / broken after patches      #' -ForegroundColor Red
    Write-Host '  #   BDO only has weak FSR-class upscale; this hacks around #' -ForegroundColor Red
    Write-Host '  ############################################################' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Safe alternatives: menu G (GameOption) + menu N (NVIDIA profile).' -ForegroundColor Yellow
    Write-Host '  Do NOT use on a main account you care about.' -ForegroundColor Yellow
    Write-Host ''

    $a = (Read-Host '  Type YES to acknowledge this is EXPERIMENTAL and NOT SAFE').Trim()
    if ($a -cne 'YES') {
        Write-Warn 'Aborted (you must type YES in capitals).'
        return $false
    }
    if (-not (Read-YesNo 'Install unofficial DLLs into your BDO game folder anyway?' $false)) {
        Write-Warn 'Aborted.'
        return $false
    }
    return $true
}

function Install-ExperimentalDlss {
    Write-Banner
    Write-Host '  [X] EXPERIMENTAL DLSS / OptiScaler for BDO' -ForegroundColor Red
    Write-Host '  ==========================================' -ForegroundColor Red
    Write-Info 'BDO native upscale is weak (FSR 1.0-class). This tries modern upscalers via OptiScaler.'
    Write-Warn 'THIS IS UNOFFICIAL CLIENT MODIFICATION. NOT SAFE.'
    Write-Host ''

    $ready = Test-ExperimentalDlssReady
    if (-not $ready.Ok) {
        Write-Err 'Experimental pack incomplete under experimental\dlss\'
        foreach ($m in $ready.Missing) { Write-Warn ("  " + $m) }
        Pause-Any
        return
    }

    if (-not (Confirm-ExperimentalDanger)) {
        Pause-Any
        return
    }

    $gameRoot = Get-GameRootFromPaz
    if (-not $gameRoot) {
        Write-Err 'Set a valid game PAZ folder first (menu 1). Game root is the parent of PAZ.'
        Pause-Any
        return
    }

    $exeCandidates = @('BlackDesert64.exe', 'BlackDesertOnline.exe', 'BlackDesert.exe')
    $exeFound = $false
    foreach ($e in $exeCandidates) {
        if (Test-Path -LiteralPath (Join-Path $gameRoot $e)) { $exeFound = $true; break }
    }
    Write-Info ("Game root : " + $gameRoot)
    if ($exeFound) {
        Write-Ok 'Found BDO executable in game root.'
    } else {
        Write-Warn 'Did not find BlackDesert64.exe in game root — double-check PAZ parent is correct.'
        if (-not (Read-YesNo 'Continue install into this folder anyway?' $false)) {
            Pause-Any
            return
        }
    }

    Write-Host ''
    Write-Host '  Proxy DLL name for OptiScaler (how it loads):' -ForegroundColor White
    Write-Host '    [1] dxgi.dll     (RECOMMENDED default, most compatible)' -ForegroundColor Cyan
    Write-Host '    [2] winmm.dll    (alternate)' -ForegroundColor Cyan
    Write-Host '    [3] version.dll (alternate; may conflict with other mods)' -ForegroundColor Cyan
    $proxyPick = Read-Choice 'Proxy' @('1', '2', '3')
    $proxyName = switch ($proxyPick) {
        '1' { 'dxgi.dll' }
        '2' { 'winmm.dll' }
        '3' { 'version.dll' }
    }

    Write-Host ''
    Write-Host '  Preferred upscaler in OptiScaler.ini (game still must enable upscale):' -ForegroundColor White
    Write-Host '    [1] dlss     (NVIDIA DLSS, if compatible inputs are available)' -ForegroundColor Cyan
    Write-Host '    [2] auto    (OptiScaler default)' -ForegroundColor Cyan
    Write-Host '    [3] fsr31   (OptiScaler bundled FidelityFX path)' -ForegroundColor Cyan
    Write-Host '    [4] xess    (Intel XeSS)' -ForegroundColor Cyan
    $upPick = Read-Choice 'Upscaler' @('1', '2', '3', '4')
    $upName = switch ($upPick) {
        '1' { 'dlss' }
        '2' { 'auto' }
        '3' { 'fsr31' }
        '4' { 'xess' }
    }

    Write-Host ''
    Write-Warn ("About to copy EXPERIMENTAL files into: " + $gameRoot)
    Write-Warn ("Proxy: " + $proxyName + "  |  Upscaler: " + $upName + '  |  official OptiScaler bundle only')
    if (-not (Read-YesNo 'Final confirm — install now?' $false)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    # Backup existing proxies / known files
    $backupDir = Join-Path $gameRoot ('BDO-AIO-backup-dlss-' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Info ("Backup folder: " + $backupDir)

    $toBackup = @($Script:OptiProxyNames + $Script:OptiExtraFiles + @('D3D12_Optiscaler')) | Select-Object -Unique
    foreach ($name in $toBackup) {
        $p = Join-Path $gameRoot $name
        if (Test-Path -LiteralPath $p) {
            try {
                Copy-Item -LiteralPath $p -Destination (Join-Path $backupDir $name) -Recurse -Force
                Write-Host ("  backed up: " + $name) -ForegroundColor DarkGray
            } catch {
                Write-Warn ("Could not back up " + $name + ": " + $_.Exception.Message)
            }
        }
    }

    # Copy OptiScaler tree (files + D3D12_Optiscaler + Licenses)
    Write-Info 'Copying OptiScaler...'
    $optiSrc = $ready.OptiDir
    Get-ChildItem -LiteralPath $optiSrc -Force | ForEach-Object {
        $dest = Join-Path $gameRoot $_.Name
        if ($_.PSIsContainer) {
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
        } else {
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
    }

    # Copy Streamline DLLs into game root
    Write-Info 'Copying Streamline DLLs...'
    Get-ChildItem -LiteralPath $ready.StreamDir -File -Filter 'sl.*.dll' | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $gameRoot $_.Name) -Force
    }

    # Rename OptiScaler.dll -> proxy
    $optiInGame = Join-Path $gameRoot 'OptiScaler.dll'
    $proxyPath = Join-Path $gameRoot $proxyName
    if (-not (Test-Path -LiteralPath $optiInGame)) {
        Write-Err 'OptiScaler.dll missing after copy — install failed.'
        Pause-Any
        return
    }

    if (Test-Path -LiteralPath $proxyPath) {
        Remove-Item -LiteralPath $proxyPath -Force
    }
    Rename-Item -LiteralPath $optiInGame -NewName $proxyName
    Write-Ok ("Installed proxy: " + $proxyName + " (was OptiScaler.dll)")

    # Patch OptiScaler.ini upscaler preferences when not auto
    $iniPath = Join-Path $gameRoot 'OptiScaler.ini'
    if ((Test-Path -LiteralPath $iniPath) -and ($upName -ne 'auto')) {
        try {
            $ini = Get-Content -LiteralPath $iniPath -Raw -Encoding UTF8
            $ini = [regex]::Replace($ini, '(?m)^Dx11Upscaler=.*$', "Dx11Upscaler=$upName")
            $ini = [regex]::Replace($ini, '(?m)^Dx12Upscaler=.*$', "Dx12Upscaler=$upName")
            $ini = [regex]::Replace($ini, '(?m)^VulkanUpscaler=.*$', "VulkanUpscaler=$upName")
            # Prefer FSR FG path when fsr31 selected (keys vary by OptiScaler version — best-effort)
            if ($upName -eq 'fsr31') {
                $ini = [regex]::Replace($ini, '(?m)^FgType=.*$', 'FgType=optifg')
            }
            $utf8 = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($iniPath, $ini, $utf8)
            Write-Ok ("OptiScaler.ini upscalers set to: " + $upName)
            Write-Info 'Using only the DLL set bundled by the official OptiScaler release.'
        } catch {
            Write-Warn ("Could not edit OptiScaler.ini: " + $_.Exception.Message)
        }
    }

    # Marker for uninstall awareness
    $marker = Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt'
    @(
        ('EXPERIMENTAL / NOT SAFE - installed by BDO-AIO ' + $Script:Version),
        ('Installed: ' + (Get-Date).ToString('s')),
        ('Proxy: ' + $proxyName),
        ('Upscaler: ' + $upName),
        ('Backup: ' + $backupDir),
        'Uninstall via BDO-AIO menu X / R. Do not delete unrelated proxy DLLs by filename.'
    ) | Set-Content -LiteralPath $marker -Encoding UTF8

    Write-Host ''
    Write-Ok 'Experimental install finished.'
    Write-Host '  NEXT STEPS' -ForegroundColor Yellow
    Write-Host '  1. Launch BDO. If it fails to start -> menu X Uninstall or menu R immediately.' -ForegroundColor Yellow
    Write-Host '  2. Enable in-game Upscale / FSR if available so the hook has something to replace.' -ForegroundColor Yellow
    Write-Host '  3. OptiScaler overlay keys are in OptiScaler.ini / OptiScaler wiki.' -ForegroundColor Yellow
    Write-Host '  4. After game patches, reinstall or remove — DLLs often break.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Remember: EXPERIMENTAL. NOT SAFE. Own risk.' -ForegroundColor Red
    Pause-Any
}

function Uninstall-ExperimentalDlss {
    Write-Banner
    Write-Host '  Uninstall EXPERIMENTAL DLSS / OptiScaler files' -ForegroundColor Yellow
    Write-Host '  ----------------------------------------------' -ForegroundColor DarkGray

    $gameRoot = Get-GameRootFromPaz
    if (-not $gameRoot) {
        Write-Err 'Set PAZ first (menu 1).'
        Pause-Any
        return
    }
    Write-Info ("Game root: " + $gameRoot)
    $marker = Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt'
    if (-not (Test-Path -LiteralPath $marker)) {
        Write-Warn 'No BDO-AIO experimental-install marker was found. Refusing filename-only DLL deletion.'
        Write-Info 'Use the launcher Verify/Repair flow or restore a known backup instead.'
        Pause-Any
        return
    }
    Write-Warn 'This removes the AIO-marked OptiScaler proxy and bundled Streamline/Opti files.'
    if (-not (Read-YesNo 'Remove experimental DLLs now?' $true)) {
        Pause-Any
        return
    }

    $removed = 0
    foreach ($name in ($Script:OptiProxyNames + $Script:OptiExtraFiles | Select-Object -Unique)) {
        $p = Join-Path $gameRoot $name
        if (Test-Path -LiteralPath $p) {
            # Never delete an unrelated loader just because it uses a common proxy filename.
            $isProxy = $Script:OptiProxyNames -contains $name
            $delete = $true
            if ($isProxy) {
                $delete = $false
                try {
                    $orig = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($p).OriginalFilename
                    if ($orig -match 'OptiScaler') { $delete = $true }
                } catch {}
                if (-not $delete) {
                    $bundled = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.dll'
                    if (Test-Path -LiteralPath $bundled) {
                        try {
                            $delete = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -eq
                                      (Get-FileHash -LiteralPath $bundled -Algorithm SHA256).Hash
                        } catch {}
                    }
                }
                if (-not $delete) { Write-Warn ("Skipping unrelated or unverifiable proxy: " + $name) }
            }
            if ($delete) {
                Remove-Item -LiteralPath $p -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host ("  removed: " + $name) -ForegroundColor DarkGray
                $removed++
            }
        }
    }
    $d3 = Join-Path $gameRoot 'D3D12_Optiscaler'
    if (Test-Path -LiteralPath $d3) {
        Remove-Item -LiteralPath $d3 -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host '  removed: D3D12_Optiscaler\' -ForegroundColor DarkGray
        $removed++
    }
    $lic = Join-Path $gameRoot 'Licenses'
    # only remove Licenses if it looks like OptiScaler licenses folder
    if (Test-Path -LiteralPath (Join-Path $lic 'XeSS_LICENSE.txt')) {
        Remove-Item -LiteralPath $lic -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host '  removed: Licenses\' -ForegroundColor DarkGray
    }
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }

    Write-Ok ("Uninstall pass done. Items removed: " + $removed)
    Write-Info 'If the game still misbehaves, verify/repair game files in the launcher.'
    Write-Info 'Timestamped BDO-AIO-backup-dlss-* folders in game root are left for you to restore manually.'
    Pause-Any
}

function Show-ExperimentalDlssMenu {
    Write-Banner
    Write-Host '  ########################################################' -ForegroundColor Red
    Write-Host '  #  EXPERIMENTAL (FROM-SCRATCH) — NOT a RESTORED feature  #' -ForegroundColor Red
    Write-Host '  #  OptiScaler / DLSS inject — NOT SAFE                   #' -ForegroundColor Red
    Write-Host '  ########################################################' -ForegroundColor Red
    Write-Host ''
    Write-Host '  This is NOT Resorepless and NOT Midnight. Built separately in BDO-AIO.' -ForegroundColor Yellow
    Write-Host '  Uses the unmodified official OptiScaler bundle only. High ban/crash risk.' -ForegroundColor Yellow
    Write-Host ''

    $ready = Test-ExperimentalDlssReady
    if ($ready.Ok) {
        Write-Ok 'Experimental pack found under experimental\dlss\'
    } else {
        Write-Err 'Experimental pack incomplete.'
        foreach ($m in $ready.Missing) { Write-Warn ("  " + $m) }
    }

    $gameRoot = Get-GameRootFromPaz
    if ($gameRoot) {
        Write-Info ("Game root: " + $gameRoot)
        if (Test-Path -LiteralPath (Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt')) {
            Write-Warn 'Marker found: experimental DLSS appears INSTALLED in game root.'
        }
    } else {
        Write-Warn 'Game PAZ not set — set menu 1 before install.'
    }

    Write-Host ''
    Write-Host '   [1] Read WARNING.txt' -ForegroundColor Red
    Write-Host '   [2] Read experimental README' -ForegroundColor Yellow
    Write-Host '   [3] INSTALL official OptiScaler 0.9.4 + bundled Streamline  *** NOT SAFE ***' -ForegroundColor Red
    Write-Host '   [4] UNINSTALL experimental DLLs from game folder' -ForegroundColor Cyan
    Write-Host '   [5] Open experimental\dlss folder' -ForegroundColor Cyan
    Write-Host '   [0] Back' -ForegroundColor DarkGray
    Write-Host ''
    $c = (Read-Host '  Select').Trim()
    switch ($c) {
        '1' {
            $w = Join-Path $Script:ExperimentalDlssDir 'WARNING.txt'
            if (Test-Path -LiteralPath $w) { Start-Process notepad.exe -ArgumentList $w }
            Pause-Any
            Show-ExperimentalDlssMenu
        }
        '2' {
            $r = Join-Path $Script:ExperimentalDlssDir 'README.txt'
            if (Test-Path -LiteralPath $r) { Start-Process notepad.exe -ArgumentList $r }
            Pause-Any
            Show-ExperimentalDlssMenu
        }
        '3' { Install-ExperimentalDlss }
        '4' { Uninstall-ExperimentalDlss }
        '5' {
            if (Test-Path -LiteralPath $Script:ExperimentalDlssDir) {
                Start-Process explorer.exe -ArgumentList $Script:ExperimentalDlssDir
            }
            Pause-Any
            Show-ExperimentalDlssMenu
        }
        default { return }
    }
}

function Resolve-NpiInteractive {
    $found = Find-NvidiaProfileInspector
    if ($found) { return $found }

    Write-Warn 'nvidiaProfileInspector.exe not found automatically.'
    Write-Info 'Pick the EXE (often under Documents\Apps\NvidiaProfileInspector).'
    Write-Host '    [B] Browse for nvidiaProfileInspector.exe' -ForegroundColor Cyan
    Write-Host '    [M] Type full path manually' -ForegroundColor Cyan
    Write-Host '    [0] Cancel' -ForegroundColor DarkGray
    $pick = (Read-Host '  Choice').Trim().ToUpperInvariant()
    if ($pick -eq '0' -or [string]::IsNullOrEmpty($pick)) { return $null }

    if ($pick -eq 'B') {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Title = 'Select nvidiaProfileInspector.exe'
            $dlg.Filter = 'NVIDIA Profile Inspector|nvidiaProfileInspector.exe|EXE|*.exe'
            $dlg.FileName = 'nvidiaProfileInspector.exe'
            $start = Join-Path $env:USERPROFILE 'Documents\Apps\NvidiaProfileInspector'
            if (Test-Path -LiteralPath $start) { $dlg.InitialDirectory = $start }
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                if (Test-Path -LiteralPath $dlg.FileName) {
                    $Script:Config.npiPath = $dlg.FileName
                    Save-Config
                    return $dlg.FileName
                }
            }
        } catch {
            Write-Warn 'Folder dialog failed; use manual path.'
            $pick = 'M'
        }
    }

    if ($pick -eq 'M') {
        $manual = (Read-Host '  Full path to nvidiaProfileInspector.exe').Trim().Trim('"')
        if (Test-Path -LiteralPath $manual) {
            $Script:Config.npiPath = $manual
            Save-Config
            return $manual
        }
        Write-Err 'Path not found.'
    }
    return $null
}

function Apply-NvidiaProfile {
    Write-Banner
    Write-Host '  NVIDIA Profile Inspector (.nip)' -ForegroundColor White
    Write-Host '  --------------------------------' -ForegroundColor DarkGray
    Write-Info 'Imports Black_Desert_Max_Quality.nip for blackdesert64.exe'
    Write-Warn 'Close Black Desert before importing. NVIDIA GPU required.'
    Write-Host ''

    $nip = Test-NipReady
    if (-not $nip.Ok) {
        Write-Err ("Missing bundled profile: " + $nip.Path)
        Pause-Any
        return
    }
    Write-Ok ("NIP file : " + $nip.Path)

    $npi = Resolve-NpiInteractive
    if (-not $npi) {
        Write-Err 'Cannot import without nvidiaProfileInspector.exe'
        Write-Info 'Install NPI or place it under tools\nvidiaProfileInspector\ in this AIO folder.'
        Pause-Any
        return
    }
    Write-Ok ("NPI app  : " + $npi)
    Write-Host ''
    Write-Host '  Options' -ForegroundColor White
    Write-Host '    [1] Import .nip silently (recommended)' -ForegroundColor Cyan
    Write-Host '    [2] Open NPI GUI (manual import)' -ForegroundColor Cyan
    Write-Host '    [R] Open NIP README' -ForegroundColor Yellow
    Write-Host '    [0] Cancel' -ForegroundColor DarkGray
    Write-Host ''
    $pick = (Read-Host '  Select').Trim().ToUpperInvariant()
    if ($pick -eq '0' -or [string]::IsNullOrEmpty($pick)) { return }

    if ($pick -eq 'R') {
        $rm = Join-Path $Script:NvidiaDir 'README.txt'
        if (Test-Path -LiteralPath $rm) { Start-Process notepad.exe -ArgumentList $rm }
        Pause-Any
        return
    }

    if ($pick -eq '2') {
        Write-Info 'In NPI: Profile menu -> Import profile(s) -> select the .nip -> Apply changes'
        Start-Process -FilePath $npi -WorkingDirectory (Split-Path -Parent $npi)
        # Also open the folder containing the nip for easy drag
        Start-Process explorer.exe -ArgumentList ("/select," + $nip.Path)
        Write-Ok 'Opened NPI and highlighted the .nip file.'
        Pause-Any
        return
    }

    if ($pick -ne '1') {
        Write-Warn 'Invalid choice.'
        Pause-Any
        return
    }

    if (-not (Read-YesNo 'Import Black Desert max-quality driver profile now?' $true)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    Write-Info 'Running silent import...'
    try {
        # Official CLI: nvidiaProfileInspector.exe -silentImport "file.nip"
        $p = Start-Process -FilePath $npi -ArgumentList @('-silentImport', $nip.Path) -WorkingDirectory (Split-Path -Parent $npi) -PassThru -Wait
        if ($p.ExitCode -and $p.ExitCode -ne 0) {
            Write-Warn ("NPI exit code " + $p.ExitCode + " - trying plain import (opens UI)...")
            Start-Process -FilePath $npi -ArgumentList @($nip.Path) -WorkingDirectory (Split-Path -Parent $npi)
            Write-Info 'If a window opened, confirm Apply/Save in NPI.'
        } else {
            Write-Ok 'Import finished (silent). Driver profile "Black Desert" should be active for blackdesert64.exe.'
        }
        Write-Info 'Tip: After big GeForce driver updates, re-run menu N if settings reset.'
        Write-Info 'Pair with menu G (GameOption) + NVIDIA DSR if using DLDSR 4K profiles.'
    } catch {
        Write-Err $_.Exception.Message
        Write-Info 'Fallback: open NPI GUI and import the .nip manually (menu N option 2).'
    }
    Pause-Any
}

function Show-Guide2026 {
    Write-Banner
    Write-Host '  2026 - What is in THIS package vs what is not' -ForegroundColor White
    Write-Host '  =============================================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  INSIDE this AIO folder (publish as one zip)' -ForegroundColor Green
    Write-Host '  -------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  START.bat              double-click entry'
    Write-Host '  bdo_aio.ps1            menu / wizard'
    Write-Host '  config.json            remembers YOUR game path + choices'
    Write-Host '  pack\                  Midnight mods + PartCutGen + Meta Injector'
    Write-Host '  graphics\              GameOption max-quality profiles'
    Write-Host '  graphics\nvidia\       Black_Desert_Max_Quality.nip'
    Write-Host '  tools\nvidiaProfileInspector\   NPI app (bundled when present)'
    Write-Host '  experimental\dlss\     OptiScaler + Streamline  [EXPERIMENTAL / NOT SAFE]'
    Write-Host '  README.md / CREDITS.md docs'
    Write-Host ''
    Write-Host '  NOT in the zip (user must have)' -ForegroundColor Yellow
    Write-Host '  -------------------------------' -ForegroundColor DarkGray
    Write-Host '  Black Desert Online install (PAZ folder)'
    Write-Host '  Documents\Black Desert (created/used for GameOption.txt)'
    Write-Host '  Python 3 (python.exe, py launcher, or normal per-user install)'
    Write-Host '  BDO Toolkit 1.3.0 (required by bundled Meta Injector 1.4.1)'
    Write-Host '  Meta Patcher 1.1.0: not needed on NA/EU; other official regions may require it'
    Write-Host '  NVIDIA GPU + driver (for .nip import / DLSS path)'
    Write-Host ''
    Write-Host '  REDUNDANT / creator-only (not bundled)' -ForegroundColor Yellow
    Write-Host '  --------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Resorepless UI, PAZ Unpacker/Browser, PACtool, 3D Converter,'
    Write-Host '  old 0.3.0 pack, SkyrimUpscaler (wrong game)'
    Write-Host ''
    Write-Host '  PIPELINE' -ForegroundColor White
    Write-Host '  --------' -ForegroundColor DarkGray
    Write-Host '  NA/EU: Deploy -> PartCutGen -> canonical stage -> Meta Injector -> Launch'
    Write-Host '  GFX : Menu G -> GameOption.txt'
    Write-Host '  NPI : Menu N -> import .nip driver profile'
    Write-Host '  DLSS: Menu X -> EXPERIMENTAL OptiScaler (NOT SAFE)'
    Write-Host ''
    Write-Host '  RISK: client mods can break after patches and may violate ToS.' -ForegroundColor Red
    Write-Host '  Menu X is EXTRA risky (DLL inject / ban potential).' -ForegroundColor Red
    Write-Host ''
    Pause-Any
}

function Show-VerifyPack {
    Write-Banner
    Write-Host '  Verify bundled content (publisher / integrity)' -ForegroundColor White
    Write-Host '  ----------------------------------------------' -ForegroundColor DarkGray

    $pack = Test-PackReady
    Write-Info ("Pack folder: " + $Script:PackDir)
    if ($pack.Ok) {
        Write-Ok 'Mod pack tools present.'
        $fileCount = (Get-ChildItem -LiteralPath $Script:PackDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $mb = (Get-ChildItem -LiteralPath $Script:PackDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        Write-Host ("  Files : " + $fileCount) -ForegroundColor Gray
        Write-Host ("  Size  : {0:N1} MB" -f $mb) -ForegroundColor Gray
        if ($mb -lt 500) {
            Write-Warn 'Pack looks small (expected ~1.5-2 GB with full Midnight content). Zip may be incomplete.'
        }
    } else {
        Write-Err 'Mod pack incomplete:'
        foreach ($m in $pack.Missing) { Write-Warn ("  " + $m) }
    }

    Write-Host ''
    $gfx = Test-GraphicsReady
    Write-Info ("Graphics folder: " + $Script:GraphicsDir)
    if ($gfx.Ok) {
        Write-Ok 'All 3 GameOption merge patches and the safe patcher are present.'
        foreach ($name in $Script:GraphicsProfiles.Keys) {
            $p = Join-Path $Script:GraphicsDir $name
            $len = (Get-Item -LiteralPath $p).Length
            Write-Host ("  " + $name + "  (" + $len + " bytes)") -ForegroundColor Gray
        }
    } else {
        Write-Err 'Graphics pack incomplete:'
        foreach ($m in $gfx.Missing) { Write-Warn ("  " + $m) }
    }

    Write-Host ''
    $nip = Test-NipReady
    $npi = Find-NvidiaProfileInspector
    Write-Info ("NVIDIA folder: " + $Script:NvidiaDir)
    if ($nip.Ok) {
        Write-Ok ("NIP present: " + $nip.Path + "  (" + (Get-Item -LiteralPath $nip.Path).Length + " bytes)")
    } else {
        Write-Err ("NIP missing: " + $nip.Path)
    }
    if ($npi) {
        Write-Ok ("NPI present: " + $npi)
    } else {
        Write-Warn 'NPI missing: put nvidiaProfileInspector.exe in tools\nvidiaProfileInspector\ or set path via menu N'
    }

    Write-Host ''
    Write-Host '  EXPERIMENTAL DLSS pack (NOT SAFE)' -ForegroundColor Red
    $ex = Test-ExperimentalDlssReady
    if ($ex.Ok) {
        Write-Ok 'OptiScaler + Streamline present under experimental\dlss\'
        $mb = (Get-ChildItem -LiteralPath $Script:ExperimentalDlssDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        Write-Host ("  Size ~ {0:N0} MB" -f $mb) -ForegroundColor Gray
    } else {
        Write-Err 'Experimental DLSS pack incomplete:'
        foreach ($m in $ex.Missing) { Write-Warn ("  " + $m) }
    }
    Pause-Any
}

function Get-BdoMetaVersion {
    <#
      The client version the launcher checks, stored as a uint32 at offset 0 of
      pad00000.meta. Four bytes -- no need to parse 861k blocks.
    #>
    param([string]$PazFolder)
    $meta = Join-Path $PazFolder 'pad00000.meta'
    if (-not (Test-Path -LiteralPath $meta)) { return 0 }
    try {
        $fs = [System.IO.File]::OpenRead($meta)
        try {
            $buf = New-Object byte[] 4
            if ($fs.Read($buf, 0, 4) -ne 4) { return 0 }
            return [BitConverter]::ToUInt32($buf, 0)
        } finally { $fs.Dispose() }
    } catch { return 0 }
}

function Warn-IfClientPatched {
    <#
      A client patch replaces pad00000.meta outright, which silently wipes every
      injection and strands its archives on disk. Measured 2026-08-27: client
      3412 -> 3418 did exactly that, and the only visible symptom was the game
      reporting corrupted files. Say it out loud instead.
    #>
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { return }
    $now = Get-BdoMetaVersion -PazFolder ([string]$Script:Config.pazFolder)
    if ($now -eq 0) { return }
    $seen = 0
    if ($Script:Config.PSObject.Properties.Name -contains 'lastMetaVersion') {
        $seen = [int]$Script:Config.lastMetaVersion
    }
    if ($seen -and $seen -ne $now) {
        Write-Host ''
        Write-Warn ("THE GAME PATCHED since your last inject (client " + $seen + " -> " + $now + ").")
        Write-Host '  A patch replaces pad00000.meta, so your mods are no longer live and their' -ForegroundColor Yellow
        Write-Host '  archives are orphaned on disk. Any vanilla snapshot from the old client is' -ForegroundColor Yellow
        Write-Host '  now STALE - restoring it would make the launcher re-download the meta.' -ForegroundColor Yellow
        Write-Host '  Do: [R] scan -> delete orphans -> re-snapshot vanilla -> re-apply AIO.' -ForegroundColor Cyan
        Write-Host ''
        $Script:Config.lastMetaVersion = $now
        Save-Config
        Pause-Any
    } elseif (-not $seen) {
        $Script:Config.lastMetaVersion = $now
        Save-Config
    }
}

function Show-MainMenu {
    while ($true) {
        Write-Banner
        Show-Status
        Write-Host ("  MENU  (BDO-AIO " + $Script:Version + ')') -ForegroundColor White
        Write-Host '  ------------------' -ForegroundColor DarkGray
        Write-Host '   [1] Set / find game PAZ folder' -ForegroundColor Cyan
        Write-Host '   [2] Options hub  (MODERN + RESTORED)' -ForegroundColor Cyan
        Write-Host '   [3] Deploy Midnight mods  ->  files_to_patch     [MODERN]' -ForegroundColor Cyan
        Write-Host '   [4] Run PartCutGen        (required)             [MODERN]' -ForegroundColor Cyan
        Write-Host '   [5] Run Meta Injector     (apply patch)          [MODERN]' -ForegroundColor Cyan
        Write-Host '   [6] FULL WIZARD           (Midnight + RESTORED)  [MODERN]' -ForegroundColor Green
        Write-Host '   [A] Apply ALL RESTORED choices (from config)     [RESTORED]' -ForegroundColor Green
        Write-Host '   [7] Open files_to_patch   (add extra mods)' -ForegroundColor Cyan
        Write-Host '   [S] Scan PAZ status (stock / staged / injected / restored)' -ForegroundColor Yellow
        Write-Host '   [H] Post-patch regen helper (heisha / Midnight)' -ForegroundColor Yellow
        Write-Host '   [R] Restore / clean AIO changes (troubleshooting)' -ForegroundColor Yellow
        Write-Host '   [G] Graphics profiles (GameOption)               [user pack]' -ForegroundColor Magenta
        Write-Host '   [N] NVIDIA .nip (Profile Inspector)              [user pack]' -ForegroundColor Magenta
        Write-Host '   [X] EXPERIMENTAL upscale (official OptiScaler bundle) *** NOT SAFE ***' -ForegroundColor Red
        Write-Host '   [8] 2026 guide + feature labels' -ForegroundColor Yellow
        Write-Host '   [9] Verify pack integrity' -ForegroundColor Yellow
        Write-Host '   [0] Exit' -ForegroundColor DarkGray
        Write-Host ''
        $c = Read-Host '  Select'
        switch ($c.Trim().ToUpperInvariant()) {
            '1' { Set-PazFolder }
            '2' { Configure-ModChoices }
            '3' { [void](Deploy-Midnight) }
            '4' { [void](Run-PartCutGen) }
            '5' { [void](Run-MetaInjector) }
            '6' { [void](Run-FullWizard) }
            'A' { [void](Apply-AllRestoredChoices) }
            '7' { Open-FilesToPatch }
            'S' {
                Write-Banner
                if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
                    Write-Err 'Set PAZ first (menu 1).'
                } else {
                    Show-PazInjectStatus -PazFolder ([string]$Script:Config.pazFolder) -Detailed
                }
                Pause-Any
            }
            'H' { Show-HeishaRegenHelper }
            'R' { Restore-UneditedGameFiles }
            'G' { Apply-GraphicsProfile }
            'N' { Apply-NvidiaProfile }
            'X' { Show-ExperimentalDlssMenu }
            '8' { Show-Guide2026 }
            '9' { Show-VerifyPack }
            '0' { return }
            default { Write-Warn 'Unknown option.'; Start-Sleep -Milliseconds 600 }
        }
    }
}

# Importing the engine only defines functions. It never opens a menu or touches PAZ.
if ($MyInvocation.InvocationName -eq '.') { return }

$operation = [ordered]@{ schema = 1; action = $Action; state = 'running'; startedAt = [DateTime]::UtcNow.ToString('o'); finishedAt = $null; error = $null; injectReport = $null }
$operationMutex = New-Object Threading.Mutex($false, 'Local\BDO-AIO-PatchOperation')
$operationLock = $false
$transcribing = $false
$operationExit = 0
try {
    # ponytail: serialize launcher sessions; per-install locks only if multi-game use is needed.
    try { $operationLock = $operationMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $operationLock = $true }
    if (-not $operationLock) { throw 'Another BDO-AIO tool session is open. Finish or close it first.' }
    if ($ResultFile) {
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $ResultFile) -Force
        $null = Start-Transcript -LiteralPath ($ResultFile + '.log')
        $transcribing = $true
        Write-MetaInjectReport -Report $operation -Path $ResultFile
    }
    Load-Config
    # Native previews report their own state; the classic warning saves config and
    # can pause for input, neither of which belongs in a hidden/read-only action.
    $nativeNoPrompt = $Action -in @('RecoveryPlan', 'RecoveryRestore', 'RecoverySnapshot', 'RecoveryCleanup', 'GraphicsPlan', 'GraphicsApply')
    if (-not $nativeNoPrompt) { Warn-IfClientPatched }
    $result = $null
    switch ($Action) {
        'Menu' { Show-MainMenu }
        'Wizard' { $result = Run-FullWizard -NoPrompt:$Script:DashboardAction }
        'Deploy' { $result = Deploy-Midnight }
        'PartCut' { $result = Run-PartCutGen }
        'Inject' { $result = Run-MetaInjector }
        'Restored' { $result = Apply-AllRestoredChoices }
        'Options' { Configure-ModChoices }
        'Recovery' { Restore-UneditedGameFiles }
        'RecoveryPlan' { $operation['recoveryPlan'] = Invoke-RecoveryJson @('recovery-plan'); $result = $true }
        'RecoveryRestore' { $operation['recoveryResult'] = Invoke-NativeRecovery -Operation restore -Token $RecoveryToken -Confirmed:$RecoveryConfirmed; $result = $true }
        'RecoverySnapshot' { $operation['recoveryResult'] = Invoke-NativeRecovery -Operation snapshot -Token $RecoveryToken -Confirmed:$RecoveryConfirmed; $result = $true }
        'RecoveryCleanup' { $operation['recoveryResult'] = Invoke-NativeRecovery -Operation cleanup -Token $RecoveryToken -Confirmed:$RecoveryConfirmed; $result = $true }
        'GraphicsPlan' { $operation['graphicsPlan'] = Get-NativeGraphicsPlan -Profile $GraphicsProfile; $result = $true }
        'GraphicsApply' { $operation['graphicsResult'] = Invoke-NativeGraphics -Profile $GraphicsProfile -Token $GraphicsToken -Confirmed:$GraphicsConfirmed; $result = $true }
        'Graphics' { Apply-GraphicsProfile }
        'Nvidia' { Apply-NvidiaProfile }
        'Dlss' { Show-ExperimentalDlssMenu }
        'Guide' { Show-Guide2026 }
        'VerifyPack' { Show-VerifyPack }
        'VerifyMeta' { $result = Invoke-VanillaRestoreTool @('verify') }
        'Regen' { Show-HeishaRegenHelper }
    }
    $operation['state'] = if ($result -is [bool]) { if ($result) { 'completed' } else { 'stopped' } } else { 'finished' }
    if ($result -is [bool] -and -not $result) { $operationExit = 1 }
} catch {
    $operation['state'] = 'failed'
    $operation['error'] = $_.Exception.Message
    $operationExit = 1
    Write-Err $_.Exception.Message
    if (-not $Script:DashboardAction) { Pause-Any }
} finally {
    $operation['finishedAt'] = [DateTime]::UtcNow.ToString('o')
    $operation['injectReport'] = $Script:LastMetaInjectReportPath
    if ($ResultFile) { Write-MetaInjectReport -Report $operation -Path $ResultFile }
    if ($transcribing) { $null = Stop-Transcript }
    if ($operationLock) { $operationMutex.ReleaseMutex() }
    $operationMutex.Dispose()
}
exit $operationExit
