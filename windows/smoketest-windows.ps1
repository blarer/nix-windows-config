# Windows-side smoke test for the nix-windows-config port.
# Run from elevated or normal PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\smoketest-windows.ps1

function Heading($t) {
    Write-Host ""
    Write-Host "== $t ==" -ForegroundColor Cyan
}

function Pass($m) { Write-Host "  + $m" -ForegroundColor Green }
function Fail($m) { Write-Host "  - $m" -ForegroundColor Red }

Heading "Komorebi / whkd processes"
foreach ($p in 'komorebi','whkd') {
    $proc = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($proc) {
        Pass "$p running (PID $($proc.Id -join ','))"
    } else {
        Fail "$p NOT running"
    }
}

Heading "Scheduled task: Komorebi"
$task = Get-ScheduledTask -TaskName 'Komorebi' -ErrorAction SilentlyContinue
if ($task) {
    Pass "Komorebi task: $($task.State)"
} else {
    Fail "Komorebi task missing"
}

Heading "WSL distros"
wsl --list --verbose

Heading "WezTerm default_prog"
$wez = Get-Content "$env:USERPROFILE\.wezterm.lua" -ErrorAction SilentlyContinue |
       Select-String -Pattern 'config\.default_prog'
$wez | ForEach-Object { Write-Host "  $_" }

Heading "Winget apps"
$apps = @(
    'Anthropic.Claude',
    'Brave.Brave',
    'wez.wezterm',
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
    $r = winget list --id $id --exact 2>$null | Select-String -Pattern $id
    if ($r) { Pass $id } else { Fail "$id MISSING" }
}

Heading "Scoop apps"
foreach ($s in 'komorebi','whkd','FiraCode-NF','mpv','notepadplusplus','7zip') {
    $r = scoop list 2>$null | Select-String -Pattern "^$s\s"
    if ($r) { Pass $s } else { Fail "$s MISSING" }
}

Heading "Komorebi config files"
foreach ($f in "$env:USERPROFILE\.config\komorebi\komorebi.json", "$env:USERPROFILE\.config\whkdrc") {
    if (Test-Path $f) { Pass $f } else { Fail "$f MISSING" }
}

Heading "Hotkey sanity (manual)"
Write-Host "  Try in any window:"
Write-Host "    Alt+H/J/K/L         focus left/down/up/right"
Write-Host "    Alt+Shift+H/J/K/L   move window"
Write-Host "    Alt+1..4            switch workspace"
Write-Host "    Alt+Enter           launch wezterm"
Write-Host ""
Write-Host "Done." -ForegroundColor Green
