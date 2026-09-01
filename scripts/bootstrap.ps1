param([switch]$Check, [switch]$Install)
$ErrorActionPreference = "Stop"
$stateDir = if ($env:CHATCODEPLUS_STATE_DIR) {
  [System.IO.Path]::GetFullPath($env:CHATCODEPLUS_STATE_DIR)
} else {
  Join-Path $HOME ".chatcodeplus"
}
$toolsDir = Join-Path $stateDir "tools"
$nodeDir = Join-Path $toolsDir "node"
$cfDir = Join-Path $toolsDir "cloudflared"
$managedNode = Join-Path $nodeDir "node.exe"
$managedCf = Join-Path $cfDir "cloudflared.exe"
$skillRoot = Split-Path -Parent $PSScriptRoot
$runtimeFile = Join-Path $skillRoot "runtime\chatcodeplus.mjs"
$manifestFile = Join-Path $skillRoot "runtime\manifest.json"
$osArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
$arch = switch ($osArch) {
  "X64" { "x64" }
  "Arm64" { "arm64" }
  default {
    [pscustomobject]@{ ok = $false; code = "CHATCODEPLUS_PLATFORM_UNSUPPORTED"; platform = "win32"; architecture = $osArch } |
      ConvertTo-Json -Compress
    exit 1
  }
}

if ($Check -and $Install) { throw "Use either -Check or -Install, not both." }

function Test-Node20 {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $false }
  try { return [int]((& $Path -p "process.versions.node.split('.')[0]").Trim()) -ge 20 } catch { return $false }
}
function System-Node { $cmd = Get-Command node.exe -ErrorAction SilentlyContinue; if ($cmd) { return $cmd.Source }; return $null }
function System-Cf { $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue; if ($cmd) { return $cmd.Source }; return $null }
function Get-RuntimeStatus {
  if (-not (Test-Path -LiteralPath $runtimeFile) -or -not (Test-Path -LiteralPath $manifestFile)) {
    return [pscustomobject]@{ ok = $false; version = $null; detail = "Skill runtime or manifest is missing" }
  }
  try {
    $manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
    $actual = (Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $ok = $manifest.runtimeFile -eq "chatcodeplus.mjs" -and $actual -eq [string]$manifest.runtimeSha256
    return [pscustomobject]@{ ok = $ok; version = $manifest.version; detail = $(if ($ok) { "SHA-256 verified" } else { "Runtime SHA-256 does not match manifest" }) }
  } catch {
    return [pscustomobject]@{ ok = $false; version = $null; detail = "Runtime manifest is invalid" }
  }
}
function Test-WriteAccess {
  $probeParent = $stateDir
  if ((Test-Path -LiteralPath $probeParent) -and -not (Test-Path -LiteralPath $probeParent -PathType Container)) {
    $probeParent = Split-Path -Parent $probeParent
  }
  while (-not (Test-Path -LiteralPath $probeParent -PathType Container)) {
    $parent = Split-Path -Parent $probeParent
    if (-not $parent -or $parent -eq $probeParent) { return $false }
    $probeParent = $parent
  }
  try {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principals = @($identity.User.Value) + @($identity.Groups | ForEach-Object { $_.Value })
    $rules = (Get-Acl -LiteralPath $probeParent).GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
    $writeMask = [System.Security.AccessControl.FileSystemRights]::WriteData -bor
      [System.Security.AccessControl.FileSystemRights]::CreateFiles -bor
      [System.Security.AccessControl.FileSystemRights]::CreateDirectories -bor
      [System.Security.AccessControl.FileSystemRights]::Modify -bor
      [System.Security.AccessControl.FileSystemRights]::FullControl
    $allowed = $false
    foreach ($rule in $rules) {
      if ($principals -notcontains $rule.IdentityReference.Value -or -not ($rule.FileSystemRights -band $writeMask)) { continue }
      if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) { return $false }
      $allowed = $true
    }
    return $allowed
  } catch {
    return $false
  }
}
function Get-AvailableReleases {
  $nodeVersion = $null
  $cloudflaredVersion = $null
  try {
    $index = Invoke-RestMethod -TimeoutSec 5 -Uri "https://nodejs.org/dist/index.json"
    $nodeVersion = ($index | Where-Object { $_.version -match '^v22\.' -and $_.lts } | Select-Object -First 1).version
  } catch {}
  try {
    $release = Invoke-RestMethod -TimeoutSec 5 -Headers @{ "User-Agent" = "chatcodeplus" } -Uri "https://api.github.com/repos/cloudflare/cloudflared/releases/latest"
    $cloudflaredVersion = $release.tag_name
  } catch {}
  return [pscustomobject]@{ node = $nodeVersion; cloudflared = $cloudflaredVersion }
}
function Swap-Directory {
  param([string]$Stage, [string]$Destination)
  $backup = "$Destination.old-" + [guid]::NewGuid().ToString("N")
  if (Test-Path -LiteralPath $Destination) { Move-Item -LiteralPath $Destination -Destination $backup }
  try {
    Move-Item -LiteralPath $Stage -Destination $Destination
  } catch {
    if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $Destination)) {
      Move-Item -LiteralPath $backup -Destination $Destination
    }
    throw
  }
  if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
}
function Emit-Status {
  $systemNode = System-Node
  $systemCf = System-Cf
  $writable = Test-WriteAccess
  $available = Get-AvailableReleases
  $runtime = Get-RuntimeStatus
  [pscustomobject]@{
    schemaVersion = 1; ok = $runtime.ok -and $writable -and ((Test-Node20 $managedNode) -or (Test-Node20 $systemNode)) -and ((Test-Path -LiteralPath $managedCf) -or [bool]$systemCf)
    platform = "win32"; architecture = $arch; writable = $writable
    runtime = $runtime
    node = [pscustomobject]@{ ok = (Test-Node20 $managedNode) -or (Test-Node20 $systemNode); managed = (Test-Node20 $managedNode); path = $(if (Test-Node20 $managedNode) { $managedNode } else { $systemNode }) }
    cloudflared = [pscustomobject]@{ ok = (Test-Path -LiteralPath $managedCf) -or [bool]$systemCf; managed = (Test-Path -LiteralPath $managedCf); path = $(if (Test-Path -LiteralPath $managedCf) { $managedCf } else { $systemCf }) }
    network = [pscustomobject]@{ nodejs = [bool]$available.node; github = [bool]$available.cloudflared }
    downloads = @(
      [pscustomobject]@{ component = "node"; version = $available.node; source = "https://nodejs.org/dist/"; required = -not ((Test-Node20 $managedNode) -or (Test-Node20 $systemNode)) },
      [pscustomobject]@{ component = "cloudflared"; version = $available.cloudflared; source = "https://github.com/cloudflare/cloudflared/releases"; required = -not ((Test-Path -LiteralPath $managedCf) -or [bool]$systemCf) }
    )
    installDirectory = $toolsDir
  } | ConvertTo-Json -Depth 5 -Compress
}
if (-not $Install) { Emit-Status; exit 0 }

if (-not (Get-RuntimeStatus).ok) { throw "CHATCODEPLUS_RUNTIME_INTEGRITY_FAILED: reinstall the complete Skill package" }
if (-not (Test-WriteAccess)) { throw "CHATCODEPLUS_INSTALL_DIRECTORY_NOT_WRITABLE: $toolsDir" }
New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
$tempRoot = Join-Path $toolsDir (".install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  if (-not ((Test-Node20 $managedNode) -or (Test-Node20 (System-Node)))) {
    $index = Invoke-RestMethod -TimeoutSec 15 -Uri "https://nodejs.org/dist/index.json"
    $release = $index | Where-Object { $_.version -match '^v22\.' -and $_.lts } | Select-Object -First 1
    if (-not $release) { throw "No Node.js 22 LTS release found" }
    $asset = "node-$($release.version)-win-$arch.zip"
    $sums = Invoke-WebRequest -UseBasicParsing -Uri "https://nodejs.org/dist/$($release.version)/SHASUMS256.txt"
    $expected = (($sums.Content -split "`n") | Where-Object { $_ -match "\s$([regex]::Escape($asset))`r?$" } | Select-Object -First 1).Split()[0]
    if (-not $expected) { throw "Node.js checksum not found for $asset" }
    $archive = Join-Path $tempRoot $asset
    Invoke-WebRequest -UseBasicParsing -Uri "https://nodejs.org/dist/$($release.version)/$asset" -OutFile $archive
    if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected.ToLowerInvariant()) { throw "Node.js checksum verification failed" }
    $expanded = Join-Path $tempRoot "node-expanded"; Expand-Archive -LiteralPath $archive -DestinationPath $expanded
    $source = Get-ChildItem -LiteralPath $expanded -Directory | Select-Object -First 1
    $stage = Join-Path $tempRoot "node-ready"
    Move-Item -LiteralPath $source.FullName -Destination $stage
    Swap-Directory -Stage $stage -Destination $nodeDir
  }
  if (-not ((Test-Path $managedCf) -or (System-Cf))) {
    $release = Invoke-RestMethod -TimeoutSec 15 -Headers @{ "User-Agent" = "chatcodeplus" } -Uri "https://api.github.com/repos/cloudflare/cloudflared/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -eq "cloudflared-windows-amd64.exe" } | Select-Object -First 1
    if (-not $asset -or -not $asset.digest) { throw "Cloudflared release digest is unavailable" }
    $download = Join-Path $tempRoot "cloudflared.exe"
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $download
    $expected = ([string]$asset.digest).Replace("sha256:", "")
    if ((Get-FileHash $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected.ToLowerInvariant()) { throw "cloudflared checksum verification failed" }
    $cfStage = Join-Path $tempRoot "cloudflared-ready"
    New-Item -ItemType Directory -Path $cfStage | Out-Null
    Move-Item -LiteralPath $download -Destination (Join-Path $cfStage "cloudflared.exe")
    Swap-Directory -Stage $cfStage -Destination $cfDir
  }
} finally {
  if (Test-Path $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
Emit-Status
