# Structural sanity check for the Nix files in this repo.
#
# This is NOT a Nix parser. It catches the class of error that a
# copy/paste or scripted edit actually introduces on the Windows side,
# where `nix` itself is unavailable to run `nix-instantiate --parse`:
#
#   - unbalanced braces / brackets / parens outside string literals
#   - unterminated '' indented-string blocks
#   - CRLF line endings (Nix tolerates them, but they churn diffs and
#     break the `''${...}` escapes when tools rewrite the file)
#   - tabs used for indentation
#
# Run:  powershell -NoProfile -File tools\check-nix-syntax.ps1
# Exits non-zero on any finding, so it can gate a commit.

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$failures = 0

function Fail($m) { $script:failures++; Write-Host "  - $m" -ForegroundColor Red }
function Pass($m) { Write-Host "  + $m" -ForegroundColor Green }

# Walks a Nix file one character at a time, tracking whether we are inside
# a "double-quoted" string, an ''indented string'', or a # comment, so that
# braces appearing inside strings do not count toward the balance.
function Test-NixFile($path) {
    $text = [System.IO.File]::ReadAllText($path)
    $rel  = $path.Substring($repo.Length + 1)
    $ok   = $true

    if ($text -match "`r`n") {
        Fail "$rel has CRLF line endings (should be LF)"
        $ok = $false
    }
    if ($text -match "(?m)^\t") {
        Fail "$rel indents with tabs"
        $ok = $false
    }

    $depth = @{ '{' = 0; '[' = 0; '(' = 0 }
    $pairs = @{ '}' = '{'; ']' = '['; ')' = '(' }

    $i = 0; $n = $text.Length
    $inDq = $false      # inside "..."
    $inIs = $false      # inside ''...''
    $inComment = $false
    $line = 1

    while ($i -lt $n) {
        $ch   = $text[$i]
        $next = if ($i + 1 -lt $n) { $text[$i + 1] } else { "`0" }

        if ($ch -eq "`n") { $line++; $inComment = $false; $i++; continue }

        if ($inComment) { $i++; continue }

        if ($inIs) {
            # ''' escapes a quote, ''$ escapes interpolation, ''\ escapes a char
            if ($ch -eq "'" -and $next -eq "'") {
                $after = if ($i + 2 -lt $n) { $text[$i + 2] } else { "`0" }
                if ($after -eq "'" -or $after -eq '$' -or $after -eq '\') { $i += 3; continue }
                $inIs = $false; $i += 2; continue
            }
            $i++; continue
        }

        if ($inDq) {
            if ($ch -eq '\') { $i += 2; continue }
            if ($ch -eq '"') { $inDq = $false }
            $i++; continue
        }

        # Not in any string
        if ($ch -eq '#') { $inComment = $true; $i++; continue }
        if ($ch -eq "'" -and $next -eq "'") { $inIs = $true; $i += 2; continue }
        if ($ch -eq '"') { $inDq = $true; $i++; continue }

        if ($depth.ContainsKey([string]$ch)) {
            $depth[[string]$ch]++
        } elseif ($pairs.ContainsKey([string]$ch)) {
            $open = $pairs[[string]$ch]
            $depth[$open]--
            if ($depth[$open] -lt 0) {
                Fail "$rel line ${line}: unmatched '$ch'"
                $ok = $false
                $depth[$open] = 0
            }
        }
        $i++
    }

    if ($inIs) { Fail "${rel}: unterminated '' indented string"; $ok = $false }
    if ($inDq) { Fail "${rel}: unterminated double-quoted string"; $ok = $false }
    foreach ($k in @('{', '[', '(')) {
        if ($depth[$k] -ne 0) {
            Fail "${rel}: $($depth[$k]) unclosed '$k'"
            $ok = $false
        }
    }

    if ($ok) { Pass $rel }
}

Write-Host "== Nix structural check ==" -ForegroundColor Cyan
Get-ChildItem $repo -Recurse -Filter *.nix -File |
    Where-Object { $_.FullName -notmatch '\\\.git\\' } |
    ForEach-Object { Test-NixFile $_.FullName }

# The autoload contract: every name in the `autoload -Uz` list must have a
# matching body file, or the shell silently loses that function.
# Match only the multi-line, backslash-continued block (the `autoload -Uz
# compinit` inside completionInit is a single line and must not match).
Write-Host "`n== Autoload function bodies ==" -ForegroundColor Cyan
$homeNix = Join-Path $repo 'modules\home.nix'
$fnDir   = Join-Path $repo 'modules\shell\functions'
$text    = [System.IO.File]::ReadAllText($homeNix)

if ($text -match '(?m)^\s*autoload -Uz \\\r?\n((?:\s*\S.*\\\r?\n)*\s*\S[^\r\n]*)') {
    $names = ($matches[1] -replace '\\', ' ') -split '\s+' | Where-Object { $_ }
    $onDisk = Get-ChildItem $fnDir -File | Select-Object -ExpandProperty Name

    foreach ($fn in $names) {
        if ($onDisk -contains $fn) { Pass $fn } else { Fail "$fn autoloaded but modules/shell/functions/$fn is MISSING" }
    }
    foreach ($f in $onDisk) {
        if ($names -notcontains $f) { Fail "modules/shell/functions/$f exists but is never autoloaded" }
    }
} else {
    Fail "could not find an 'autoload -Uz' block in modules/home.nix"
}

# Anything executed by bash/zsh inside WSL must be LF. A CRLF checkout makes
# the interpreter read the trailing \r as part of the last token, producing
# baffling errors ("$'\r': command not found", or a shebang that never
# resolves). Guard explicitly rather than trusting .gitattributes to have been
# honoured on every clone.
Write-Host "`n== WSL script line endings ==" -ForegroundColor Cyan
$crlf = @()
@(
    (Get-ChildItem $fnDir -File),
    (Get-ChildItem (Join-Path $repo 'windows') -File -Include *.sh, *.zsh -Recurse),
    (Get-ChildItem $repo -File -Filter '*.nix' -Recurse |
        Where-Object { $_.FullName -notmatch '\\\.git\\' }),
    (Get-Item (Join-Path $repo 'Justfile') -ErrorAction SilentlyContinue)
) | ForEach-Object { $_ } | Where-Object { $_ } | ForEach-Object {
    if ([System.IO.File]::ReadAllText($_.FullName) -match "`r") {
        $crlf += $_.FullName.Substring($repo.Length + 1)
    }
}
if ($crlf) {
    Fail "CRLF in: $($crlf -join ', ')  (run: git add --renormalize .)"
} else {
    Pass "all WSL-executed files are LF"
}

# PowerShell scripts are the mirror image: they only run on Windows and are
# pinned to CRLF, so flag a stray LF-only one that .gitattributes missed.
$ps1 = Get-ChildItem $repo -File -Filter '*.ps1' -Recurse |
       Where-Object { $_.FullName -notmatch '\\\.git\\' }
$badPs1 = $ps1 | Where-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName)
    $t -match "`n" -and $t -notmatch "`r`n"
}
if ($badPs1) {
    Fail "LF-only PowerShell: $(($badPs1 | ForEach-Object { $_.Name }) -join ', ')"
} else {
    Pass "all .ps1 files are CRLF"
}

# Round-tripping a UTF-8 file through a tool that assumes Latin-1 silently
# corrupts every multi-byte character (box drawing, arrows, CJK). This is easy
# to do by accident when scripting edits, and the damage is not obvious in a
# diff. U+00E2 / U+00C3 are the tell-tale lead bytes of the mangled form.
Write-Host "`n== UTF-8 integrity ==" -ForegroundColor Cyan
$sig = @([char]0x00E2, [char]0x00C3)
$mojibake = @()
Get-ChildItem $repo -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Extension -notin '.png', '.age' } |
    ForEach-Object {
        $u = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($_.FullName))
        foreach ($c in $sig) {
            if ($u.IndexOf($c) -ge 0) {
                $mojibake += $_.FullName.Substring($repo.Length + 1)
                break
            }
        }
    }
if ($mojibake) {
    Fail "mojibake (UTF-8 decoded as Latin-1) in: $(($mojibake | Sort-Object -Unique) -join ', ')"
} else {
    Pass "no mojibake"
}

Write-Host ""
if ($failures -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failures problem(s) found." -ForegroundColor Red
    exit 1
}
