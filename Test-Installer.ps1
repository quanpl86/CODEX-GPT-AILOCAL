$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot ('test-results\installer-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
$agents = Join-Path $root 'AGENTS.md'
Set-Content $agents '# Existing project rules: preserve this line.' -Encoding utf8
& "$PSScriptRoot\Install-ProjectAI.ps1" -ProjectPath $root | Out-Null
$first = Get-Content $agents -Raw
if (-not $first.Contains('# Existing project rules: preserve this line.')) { throw 'Lost existing instructions' }
& "$PSScriptRoot\Install-ProjectAI.ps1" -ProjectPath $root | Out-Null
$second = Get-Content $agents -Raw
if ($first -ne $second) { throw 'Installer is not idempotent' }
if ([regex]::Matches($second,'<!-- BEGIN PROJECT LOCAL AI -->').Count -ne 1) { throw 'Duplicate instructions' }
Add-Content (Join-Path $root '.ai-local\profiles.json') 'user change'
$caught = $false
try { & "$PSScriptRoot\Install-ProjectAI.ps1" -ProjectPath $root | Out-Null } catch { $caught = $_.Exception.Message -match 'Existing file differs' }
if (-not $caught) { throw 'Installer overwrote edited config' }
$preview = Join-Path $root 'preview-only'
& "$PSScriptRoot\Install-ProjectAI.ps1" -ProjectPath $preview -WhatIf | Out-Null
if (Test-Path $preview) { throw 'WhatIf wrote to disk' }
$bad = Join-Path $root 'bad-markers'
New-Item -ItemType Directory -Path $bad | Out-Null
$badAgents=Join-Path $bad 'AGENTS.md'
foreach($badText in @('<!-- END PROJECT LOCAL AI --><!-- BEGIN PROJECT LOCAL AI -->','<!-- BEGIN PROJECT LOCAL AI -->','<!-- BEGIN PROJECT LOCAL AI --><!-- END PROJECT LOCAL AI --><!-- BEGIN PROJECT LOCAL AI --><!-- END PROJECT LOCAL AI -->')) {
    Set-Content $badAgents $badText -Encoding utf8
    $caught=$false
    try { & "$PSScriptRoot\Install-ProjectAI.ps1" -ProjectPath $bad | Out-Null } catch { $caught=$_.Exception.Message -match 'Malformed' }
    if(-not $caught -or (Test-Path (Join-Path $bad '.ai-local'))) { throw 'Invalid markers changed project' }
}
Write-Output 'PASS: existing instructions preserved, rerun idempotent, edited config protected, WhatIf makes no changes, malformed markers rejected.'
