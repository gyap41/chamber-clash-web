# CHAMBER CLASH: run every headless test in one go.
# Usage:
#   powershell -ExecutionPolicy Bypass -File run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
#   powershell -ExecutionPolicy Bypass -File run_tests.ps1 -GodotPath "D:\Godot\Godot.exe"
#
# Auto-discovers tests/*.gd. render.gd (non-headless) is skipped by default; pass -IncludeRender to run it too.
# Combined output is saved under .local/logs/, and a PASS/FAIL summary is printed at the end.
# Results:
#   FAIL    - non-zero exit, SCRIPT ERROR, assertion failure, "FAIL:", or an "ERROR:" line other than
#             the exit-time "resources still in use" leak report.
#   PASS    - no error and at least one line starting with "PASS" ("PASS:" or "PASS <name>").
#   NO-PASS - no error but no PASS line (capture/review scripts); reported, does not fail the run.
# Exit-time leak reports vary between runs; they are counted in the Leaks column, not judged.
# Exit code is 1 if anything failed, 0 otherwise.

param(
    [string]$GodotPath = "",
    [switch]$IncludeRender,
    [int]$QuitAfter = 120
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$ProjectPath = $PSScriptRoot

# Auto-detect the Godot executable, in priority order.
if (-not $GodotPath) {
    $candidates = @(
        (Join-Path $ProjectPath ".local\tools\Godot_v4.7.2-stable_win64.exe"),
        (Join-Path (Split-Path $ProjectPath -Parent) "Godot_v4.7.2-stable_win64.exe"),
        (Join-Path $ProjectPath ".local\tools\Godot-4.5.1\Godot_v4.5.1-stable_win64.exe")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $GodotPath = $c; break }
    }
}
if (-not $GodotPath -or -not (Test-Path $GodotPath)) {
    Write-Error "Could not find a Godot executable. Pass one explicitly with -GodotPath."
    exit 1
}

# The plain .exe is a GUI-subsystem binary on Windows: launched non-interactively with
# stdout/stderr redirected, it silently produces no output at all (this is why every test
# below showed 0 passes with nothing captured). Godot ships a matching "_console.exe" in the
# same folder specifically for command-line use; prefer it whenever it sits beside the exe
# we resolved above, since only the console build's output can actually be redirected.
$consoleVariant = $GodotPath -replace '\.exe$', '_console.exe'
if (Test-Path $consoleVariant) { $GodotPath = $consoleVariant }

$logDir = Join-Path $ProjectPath ".local\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $logDir "run_tests-$timestamp.log"

$testFiles = Get-ChildItem -Path (Join-Path $ProjectPath "tests") -Filter "*.gd" |
    Where-Object { $IncludeRender -or $_.BaseName -ne "render" } |
    Sort-Object BaseName

if (-not $testFiles) {
    Write-Error "No test scripts found."
    exit 1
}

$results = @()

Write-Host "Godot: $GodotPath"
Write-Host "Project: $ProjectPath"
Write-Host "Log: $logPath"
Write-Host ""

# Godot writes its normal engine/script log lines to stderr as well as stdout, and with
# 2>&1 those become PowerShell ErrorRecord objects. Under $ErrorActionPreference = "Stop"
# (set above), the very first such line throws a terminating NativeCommandError and aborts
# the whole script after just one test, even though the process itself is not fatal. Run
# the test loop under "Continue" instead so every test actually gets to run.
$loopEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    foreach ($file in $testFiles) {
        $name = $file.BaseName
        Write-Host "=== $name ===" -NoNewline
        "=== $name ===" | Out-File -FilePath $logPath -Append -Encoding utf8

        $frameLimit = if ($name -eq "render") { [Math]::Max($QuitAfter, 300) } else { $QuitAfter }
        $headlessArgs = @("--path", $ProjectPath, "--script", "res://tests/$name.gd", "--quit-after", $frameLimit)
        if ($name -ne "render") { $headlessArgs = @("--headless") + $headlessArgs }

        $output = & $GodotPath @headlessArgs 2>&1
        $processExitCode = $LASTEXITCODE
        $output | Out-File -FilePath $logPath -Append -Encoding utf8

        $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
        $leakPattern = "(?m)^ERROR: \d+ resources still in use at exit"
        $leakCount = ([regex]::Matches($text, $leakPattern)).Count
        $judged = [regex]::Replace($text, $leakPattern, "")
        $hasError = $processExitCode -ne 0 -or $judged -match "SCRIPT ERROR|Assertion failed|(?m)^ERROR:|FAIL:"
        $passCount = ([regex]::Matches($text, "(?m)^PASS\b")).Count

        if ($hasError) {
            Write-Host "  FAIL" -ForegroundColor Red
            $result = "FAIL"
        } elseif ($passCount -eq 0) {
            Write-Host "  NO-PASS (no errors, no PASS line)" -ForegroundColor Yellow
            $result = "NO-PASS"
        } else {
            Write-Host "  PASS ($passCount)" -ForegroundColor Green
            $result = "PASS"
        }
        $results += [pscustomobject]@{ Test = $name; Result = $result; Passes = $passCount; Leaks = $leakCount }
    }
} finally {
    $ErrorActionPreference = $loopEAP
}

Write-Host ""
Write-Host "----- summary -----"
"----- summary -----" | Out-File -FilePath $logPath -Append -Encoding utf8
$results | Format-Table -AutoSize | Out-String | Write-Host
$results | Format-Table -AutoSize | Out-String | Out-File -FilePath $logPath -Append -Encoding utf8

$failed = @($results | Where-Object { $_.Result -eq "FAIL" })
$noPass = @($results | Where-Object { $_.Result -eq "NO-PASS" })
$passed = @($results | Where-Object { $_.Result -eq "PASS" })
$totals = "PASS $($passed.Count) / FAIL $($failed.Count) / NO-PASS $($noPass.Count) / total $($results.Count)"
Write-Host $totals
$totals | Out-File -FilePath $logPath -Append -Encoding utf8
if ($noPass.Count -gt 0) {
    Write-Host "NO-PASS (not counted as failures): $($noPass.Test -join ', ')" -ForegroundColor Yellow
}
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed.Test -join ', ')" -ForegroundColor Red
    exit 1
} else {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
