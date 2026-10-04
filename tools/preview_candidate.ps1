# Launch the game with unadopted candidate assets swapped in (memory only; files are untouched).
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/preview_candidate.ps1 lizard/v2
#   powershell -ExecutionPolicy Bypass -File tools/preview_candidate.ps1 -Candidate lizard/v2,lizard_spit/v1 --rina-run
# Candidates live in assets/candidates/<asset_id>/<version>/ with a preview.json (see assets/candidates/README.md).

param(
    [Parameter(Mandatory = $true, Position = 0)][string[]]$Candidate,
    [string]$GodotPath = "",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArgs = @()
)

$ErrorActionPreference = "Stop"
$ProjectPath = Split-Path $PSScriptRoot -Parent

if (-not $GodotPath) {
    $candidates = @(
        (Join-Path $ProjectPath ".local\tools\Godot_v4.7.2-stable_win64.exe"),
        (Join-Path (Split-Path $ProjectPath -Parent) "Godot_v4.7.2-stable_win64.exe")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $GodotPath = $c; break }
    }
}
if (-not $GodotPath -or -not (Test-Path $GodotPath)) {
    Write-Error "Could not find a Godot executable. Pass one explicitly with -GodotPath."
    exit 1
}

$userArgs = @()
foreach ($id in ($Candidate -join ",").Split(",")) {
    $id = $id.Trim()
    if (-not $id) { continue }
    $manifest = Join-Path $ProjectPath "assets\candidates\$id\preview.json"
    if (-not (Test-Path $manifest)) {
        Write-Error "No preview.json for candidate '$id' ($manifest)."
        exit 1
    }
    $userArgs += "--preview-candidate=$id"
}
$userArgs += $GameArgs

Write-Host "Godot: $GodotPath"
Write-Host "Preview: $($userArgs -join ' ')"
& $GodotPath --path $ProjectPath -- @userArgs
