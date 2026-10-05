param([string]$Binary = "dist/moon-dbc.exe")
$ErrorActionPreference = "Stop"
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  $cases = @(
    @{Args=@("inspect","tests/fixtures/basic.dbc"); Code=0},
    @{Args=@("inspect","tests/fixtures/basic.dbc","--message","0x123"); Code=0},
    @{Args=@("validate","tests/fixtures/basic.dbc"); Code=0},
    @{Args=@("decode","tests/fixtures/basic.dbc","0x123","E02E030000000000"); Code=0},
    @{Args=@("decode","tests/fixtures/motorola.dbc","292","0540FFF000000000","--json"); Code=0},
    @{Args=@("encode","tests/fixtures/basic.dbc","0x123","EngineSpeed=1500","Gear=3"); Code=0},
    @{Args=@("encode","tests/fixtures/basic.dbc","0x123","--raw","EngineSpeed=12000","Gear=3"); Code=0},
    @{Args=@("layout","tests/fixtures/multiplex.dbc","293"); Code=0},
    @{Args=@("diff","tests/fixtures/basic.dbc","tests/fixtures/basic.dbc"); Code=0},
    @{Args=@("normalize","tests/fixtures/attributes.dbc"); Code=0},
    @{Args=@("validate","tests/fixtures/invalid_overlap.dbc"); Code=1},
    @{Args=@("decode","tests/fixtures/basic.dbc","291","ABC"); Code=2},
    @{Args=@("inspect","missing.dbc"); Code=2}
  )
  foreach ($case in $cases) {
    $commandArgs = $case.Args
    & $Binary @commandArgs
    if ($LASTEXITCODE -ne $case.Code) {throw "Unexpected exit code for $commandArgs"}
  }
  Write-Output "CLI smoke: $($cases.Count) cases passed"
} finally {Pop-Location}
