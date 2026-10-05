param([string]$OutputDirectory = "dist")
$ErrorActionPreference = "Stop"
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  moon build --target native --release cmd/main
  if ($LASTEXITCODE -ne 0) { throw "native build failed" }
  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
  Copy-Item -LiteralPath "_build/native/release/build/cmd/main/main.exe" -Destination (Join-Path $OutputDirectory "moon-dbc.exe") -Force
  Write-Output (Join-Path (Get-Location) $OutputDirectory "moon-dbc.exe")
} finally { Pop-Location }
