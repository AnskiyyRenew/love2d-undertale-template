<#
    Packager/setup/install.ps1 -- portable LOVE runtime installer for Windows.

    Downloads the LOVE build listed in setup.conf, unwraps it into
    Packager\tools\love and checks that it starts. Nothing is installed
    outside the repository, so deleting that folder is a clean uninstall.

    Use install.bat instead of calling this file directly (it bypasses the
    execution policy for you).

        install.bat              install or refresh
        install.bat -Check       environment report only, no download
        install.bat -Force       reinstall even if a copy exists
        install.bat -Url <url>   override the URL for this run only
        install.bat -Dest <dir>  override the target folder for this run only
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Check,
    [string]$Url,
    [string]$Dest
)

$ErrorActionPreference = 'Stop'
# Invoke-WebRequest otherwise redraws a progress bar for every received chunk
# and floods the console; the script prints its own one-line progress instead.
$ProgressPreference = 'SilentlyContinue'
try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop } catch { }
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$SetupDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackagerDir = Split-Path -Parent $SetupDir
$GameDir     = Split-Path -Parent $PackagerDir
$ConfPath    = Join-Path $SetupDir 'setup.conf'

function Write-Step([string]$text) { Write-Host ("`n== " + $text) }
function Write-Info([string]$text) { Write-Host "   $text" }
function Write-Warn([string]$text) { Write-Host "   [warn] $text" -ForegroundColor Yellow }
function Write-Fail([string]$text) { Write-Host "   [error] $text" -ForegroundColor Red }

function Read-Conf([string]$path) {
    $map = @{}
    if (-not (Test-Path -LiteralPath $path)) { return $map }
    foreach ($raw in Get-Content -LiteralPath $path -Encoding UTF8) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        $key = $line.Substring(0, $i).Trim()
        $val = $line.Substring($i + 1).Trim()
        $map[$key] = $val.Trim('"').Trim("'")
    }
    return $map
}

function Get-ConfValue($map, [string]$key, [string]$fallback) {
    if ($map.ContainsKey($key) -and $map[$key] -ne '') { return $map[$key] }
    return $fallback
}

function Resolve-LocalPath([string]$value, [string]$baseDir) {
    if ([System.IO.Path]::IsPathRooted($value)) { return [System.IO.Path]::GetFullPath($value) }
    return [System.IO.Path]::GetFullPath((Join-Path $baseDir $value))
}

# LOVE's own build ships lovec.exe (console subsystem) next to the GUI love.exe.
# Preferring it makes --version readable without a window.
function Get-LoveExe([string]$dir) {
    foreach ($name in @('lovec.exe', 'love.exe')) {
        $candidate = Join-Path $dir $name
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Get-LoveVersion([string]$dir) {
    $exe = Get-LoveExe $dir
    if (-not $exe) { return $null }
    try {
        $output = & $exe --version 2>&1
        $text = ($output | Out-String).Trim()
        if ($text) { return $text }
    } catch { }
    return $null
}

function Invoke-Download([string]$url, [string]$outFile) {
    $partial = "$outFile.part"
    if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $partial -UseBasicParsing -TimeoutSec 900
            Move-Item -LiteralPath $partial -Destination $outFile -Force
            return
        } catch {
            Write-Warn ('download attempt {0}/3 failed: {1}' -f $attempt, $_.Exception.Message)
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds 3
        }
    }
}

function Expand-Zip([string]$zip, [string]$dir) {
    # ZipFile instead of Expand-Archive: no progress bar, and no "directory
    # already exists" surprise when the target has files in it.
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir)
}

function Expand-Payload {
    param([string]$archive, [string]$destDir)

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('se-love-' + [Guid]::NewGuid().ToString('N'))
    try {
        Expand-Zip $archive $work

        # love's CI artifact is a zip containing another zip (plus a Windows
        # installer exe we do not want). Unwrap until love.exe shows up.
        $payload = $null
        $round = 0
        while ($round -lt 3) {
            $found = Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'love.exe' -ErrorAction SilentlyContinue |
                     Select-Object -First 1
            if ($found) { $payload = $found.Directory.FullName; break }

            $inner = Get-ChildItem -LiteralPath $work -Recurse -File -Filter '*.zip' -ErrorAction SilentlyContinue |
                     Select-Object -First 1
            if (-not $inner) { break }

            Write-Info ('unwrapping nested archive: ' + $inner.Name)
            $innerDir = Join-Path $work ('inner' + $round)
            Expand-Zip $inner.FullName $innerDir
            Remove-Item -LiteralPath $inner.FullName -Force
            $round++
        }

        if (-not $payload) { throw 'no love.exe found inside the archive' }

        if (Test-Path -LiteralPath $destDir) { Remove-Item -LiteralPath $destDir -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Copy-Item -Path (Join-Path $payload '*') -Destination $destDir -Recurse -Force
    } finally {
        if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
$cfg = Read-Conf $ConfPath
if (-not $cfg.ContainsKey('DEST')) { Write-Warn "setup.conf not found or empty, using built-in defaults" }

$arch = 'x64'
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { $arch = 'arm64' }

if (-not $Dest) { $Dest = Get-ConfValue $cfg 'DEST' 'tools/love' }
$destPath = Resolve-LocalPath $Dest $PackagerDir

if (-not $Url) {
    $Url = Get-ConfValue $cfg ('LOVE_WINDOWS_' + $arch.ToUpper()) ''
}

$cacheDir = Resolve-LocalPath (Get-ConfValue $cfg 'CACHE' 'tools/cache') $PackagerDir
$keepArchive = (Get-ConfValue $cfg 'KEEP_ARCHIVE' '0') -eq '1'

$installedExe = Get-LoveExe $destPath
$installedVer = if ($installedExe) { Get-LoveVersion $destPath } else { $null }

if ($Check) {
    Write-Host 'SoulEngine - LOVE environment report' -ForegroundColor Cyan
    Write-Step 'System'
    Write-Info ("platform      : Windows {0}" -f $arch)
    Write-Info ("powershell    : {0}" -f $PSVersionTable.PSVersion)
    Write-Info ("repo root     : {0}" -f $GameDir)

    Write-Step 'LOVE'
    Write-Info ("target        : {0}" -f $destPath)
    if ($installedExe) {
        Write-Info ("installed     : yes  ({0})" -f $installedExe)
        Write-Info ("version       : {0}" -f ($(if ($installedVer) { $installedVer } else { 'unknown' })))
    } else {
        Write-Info  'installed     : no'
        Write-Host  '   run install.bat to download it' -ForegroundColor Yellow
    }
    if ($Url) { Write-Info ("source        : {0}" -f $Url) } else { Write-Warn 'no download URL configured for this platform' }

    Write-Step 'Optional tooling'
    $git = Get-Command git -ErrorAction SilentlyContinue
    Write-Info ("git           : {0}" -f ($(if ($git) { $git.Source } else { 'not found (only needed to clone love-android)' })))
    $py = Get-Command python -ErrorAction SilentlyContinue
    Write-Info ("python        : {0}" -f ($(if ($py) { $py.Source } else { 'not found (only needed for the packager GUI)' })))
    $template = Join-Path $PackagerDir 'love-android'
    Write-Info ("love-android  : {0}" -f ($(if (Test-Path $template) { 'present' } else { 'missing (only needed for APK builds)' })))
    Write-Host ''
    exit 0
}

if ($installedExe -and -not $Force) {
    Write-Host 'LOVE is already installed - nothing to do.' -ForegroundColor Green
    Write-Info ("path    : {0}" -f $destPath)
    Write-Info ("version : {0}" -f ($(if ($installedVer) { $installedVer } else { 'unknown' })))
    Write-Host '   reinstall with: install.bat -Force'
    Write-Host '   run the game  : Packager\play.bat'
    exit 0
}

Write-Host 'SoulEngine - LOVE setup' -ForegroundColor Cyan
Write-Step 'Resolving download'
if (-not $Url) {
    Write-Fail ("no URL configured for Windows {0}" -f $arch)
    Write-Info  'set LOVE_WINDOWS_X64 (or LOVE_WINDOWS_ARM64) in Packager\setup\setup.conf'
    exit 1
}
Write-Info ("url  : {0}" -f $Url)
Write-Info ("dest : {0}" -f $destPath)

Write-Step 'Downloading'
if (-not (Test-Path -LiteralPath $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }
$archiveName = [System.IO.Path]::GetFileName(([Uri]$Url).AbsolutePath)
if (-not $archiveName) { $archiveName = 'love-win.zip' }
$archive = Join-Path $cacheDir $archiveName

if (Test-Path -LiteralPath $archive) {
    Write-Info ("using cached archive: {0}" -f $archive)
} else {
    Write-Info 'downloading (roughly 10-20 MB, a few seconds on a normal link)'
    Invoke-Download $Url $archive
    $sizeMb = [math]::Round((Get-Item -LiteralPath $archive).Length / 1MB, 1)
    Write-Info ("saved {0} MB" -f $sizeMb)
}

Write-Step 'Installing'
Expand-Payload -archive $archive -destDir $destPath

Write-Step 'Verifying'
$ok = $true
foreach ($name in @('love.exe', 'love.dll', 'SDL3.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $destPath $name))) {
        Write-Fail ("missing expected file: {0}" -f $name)
        $ok = $false
    }
}
if (-not $ok) { exit 1 }

$version = Get-LoveVersion $destPath
if (-not $version) {
    Write-Warn 'could not read the version string (the build may still work; check with play.bat)'
}

$infoLines = @(
    ('source   : ' + $Url),
    ('version  : ' + $(if ($version) { $version } else { 'unknown' })),
    ('installed: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
)
Set-Content -LiteralPath (Join-Path $destPath 'INSTALL_INFO.txt') -Value $infoLines -Encoding ASCII

if (-not $keepArchive -and (Test-Path -LiteralPath $archive)) {
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
}
if ((Test-Path -LiteralPath $cacheDir) -and -not (Get-ChildItem -LiteralPath $cacheDir -Force)) {
    Remove-Item -LiteralPath $cacheDir -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Info ("LOVE     : {0}" -f $destPath)
Write-Info ("version  : {0}" -f ($(if ($version) { $version } else { 'unknown' })))
Write-Info  'run      : Packager\play.bat'
Write-Info  'check    : Packager\setup\install.bat -Check'
exit 0
