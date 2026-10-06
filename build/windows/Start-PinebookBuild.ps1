<#
.SYNOPSIS
Runs the ChromiumOS build for the Pinebook Pro inside WSL2 from Windows.

.DESCRIPTION
Calls build/linux/preflight.sh, sync.sh and build.sh inside a WSL2 distro.
The ChromiumOS checkout stays on the Linux filesystem inside WSL
(~/chromiumos by default); only the finished image is written to OutputDir,
which defaults to the output\ folder of this repository on Windows.

.PARAMETER Step
Which steps to run: Preflight, Sync, Build or All (default). Several are allowed.

.PARAMETER Stage
Build stages passed to build.sh (overlay, sdk, board, packages, image).
Default: all of them.

.PARAMETER Board
Board to build. Default: BOARD_NAME from boards/pinebook-pro-rk3399/board.conf.
arm64-generic is useful for trying the SDK before the board overlay exists.

.PARAMETER Distro
WSL distro to use. Default: the default WSL distro.

.PARAMETER ImageType
base, dev or test (default). A test image allows SSH and root login, which
helps while porting.

.PARAMETER ChromiumOSRoot
Linux path of the ChromiumOS checkout inside WSL. Default: ~/chromiumos.
Must not be under /mnt/c, /mnt/d and so on.

.PARAMETER ManifestBranch
ChromiumOS manifest branch, e.g. stable, main or release-R130-16033.B.
Default: stable, the newest main snapshot with prebuilt binaries (on main,
Chrome usually has no prebuilt and is compiled from source for hours).

.PARAMETER OutputDir
Windows folder for the image and logs. Default: <repo>\output.

.PARAMETER DryRun
Print the commands without running them.

.EXAMPLE
pwsh -File .\build\windows\Start-PinebookBuild.ps1

.EXAMPLE
.\build\windows\Start-PinebookBuild.ps1 -Step Build -Stage packages,image -Distro Ubuntu-22.04
#>
[CmdletBinding()]
param(
    [ValidateSet('Preflight', 'Sync', 'Build', 'All')]
    [string[]]$Step = @('All'),

    [ValidateSet('overlay', 'sdk', 'board', 'packages', 'image')]
    [string[]]$Stage = @(),

    [string]$Board = '',

    [string]$Distro = '',

    [ValidateSet('base', 'dev', 'test')]
    [string]$ImageType = 'test',

    [string]$ChromiumOSRoot = '',

    [string]$ManifestBranch = '',

    [string]$OutputDir = '',

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path ([System.IO.Path]::Combine($PSScriptRoot, '..', '..'))).Path
if (-not $OutputDir) { $OutputDir = Join-Path $RepoRoot 'output' }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path $OutputDir).Path

$WslArgs = @()
if ($Distro) { $WslArgs = @('-d', $Distro) }

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# wsl.exe prints warnings (e.g. about %UserProfile%\.wslconfig) on stderr.
# Windows PowerShell 5.1 turns native stderr into errors, which
# $ErrorActionPreference = 'Stop' would make fatal, so judge native commands
# by their exit code only.
function Invoke-Wsl {
    param([Parameter(Mandatory)][string[]]$Command)
    $ErrorActionPreference = 'Continue'
    & wsl.exe @WslArgs -e @Command
    if ($LASTEXITCODE -ne 0) {
        throw "WSL command failed with exit code ${LASTEXITCODE}: $($Command -join ' ')"
    }
}

function ConvertTo-WslPath([string]$WindowsPath) {
    $ErrorActionPreference = 'Continue'
    $result = & wsl.exe @WslArgs -e wslpath -a $WindowsPath 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $result) {
        throw "wslpath could not convert '$WindowsPath'."
    }
    return ($result | Select-Object -First 1).Trim()
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'wsl.exe not found. Install WSL2 first: wsl --install -d Ubuntu-22.04'
}

# Scripts checked out with CRLF line endings fail in bash with "$'\r': command not found".
$probe = [System.IO.Path]::Combine($RepoRoot, 'build', 'linux', 'common.sh')
if ([System.IO.File]::ReadAllText($probe).Contains("`r`n")) {
    throw @"
build\linux\*.sh have Windows (CRLF) line endings and will not run in bash.
Re-checkout them with LF endings from the repository root:
  Remove-Item build\linux\*.sh
  git checkout -- build/linux
"@
}

$RepoWsl = ConvertTo-WslPath $RepoRoot
$OutputWsl = ConvertTo-WslPath $OutputDir

$envArgs = @('env', "IMAGE_TYPE=$ImageType", "OUTPUT_DIR=$OutputWsl")
if ($Board) { $envArgs += "BOARD=$Board" }
if ($ChromiumOSRoot) { $envArgs += "CHROMIUMOS_ROOT=$ChromiumOSRoot" }
if ($ManifestBranch) { $envArgs += "MANIFEST_BRANCH=$ManifestBranch" }
if ($DryRun) { $envArgs += 'DRY_RUN=1' }

$runAll = $Step -contains 'All'
$started = Get-Date

if ($runAll -or $Step -contains 'Preflight') {
    Write-Step 'Preflight checks'
    Invoke-Wsl ($envArgs + @('bash', "$RepoWsl/build/linux/preflight.sh"))
}
if ($runAll -or $Step -contains 'Sync') {
    Write-Step 'Syncing ChromiumOS source'
    Invoke-Wsl ($envArgs + @('bash', "$RepoWsl/build/linux/sync.sh"))
}
if ($runAll -or $Step -contains 'Build') {
    Write-Step 'Building ChromiumOS'
    Invoke-Wsl ($envArgs + @('bash', "$RepoWsl/build/linux/build.sh") + $Stage)
}

$elapsed = (Get-Date) - $started
Write-Step ("Done in {0:hh\:mm\:ss}" -f $elapsed)

$images = Get-ChildItem -Path (Join-Path $OutputDir 'images') -Filter '*.bin' -ErrorAction SilentlyContinue
if ($images) {
    $images | ForEach-Object { Write-Host "Image: $($_.FullName)" }
    Write-Host 'Write it to a microSD card with balenaEtcher, Rufus or Raspberry Pi Imager (see docs/WINDOWS_BUILD.md).'
}
Write-Host "Logs: $(Join-Path $OutputDir 'logs')"
