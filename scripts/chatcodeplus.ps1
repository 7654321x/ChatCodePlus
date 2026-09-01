$ErrorActionPreference = "Stop"
$ChatCodePlusArgs = $args
$skillRoot = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $skillRoot "runtime"
$runtimeFile = Join-Path $runtimeDir "chatcodeplus.mjs"
$manifestFile = Join-Path $runtimeDir "manifest.json"
$stateDir = if ($env:CHATCODEPLUS_STATE_DIR) {
  [System.IO.Path]::GetFullPath($env:CHATCODEPLUS_STATE_DIR)
} else {
  Join-Path $HOME ".chatcodeplus"
}
$toolsDir = Join-Path $stateDir "tools"
$managedNode = Join-Path $toolsDir "node\node.exe"
$managedCloudflared = Join-Path $toolsDir "cloudflared\cloudflared.exe"

if (-not (Test-Path -LiteralPath $runtimeFile) -or -not (Test-Path -LiteralPath $manifestFile)) {
  throw "ChatCodePlus Skill runtime is incomplete. Reinstall the Skill."
}
$manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
$actual = (Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne [string]$manifest.runtimeSha256) {
  throw "ChatCodePlus Skill runtime integrity check failed. Reinstall the Skill."
}

$node = $null
if (Test-Path -LiteralPath $managedNode) { $node = $managedNode }
if (-not $node) {
  $systemNode = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($systemNode) {
    $major = [int]((& $systemNode.Source -p "process.versions.node.split('.')[0]").Trim())
    if ($major -ge [int]$manifest.minimumNodeMajor) { $node = $systemNode.Source }
  }
}
if (-not $node) {
  throw "Node.js is missing or too old. Run: pwsh -NoProfile -File `"$PSScriptRoot\bootstrap.ps1`" -Install"
}
if (Test-Path -LiteralPath $managedCloudflared) {
  $env:PATH = "$(Split-Path -Parent $managedCloudflared);$env:PATH"
}
& $node $runtimeFile @ChatCodePlusArgs
exit $LASTEXITCODE
