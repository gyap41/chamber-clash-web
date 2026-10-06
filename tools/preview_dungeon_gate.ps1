param(
    [ValidateSet('north','south','east','west','all')][string]$View = 'north'
)
$ErrorActionPreference = 'Stop'
$gateRoot = Split-Path $PSScriptRoot -Parent
$gateExe = Join-Path $gateRoot '.local/tools/Godot_v4.7.2-stable_win64_console.exe'
$gateArgs = @('--path', '.', '--script', 'res://tools/preview_dungeon_gate.gd', '--quit-after', '3600', '--')
if ($View -ne 'all') { $gateArgs += "--gate-view=$View" }
$gateProcess = Start-Process -FilePath $gateExe -WorkingDirectory $gateRoot -ArgumentList $gateArgs -WindowStyle Hidden -PassThru
if (-not $gateProcess.WaitForExit(120000)) {
    $gateProcess.Kill()
    throw 'Gate preview stopped after its 120-second limit.'
}
exit $gateProcess.ExitCode
