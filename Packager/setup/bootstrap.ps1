<#
    Packager/setup/bootstrap.ps1 -- clone the repo and install LOVE, in one go.

    This is the entry point for a machine that does not have the repository yet
    (a fresh VM, for example). It is standalone: it does not read setup.conf and
    does not need to sit inside a checkout.

        bootstrap.bat                     clone into .\love2d-undertale-template,
                                          then install LOVE there
        bootstrap.bat -Dir D:\dev\se      clone somewhere else
        bootstrap.bat -Update             pull --ff-only in an existing clone
        bootstrap.bat -Zip                snapshot download, no git required
        bootstrap.bat -Full               full history instead of --depth 1
        bootstrap.bat -SkipLOVE           clone only
        bootstrap.bat -Check              report the environment of the clone

    The clone is shallow by default: the tracked tree is about 140 MB, the full
    history is roughly twice that and nobody needs it inside a test VM.
#>

[CmdletBinding()]
param(
    [string]$Dir,
    [string]$Branch = 'main',
    [string]$Repo = 'https://github.com/AnskiyyRenew/love2d-undertale-template.git',
    [switch]$Update,
    [switch]$Full,
    [switch]$Zip,
    [switch]$SkipLOVE,
    [switch]$Force,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop } catch { }
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

function Write-Step([string]$text) { Write-Host ("`n== " + $text) }
function Write-Info([string]$text) { Write-Host "   $text" }
function Write-Warn([string]$text) { Write-Host "   [warn] $text" -ForegroundColor Yellow }
function Write-Fail([string]$text) { Write-Host "   [error] $text" -ForegroundColor Red }

# "https://host/owner/repo.git", "git@host:owner/repo.git" and a local
# "D:\path\repo" all reduce to "repo".
$repoName = ($Repo -replace '\.git$', '')
$repoName = ($repoName -split '[/\\:]')[-1]
if (-not $repoName) { Write-Fail "cannot derive a folder name from $Repo"; exit 1 }

if (-not $Dir) { $Dir = Join-Path (Get-Location).Path $repoName }
$target = [System.IO.Path]::GetFullPath($Dir)

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
$useGit = ($gitCmd -ne $null) -and (-not $Zip)

Write-Host 'SoulEngine - repository bootstrap' -ForegroundColor Cyan
Write-Step 'Target'
Write-Info ("repo   : {0}" -f $Repo)
Write-Info ("branch : {0}" -f $Branch)
Write-Info ("dir    : {0}" -f $target)
Write-Info ("method : {0}" -f ($(if ($useGit) { 'git clone' } else { 'zip snapshot' })))

$cloned = Test-Path -LiteralPath (Join-Path $target 'conf.lua')

if ($cloned -and $Update) {
    Write-Step 'Updating existing clone'
    if (-not $gitCmd) {
        Write-Fail 'git is not installed, so this folder cannot be updated'
        Write-Info 'install git, or delete the folder and re-run without -Update'
        exit 1
    }
    if (-not (Test-Path -LiteralPath (Join-Path $target '.git'))) {
        Write-Fail 'this folder is not a git checkout (zip snapshot)'
        Write-Info 're-run with -Zip to refresh it, or delete it and clone normally'
        exit 1
    }
    & git -C $target pull --ff-only
    if ($LASTEXITCODE -ne 0) { Write-Fail 'git pull failed'; exit 1 }
} elseif ($cloned) {
    Write-Info ''
    Write-Info 'already cloned - skipping the download (use -Update to pull)'
} else {
    if (Test-Path -LiteralPath $target) {
        $existing = Get-ChildItem -LiteralPath $target -Force | Measure-Object
        if ($existing.Count -gt 0) {
            Write-Fail ("target folder is not empty: {0}" -f $target)
            Write-Info 'pick another -Dir, or empty that folder first'
            exit 1
        }
    }

    if ($useGit) {
        Write-Step 'Cloning'
        if ($Full) {
            & git clone --branch $Branch $Repo $target
        } else {
            & git clone --depth 1 --branch $Branch $Repo $target
        }
        if ($LASTEXITCODE -ne 0) { Write-Fail 'git clone failed'; exit 1 }
    } else {
        if (-not $Zip -and -not $gitCmd) {
            Write-Warn 'git is not installed - falling back to a zip snapshot'
            Write-Info 'Windows:  winget install --id Git.Git -e'
            Write-Info 'or get git from https://git-scm.com/downloads'
            Write-Info 'a snapshot cannot be updated with -Update; re-run -Zip to refresh'
        }

        # https://github.com/owner/repo(.git) -> codeload archive URL
        $slug = $null
        if ($Repo -match 'github\.com[/:](.+?)/(.+?)(\.git)?$') {
            $slug = $Matches[1] + '/' + ($Matches[2] -replace '\.git$', '')
        }
        if (-not $slug) {
            Write-Fail 'the zip fallback only understands github.com URLs'
            Write-Info 'install git instead, or pass -Repo with a github.com URL'
            exit 1
        }
        $zipUrl = "https://codeload.github.com/$slug/zip/refs/heads/$Branch"

        Write-Step 'Downloading snapshot'
        Write-Info ("url : {0}" -f $zipUrl)
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('se-repo-' + [Guid]::NewGuid().ToString('N'))
        $archive = "$tmp.zip"
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $archive -UseBasicParsing -TimeoutSec 900
            Write-Info ("saved {0} MB" -f [math]::Round((Get-Item -LiteralPath $archive).Length / 1MB, 1))

            Write-Step 'Extracting'
            New-Item -ItemType Directory -Force -Path $tmp | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($archive, $tmp)

            # The archive wraps everything in "<repo>-<branch>/".
            $root = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
            if (-not $root) { throw 'the snapshot contains no folder' }
            New-Item -ItemType Directory -Force -Path $target | Out-Null
            Copy-Item -Path (Join-Path $root.FullName '*') -Destination $target -Recurse -Force
        } finally {
            if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Write-Step 'Checking the checkout'
$conf = Join-Path $target 'conf.lua'
if (-not (Test-Path -LiteralPath $conf)) {
    Write-Fail ("conf.lua is missing in {0}" -f $target)
    Write-Info 'the clone looks incomplete - delete the folder and try again'
    exit 1
}
Write-Info 'conf.lua found - this is a SoulEngine checkout'

$installer = Join-Path $target 'Packager\setup\install.ps1'
if ($SkipLOVE) {
    Write-Info 'LOVE install skipped (-SkipLOVE)'
} elseif (-not (Test-Path -LiteralPath $installer)) {
    Write-Warn 'Packager\setup\install.ps1 not found in the checkout - skipping LOVE'
} else {
    Write-Step 'Installing LOVE'
    & $installer -Force:$Force -Check:$Check
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Info ("repo : {0}" -f $target)
Write-Info ("run  : cd `"{0}`"; Packager\play.bat" -f $target)
Write-Info  'env  : Packager\setup\install.bat -Check'
if (-not $useGit) { Write-Info 'note : zip snapshot - no git history and no -Update' }
exit 0
