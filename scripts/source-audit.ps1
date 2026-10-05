$ErrorActionPreference = "Stop"
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  $files = @(rg --files -g '*.mbt')
  if ($LASTEXITCODE -ne 0) {throw "rg source inventory failed"}
  $categories = @{}
  foreach ($file in $files) {
    $category = if ($file -match '^examples[\\/]') {"Examples"} elseif ($file -match 'benchmark_test\.mbt$') {"Benchmarks"} elseif ($file -match '_(wb)?test\.mbt$') {"Tests"} else {"CoreAndCLI"}
    if (!$categories.ContainsKey($category)) {$categories[$category]=@{Files=0; Physical=0; Code=0}}
    $lines = @(Get-Content -LiteralPath $file)
    $code = @($lines | Where-Object {$_ -notmatch '^\s*(//|$)'}).Count
    $categories[$category].Files += 1
    $categories[$category].Physical += $lines.Count
    $categories[$category].Code += $code
  }
  $totalPhysical = 0
  $totalCode = 0
  foreach ($category in ($categories.Keys | Sort-Object)) {
    $data = $categories[$category]
    $totalPhysical += $data.Physical
    $totalCode += $data.Code
    Write-Output "$category`: files=$($data.Files), physical=$($data.Physical), nonblank-noncomment=$($data.Code)"
  }
  Write-Output "Total: physical=$totalPhysical, nonblank-noncomment=$totalCode"
  Write-Output "Excludes generated interfaces, dependencies, build output, fixtures and non-MoonBit files."
} finally {Pop-Location}
