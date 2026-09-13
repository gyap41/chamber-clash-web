param(
 [ValidateSet('Web','Native','Update','Test')][string]$Mode = 'Web',
 [switch]$Install,
 [string]$NodePath,
 [string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$hubRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location -LiteralPath $hubRoot
if ($GodotPath) { $env:HUB_GODOT = (Resolve-Path -LiteralPath $GodotPath).Path }
if ($Mode -eq 'Native') {
 $hubGodot = if ($env:HUB_GODOT) { $env:HUB_GODOT } else { Join-Path $hubRoot '.local/tools/Godot_v4.7.2-stable_win64_console.exe' }
 if (!(Test-Path -LiteralPath $hubGodot)) { throw 'Godot executable missing: use -GodotPath or HUB_GODOT.' }
 & $hubGodot --path $hubRoot --rendering-method gl_compatibility res://tools/visual_hub/visual_hub.tscn
 exit $LASTEXITCODE
}
$hubNodeCandidates = @($NodePath, $env:HUB_NODE)
$hubNodeCommand = Get-Command node -ErrorAction SilentlyContinue
if ($hubNodeCommand) { $hubNodeCandidates += $hubNodeCommand.Source }
$hubNodeCandidates += (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe')
$hubNode = $null
foreach ($hubCandidate in $hubNodeCandidates) {
 if (!$hubCandidate -or !(Test-Path -LiteralPath $hubCandidate)) { continue }
 $hubVersion = & $hubCandidate -p 'process.versions.node'
 $hubParts = $hubVersion.Split('.')
 if (([int]$hubParts[0] -eq 20 -and [int]$hubParts[1] -ge 19) -or ([int]$hubParts[0] -eq 22 -and [int]$hubParts[1] -ge 12) -or [int]$hubParts[0] -ge 24) { $hubNode = $hubCandidate; break }
}
if (!$hubNode) { throw 'Node 20.19+, 22.12+ or 24+ required. Use -NodePath or HUB_NODE.' }
Write-Host "Node: $hubNode"
if ($Install) {
 $hubNpm = Get-Command npm.cmd -ErrorAction Stop
 $hubNpmCli = Join-Path (Split-Path $hubNpm.Source) 'node_modules/npm/bin/npm-cli.js'
 & $hubNode $hubNpmCli ci --include=optional
 if ($LASTEXITCODE) { throw 'npm ci failed' }
}
if (Test-Path -LiteralPath node_modules) { Set-Content -Encoding ascii -LiteralPath node_modules/.gdignore -Value '' }
if (!(Test-Path node_modules/typescript/bin/tsc)) { throw 'Dependencies missing. Run this script with -Install once.' }
if ($Mode -eq 'Test') {
 & $hubNode --test tools/visual_hub/web/test/core.test.mjs
 exit $LASTEXITCODE
}
if ($Mode -eq 'Update') {
 & $hubNode tools/visual_hub/web/cli.mjs update
 exit $LASTEXITCODE
}
& $hubNode node_modules/typescript/bin/tsc -p tools/visual_hub/web/tsconfig.json
if ($LASTEXITCODE) { throw 'Type check failed' }
& $hubNode node_modules/vite/bin/vite.js build --config tools/visual_hub/web/vite.config.ts
if ($LASTEXITCODE) { throw 'Web build failed' }
& $hubNode tools/visual_hub/web/cli.mjs update
if ($LASTEXITCODE) { throw 'Catalog export failed' }
& $hubNode tools/visual_hub/web/build-live.mjs
if ($LASTEXITCODE) { throw 'Live Web build failed' }
& $hubNode tools/visual_hub/web/service.mjs
exit $LASTEXITCODE
