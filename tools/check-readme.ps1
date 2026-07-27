# Verifies that the README does not drift from reality:
#   - every repo path named in a table exists
#   - every `just` recipe named actually exists in the Justfile
#   - every GlazeWM binding listed matches windows/glazewm/config.yaml
#
# Cheap to run, and catches the usual documentation rot.
# Run: powershell -NoProfile -File tools\check-readme.ps1

$repo = Split-Path -Parent $PSScriptRoot
$readme = Get-Content (Join-Path $repo 'README.md') -Raw
$failures = 0

function Fail($m) { $script:failures++; Write-Host "  - $m" -ForegroundColor Red }
function Pass($m) { Write-Host "  + $m" -ForegroundColor Green }

Write-Host "== README paths ==" -ForegroundColor Cyan
$paths = [regex]::Matches($readme, '\|\s*`([^`]+)`\s*\|') |
         ForEach-Object { $_.Groups[1].Value } |
         Where-Object { $_ -match '^(flake|packages|treefmt|Justfile|modules|tools|windows)' }
$missing = @()
foreach ($p in $paths) {
    $full = Join-Path $repo ($p.TrimEnd('/') -replace '/', '\')
    if (-not (Test-Path $full)) { $missing += $p }
}
if ($missing) { Fail "paths in README that do not exist: $($missing -join ', ')" }
else { Pass "$($paths.Count) documented paths all exist" }

Write-Host "`n== README just recipes ==" -ForegroundColor Cyan
$justfile = Get-Content (Join-Path $repo 'Justfile') -Raw
$recipes = [regex]::Matches($justfile, '(?m)^([a-z][a-z0-9-]*)[: ]') |
           ForEach-Object { $_.Groups[1].Value }
$documented = [regex]::Matches($readme, '(?m)^just\s+([a-z][a-z0-9-]*)') |
              ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$badRecipes = $documented | Where-Object { $recipes -notcontains $_ }
if ($badRecipes) { Fail "README documents nonexistent recipes: $($badRecipes -join ', ')" }
else { Pass "$($documented.Count) documented recipes all exist" }

Write-Host "`n== README GlazeWM bindings ==" -ForegroundColor Cyan
$cfg = Get-Content (Join-Path $repo 'windows\glazewm\config.yaml') -Raw
# Pull `Alt+X` style keys out of the README's binding table and confirm the
# lowercase form appears in the config's bindings list.
$docBinds = [regex]::Matches($readme, '\|\s*`(Alt\+[^`]+)`\s*\|') |
            ForEach-Object { $_.Groups[1].Value }
$badBinds = @()
foreach ($b in $docBinds) {
    # Normalise "Alt+H/J/K/L" -> first alternative; "Alt+1..9" -> Alt+1
    $probe = ($b -replace '/.*$', '') -replace '\.\..*$', ''
    $probe = $probe.ToLower() -replace '\s', ''
    if ($cfg -notmatch [regex]::Escape($probe)) { $badBinds += $b }
}
if ($badBinds) { Fail "README bindings absent from config.yaml: $($badBinds -join ', ')" }
else { Pass "$($docBinds.Count) documented bindings all present in config.yaml" }

Write-Host "`n== README runnable commands ==" -ForegroundColor Cyan
# Every script the README tells the reader to run must exist, otherwise the
# quick-start instructions fail on a fresh clone.
$cmdMissing = @()
foreach ($m in [regex]::Matches($readme, '(?m)^powershell -NoProfile -File (\S+)')) {
    $f = $m.Groups[1].Value -replace '/', '\'
    if (-not (Test-Path (Join-Path $repo $f))) { $cmdMissing += $f }
}
foreach ($m in [regex]::Matches($readme, '(?m)^bash \S*?([\w./-]+\.sh)')) {
    $f = ($m.Groups[1].Value -replace '/', '\') -replace '^.*nix-windows-config\\', ''
    if (-not (Test-Path (Join-Path $repo $f))) { $cmdMissing += $f }
}
if ($cmdMissing) { Fail "README runs missing scripts: $($cmdMissing -join ', ')" }
else { Pass "all documented commands point at existing scripts" }

Write-Host ""
if ($failures -eq 0) { Write-Host "README is consistent." -ForegroundColor Green; exit 0 }
else { Write-Host "$failures inconsistency(ies)." -ForegroundColor Red; exit 1 }
