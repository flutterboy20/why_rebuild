# Launches the example app on a device, waits for its VM service URL, runs the
# MCP test (through the official `dart mcp-server`), then stops the app.
#   powershell -File tool/run_live.ps1 -Device windows -Out tool/result_windows.md
# Uses `fvm flutter` (version from .fvmrc). $env:DART picks the dart.exe whose
# `dart mcp-server` is used; defaults to the fvm SDK's dart.
param(
  [Parameter(Mandatory = $true)][string]$Device,
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$Extra = ""
)
$ErrorActionPreference = "Stop"
$root = Join-Path (Split-Path -Parent $PSScriptRoot) "example"
$log = Join-Path $env:TEMP "why_rebuild_$($Device -replace '[^a-zA-Z0-9]','_').log"
Remove-Item $log, "$log.err" -ErrorAction SilentlyContinue

$flutterArgs = @("flutter", "run", "-d", $Device)
if ($Extra) { $flutterArgs += $Extra.Split(" ") }
$p = Start-Process -FilePath "fvm" -ArgumentList $flutterArgs -WorkingDirectory $root `
  -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -NoNewWindow

$ws = $null
$deadline = (Get-Date).AddMinutes(12)
while (-not $ws -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 3
  $text = (Get-Content $log -Raw -ErrorAction SilentlyContinue) + (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue)
  if ($text -match "Debug service listening on (ws://\S+)") { $ws = $Matches[1] }
  elseif ($text -match "Dart VM Service on .* is available at: http://(\S+)/") { $ws = "ws://$($Matches[1])/ws" }
  if ($p.HasExited) { break }
}
if (-not $ws) {
  Write-Output "FAILED to start on $Device. Log tail:"
  Get-Content $log -Tail 30
  Get-Content "$log.err" -Tail 30 -ErrorAction SilentlyContinue
  taskkill /PID $p.Id /T /F | Out-Null
  exit 1
}
Write-Output "VM service: $ws"
Start-Sleep -Seconds 3
if (-not $env:DART) {
  $ver = (Get-Content (Join-Path (Split-Path -Parent $PSScriptRoot) ".fvmrc") | ConvertFrom-Json).flutter
  $env:DART = Join-Path $env:USERPROFILE "fvm/versions/$ver/bin/cache/dart-sdk/bin/dart.exe"
}
python (Join-Path $PSScriptRoot "mcp_test.py") $ws $Out --bench
$exceptions = (Select-String -Path $log -Pattern "EXCEPTION CAUGHT" -AllMatches).Count
Write-Output "app exceptions logged: $exceptions"
taskkill /PID $p.Id /T /F | Out-Null
