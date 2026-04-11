<#
    Windows bootstrap — nix-darwin-config port
    Installs: winget apps, scoop + CLI fallbacks, fonts, komorebi, whkd,
              WezTerm config, WSL2 (Ubuntu) for the Nix flake.

    Runs on Windows PowerShell 5.1+ (stock) or PowerShell 7.
    From an elevated prompt, in this directory:
        Set-ExecutionPolicy -Scope Process Bypass -Force
        .\bootstrap.ps1

    Note: winget.json includes Microsoft.PowerShell — after the first run,
    subsequent use should prefer `pwsh`.
#>

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$WinDir   = Join-Path $RepoRoot 'windows'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Test-Command($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# ─── 1. winget ────────────────────────────────────────────────────────────
Write-Step 'Installing winget packages'
if (-not (Test-Command winget)) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store first.'
}
winget import --import-file (Join-Path $WinDir 'winget.json') `
              --accept-package-agreements --accept-source-agreements `
              --ignore-unavailable --ignore-versions

# ─── 2. Scoop ─────────────────────────────────────────────────────────────
Write-Step 'Installing Scoop'
if (-not (Test-Command scoop)) {
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

Write-Step 'Adding Scoop buckets'
scoop bucket add extras     2>$null
scoop bucket add nerd-fonts 2>$null

Write-Step 'Installing Scoop packages'
$scoopList = Get-Content (Join-Path $WinDir 'scoop-packages.txt') |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    ForEach-Object { $_.Trim().Split('#')[0].Trim() } |
    Where-Object { $_ }
foreach ($pkg in $scoopList) {
    scoop install $pkg
}

# ─── 3. Deploy configs ────────────────────────────────────────────────────
Write-Step 'Deploying WezTerm config'
$weztermTarget = Join-Path $env:USERPROFILE '.wezterm.lua'
Copy-Item -Force (Join-Path $WinDir 'wezterm\wezterm.lua') $weztermTarget

Write-Step 'Deploying komorebi config'
$komorebiDir = Join-Path $env:USERPROFILE '.config\komorebi'
New-Item -ItemType Directory -Force -Path $komorebiDir | Out-Null
Copy-Item -Force (Join-Path $WinDir 'komorebi.json') (Join-Path $komorebiDir 'komorebi.json')

Write-Step 'Deploying whkd config'
$whkdDir = Join-Path $env:USERPROFILE '.config\whkdrc'
New-Item -ItemType Directory -Force -Path (Split-Path $whkdDir) | Out-Null
Copy-Item -Force (Join-Path $WinDir 'whkdrc') $whkdDir

# ─── 4. Start komorebi + whkd ─────────────────────────────────────────────
Write-Step 'Starting komorebi + whkd (one-shot; use komorebic start-plus-whkd later)'
if (Test-Command komorebic) {
    komorebic start --whkd
} else {
    Write-Warning 'komorebic not on PATH — open a new shell and run: komorebic start --whkd'
}

# ─── 5. WSL2 + Ubuntu ─────────────────────────────────────────────────────
Write-Step 'Enabling WSL2 + installing Ubuntu'
if (-not (wsl --status 2>$null)) {
    wsl --install -d Ubuntu
    Write-Host 'WSL2 installed. A reboot may be required before continuing.' -ForegroundColor Yellow
} else {
    Write-Host 'WSL2 already present — skipping.' -ForegroundColor Green
    wsl --list --verbose
}

Write-Step 'Done'
Write-Host @'

Next steps:

  1. Reboot if WSL2 was freshly installed.
  2. Launch Ubuntu, create your user, then inside WSL run:
       bash <(curl -L https://nixos.org/nix/install) --daemon
       nix run nixpkgs#home-manager -- switch --flake ~/nix-darwin-config#wsl
     (see windows/WSL2.md for flake adaptation notes)
  3. Windows-side only:
       - komorebic start --whkd      # start tiling WM + hotkeys
       - wezterm                      # launch terminal
'@ -ForegroundColor Green
