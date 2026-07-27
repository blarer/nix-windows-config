# Windows-side smoke test for the nix-windows-config port.
# Run from elevated or normal PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\smoketest-windows.ps1
#
# Exits non-zero if any check fails, so it can gate a re-bootstrap.

$script:Failures = 0

function Heading($t) {
    Write-Host ""
    Write-Host "== $t ==" -ForegroundColor Cyan
}

function Pass($m) { Write-Host "  + $m" -ForegroundColor Green }
function Fail($m) { $script:Failures++; Write-Host "  - $m" -ForegroundColor Red }
function Info($m) { Write-Host "    $m" -ForegroundColor DarkGray }

Heading "GlazeWM process"
$glaze = Get-Process glazewm -ErrorAction SilentlyContinue
if ($glaze) {
    Pass "glazewm running (PID $($glaze.Id -join ','))"
    Info $glaze.Path
} else {
    Fail "glazewm NOT running  (start it with: glazewm start)"
}

Heading "GlazeWM config"
$repoCfg  = Join-Path $PSScriptRoot 'glazewm\config.yaml'
$liveCfg  = Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml'
if (Test-Path $liveCfg) {
    Pass $liveCfg
    if (Test-Path $repoCfg) {
        $a = (Get-FileHash $liveCfg).Hash
        $b = (Get-FileHash $repoCfg).Hash
        if ($a -eq $b) {
            Pass "live config matches repo copy"
        } else {
            Fail "live config DIVERGED from repo copy (windows\glazewm\config.yaml)"
            Info "diff:  fc `"$liveCfg`" `"$repoCfg`""
        }
    } else {
        Fail "repo copy missing: $repoCfg"
    }
} else {
    Fail "$liveCfg MISSING"
}

Heading "GlazeWM autostart"
$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'GlazeWM.lnk'
if (Test-Path $lnk) { Pass $lnk } else { Fail "startup shortcut MISSING - glazewm will not survive a reboot" }

Heading "Stale komorebi/whkd leftovers"
foreach ($p in 'komorebi', 'whkd') {
    if (Get-Process -Name $p -ErrorAction SilentlyContinue) {
        Fail "$p still running - it will fight GlazeWM for window control"
    } else {
        Pass "$p not running"
    }
}

Heading "WSL distros"
# `wsl --list --quiet` exits 0 with empty output when WSL is present but has
# no distributions installed, so test the parsed output rather than the code.
$distros = ((& wsl --list --quiet 2>$null | Out-String) -replace "`0", '') -split "`r?`n" |
           ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($distros) {
    foreach ($d in $distros) { Pass $d }
} else {
    Fail "no WSL distribution installed - the flake's #wsl config has nowhere to run"
    Info "fix:  wsl --install -d Ubuntu   (then see windows\WSL2.md)"
}

Heading "Alacritty"
$alaExe = @(
    (Get-Command alacritty.exe -ErrorAction SilentlyContinue).Source,
    "$env:ProgramFiles\Alacritty\alacritty.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($alaExe) { Pass $alaExe } else { Fail "alacritty.exe not found" }

$repoAla = Join-Path $PSScriptRoot 'alacritty\alacritty.toml'
$liveAla = Join-Path $env:APPDATA 'alacritty\alacritty.toml'
if (Test-Path $liveAla) {
    Pass $liveAla
    if ((Test-Path $repoAla) -and
        (Get-FileHash $liveAla).Hash -ne (Get-FileHash $repoAla).Hash) {
        Fail "live alacritty.toml DIVERGED from repo copy"
    }
} else {
    Fail "$liveAla MISSING - alacritty is running on defaults"
}

# The terminal keybinding is only useful if it points at an installed program.
$termBind = Select-String -Path (Join-Path $PSScriptRoot 'glazewm\config.yaml') `
                          -Pattern "shell-exec\s+(\S+)'" |
            ForEach-Object { $_.Matches[0].Groups[1].Value }
if ($termBind -contains 'alacritty') {
    Pass "alt+enter -> alacritty"
} else {
    Fail "alt+enter does not launch alacritty (found: $($termBind -join ', '))"
}

Heading "Winget apps"
$apps = @(
    'Anthropic.Claude',
    'Alacritty.Alacritty',
    'Brave.Brave',
    'Microsoft.PowerShell',
    'GitHub.cli',
    'Anysphere.Cursor',
    'Obsidian.Obsidian',
    'Ollama.Ollama',
    'Spotify.Spotify',
    'Valve.Steam',
    'OBSProject.OBSStudio',
    'Bitwarden.Bitwarden'
)
foreach ($id in $apps) {
    # winget list returns 0 if package found, non-zero otherwise.
    # Output is UTF-16 with cell padding so pattern matching is unreliable.
    & winget list --id $id --exact --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) { Pass $id } else { Fail "$id MISSING" }
}

Heading "Scoop apps"
# scoop info shows "Installed   : <version>" line when installed locally,
# or no Installed line at all when not installed.
foreach ($s in 'glazewm','FiraCode-NF','mpv','notepadplusplus','7zip') {
    $info = & scoop info $s 2>$null | Out-String
    if ($info -match 'Installed\s*:\s*\d') {
        Pass $s
    } else {
        Fail "$s MISSING"
    }
}

Heading "Hotkey sanity (manual)"
Write-Host "  Try in any window:"
Write-Host "    Alt+H/J/K/L         focus left/down/up/right"
Write-Host "    Alt+Shift+H/J/K/L   move window"
Write-Host "    Alt+1..9            switch workspace"
Write-Host "    Alt+Shift+1..9      move window to workspace"
Write-Host "    Alt+R               resize mode        Alt+F  fullscreen"
Write-Host "    Alt+Shift+Q         close window       Alt+Shift+R  reload config"

Write-Host ""
if ($script:Failures -eq 0) {
    Write-Host "Done. All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Done. $script:Failures check(s) FAILED." -ForegroundColor Red
    exit 1
}
