<#
    Windows bootstrap — nix-windows-config
    Installs: winget apps, scoop + CLI fallbacks, fonts, GlazeWM, Alacritty
              config, WSL2 (Ubuntu) for the Nix flake.

    Runs on Windows PowerShell 5.1+ (stock) or PowerShell 7.
    From an elevated prompt, in this directory:
        Set-ExecutionPolicy -Scope Process Bypass -Force
        .\bootstrap.ps1

    Safe to re-run: every step is idempotent.

    Note: winget.json includes Microsoft.PowerShell — after the first run,
    subsequent use should prefer `pwsh`.
#>

[CmdletBinding()]
param(
    # Skip the WSL2 install/check (useful when re-running just the Windows side).
    [switch]$SkipWsl,

    # Skip the winget import. That step re-verifies every GUI app and takes
    # several minutes, so skip it when you only want to redeploy configs.
    [switch]$SkipWinget
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$WinDir   = Join-Path $RepoRoot 'windows'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host "    - $msg" -ForegroundColor DarkGray }
function Write-Ok($msg)   { Write-Host "    + $msg" -ForegroundColor Green }
function Test-Command($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# ─── 1. winget ────────────────────────────────────────────────────────────
Write-Step 'Installing winget packages'
if ($SkipWinget) {
    Write-Skip 'skipped (-SkipWinget)'
} else {
if (-not (Test-Command winget)) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store first.'
}
# winget import exits non-zero when a package is already installed or
# unavailable; that is not fatal for a re-run.
& winget import --import-file (Join-Path $WinDir 'winget.json') `
                --accept-package-agreements --accept-source-agreements `
                --ignore-unavailable --ignore-versions
if ($LASTEXITCODE -ne 0) {
    Write-Skip "winget import returned $LASTEXITCODE (already-installed/unavailable entries are expected)"
}
}

# ─── 2. Scoop ─────────────────────────────────────────────────────────────
Write-Step 'Installing Scoop'
if (Test-Command scoop) {
    Write-Skip 'scoop already installed'
} else {
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

Write-Step 'Adding Scoop buckets'
# Check the buckets directory directly instead of calling `scoop bucket list`:
# that shells out to `git config remote.origin.url` for every bucket, which can
# hang for minutes on a slow or filtered network (observed: 165s and counting).
# A bucket is just a directory under ~/scoop/buckets, so a path test is both
# faster and immune to network conditions.
$bucketRoot = Join-Path $env:USERPROFILE 'scoop\buckets'
foreach ($b in 'extras', 'nerd-fonts', 'sysinternals') {
    if (Test-Path (Join-Path $bucketRoot $b)) {
        Write-Skip "bucket $b already added"
    } else {
        & scoop bucket add $b
    }
}

Write-Step 'Installing Scoop packages'
$scoopList = Get-Content (Join-Path $WinDir 'scoop-packages.txt') |
    Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') } |
    ForEach-Object { $_.Trim().Split('#')[0].Trim() } |
    Where-Object { $_ }
$scoopFailed = @()
foreach ($pkg in $scoopList) {
    # A list entry may be bucket-qualified (sysinternals/autoruns) to
    # disambiguate; `scoop info` wants the bare name.
    $bare = $pkg.Split('/')[-1]
    # `scoop info` prints an "Installed : <version>" line only when the app is
    # present locally. Checking first keeps re-runs from aborting the script.
    $info = & scoop info $bare 2>$null | Out-String
    if ($info -match 'Installed\s*:\s*\d') {
        Write-Skip "$bare already installed"
    } else {
        & scoop install $pkg
        $info = & scoop info $bare 2>$null | Out-String
        if ($info -match 'Installed\s*:\s*\d') {
            Write-Ok "$bare installed"
        } else {
            $scoopFailed += $pkg
        }
    }
}
if ($scoopFailed) {
    Write-Warning "scoop could not install: $($scoopFailed -join ', ')"
    Write-Warning 'Check the names in windows/scoop-packages.txt against `scoop search <name>`.'
}

# ─── 3. Deploy configs ────────────────────────────────────────────────────
Write-Step 'Deploying Alacritty config'
$alacrittyDir = Join-Path $env:APPDATA 'alacritty'
New-Item -ItemType Directory -Force -Path $alacrittyDir | Out-Null
Copy-Item -Force (Join-Path $WinDir 'alacritty\alacritty.toml') `
                 (Join-Path $alacrittyDir 'alacritty.toml')
Write-Ok (Join-Path $alacrittyDir 'alacritty.toml')

Write-Step 'Deploying GlazeWM config'
$glazeDir    = Join-Path $env:USERPROFILE '.glzr\glazewm'
$glazeTarget = Join-Path $glazeDir 'config.yaml'
New-Item -ItemType Directory -Force -Path $glazeDir | Out-Null
if (Test-Path $glazeTarget) {
    # Never silently clobber a config the user may have tuned in place.
    Copy-Item -Force $glazeTarget "$glazeTarget.bak"
    Write-Skip "existing config backed up to config.yaml.bak"
}
Copy-Item -Force (Join-Path $WinDir 'glazewm\config.yaml') $glazeTarget
Write-Ok $glazeTarget

# ─── 4. Start GlazeWM + register autostart ────────────────────────────────
Write-Step 'Starting GlazeWM'
if (Get-Process glazewm -ErrorAction SilentlyContinue) {
    Write-Skip 'glazewm already running (use alt+shift+r to reload config)'
} elseif (Test-Command glazewm) {
    Start-Process glazewm -ArgumentList 'start' -WindowStyle Hidden
    Write-Ok 'glazewm started'
} else {
    Write-Warning 'glazewm not on PATH — open a new shell and run: glazewm start'
}

Write-Step 'Registering GlazeWM autostart'
$startup  = [Environment]::GetFolderPath('Startup')
$lnkPath  = Join-Path $startup 'GlazeWM.lnk'
$glazeExe = (Get-Command glazewm -ErrorAction SilentlyContinue).Source
if (-not $glazeExe) {
    Write-Warning 'glazewm not on PATH — skipping autostart shortcut'
} elseif (Test-Path $lnkPath) {
    Write-Skip 'startup shortcut already present'
} else {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $glazeExe
    $lnk.Arguments        = 'start'
    $lnk.WorkingDirectory = Split-Path -Parent $glazeExe
    $lnk.WindowStyle      = 7    # minimized
    $lnk.Description      = 'GlazeWM tiling window manager'
    $lnk.Save()
    Write-Ok $lnkPath
}

# ─── 5. WSL2 + Ubuntu ─────────────────────────────────────────────────────
if ($SkipWsl) {
    Write-Step 'Skipping WSL2 (-SkipWsl)'
} else {
    Write-Step 'Enabling WSL2 + installing Ubuntu'
    # `wsl` emits UTF-16, so strip NULs before testing. Note that
    # `wsl --list --quiet` exits 0 with EMPTY output when WSL itself is
    # installed but has no distributions - checking the exit code alone
    # would wrongly report success on a machine with no distro.
    $distros = (& wsl --list --quiet 2>$null | Out-String) -replace "`0", ''
    $distros = ($distros -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($distros) {
        Write-Skip "WSL distro(s) present: $($distros -join ', ')"
        & wsl --list --verbose
    } else {
        Write-Host '    no WSL distribution found - installing Ubuntu' -ForegroundColor Yellow
        & wsl --install -d Ubuntu
        Write-Host 'WSL2 installed. A reboot may be required before continuing.' -ForegroundColor Yellow
    }
}

Write-Step 'Done'
Write-Host @'

Next steps:

  1. Reboot if WSL2 was freshly installed.
  2. Launch Ubuntu and create your user, then run the WSL-side bootstrap.
     It installs Nix, registers the daemon, clones the repo, activates the
     home-manager generation, and smoke-tests the result:

       wsl -d Ubuntu
       bash /mnt/c/Users/blare/nix-windows-config/windows/wsl-bootstrap.sh

     (or clone the repo first and run `bash windows/wsl-bootstrap.sh`)
  3. Windows-side only:
       - glazewm start   # tiling WM + hotkeys (autostarts on login)
       - alacritty       # launch terminal (alt+enter)

  Verify with:  powershell -NoProfile -File windows\smoketest-windows.ps1
'@ -ForegroundColor Green
