$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot ('test-results/startup-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force|Out-Null
Copy-Item "$PSScriptRoot/Ensure-ProjectService.ps1" $root
$config=Join-Path $root 'integrations.json'
@{services=@{ollama=@{executable='missing-ollama.exe';port=11434};godot=@{executable='missing-godot.exe';projectConfig=(Join-Path $root 'godot.json');port=3000}}}|ConvertTo-Json -Depth 6|Set-Content $config -Encoding utf8
$global:startupApiReady=$true
function Invoke-RestMethod {param($Uri,$TimeoutSec) if($global:startupApiReady){return @{version='test'}};throw 'offline'}
function Start-Process {throw 'Unexpected process creation in offline test'}
$result=& "$root/Ensure-ProjectService.ps1" -Service ollama -ConfigPath $config -TimeoutSec 1
if(-not $result.local_ready -or $result.remote_verified){throw 'Existing API readiness or remote status invalid'}
$global:startupApiReady=$false
$caught=$false
try{& "$root/Ensure-ProjectService.ps1" -Service ollama -ConfigPath $config -TimeoutSec 1|Out-Null}catch{$caught=$_.Exception.Message -match 'Executable missing'}
if(-not $caught){throw 'Missing executable did not fail before launch'}
$caught=$false
try{& "$root/Ensure-ProjectService.ps1" -Service godot -ConfigPath $config -TimeoutSec 1|Out-Null}catch{$caught=$_.Exception.Message -match 'ExpectedGodotProject'}
if(-not $caught){throw 'Godot selected project implicitly'}
@{project_path=(Join-Path $root 'old-project');godot_path='missing-godot.exe'}|ConvertTo-Json|Set-Content "$root/godot.json"
$caught=$false
try{& "$root/Ensure-ProjectService.ps1" -Service godot -ConfigPath $config -ExpectedGodotProject (Join-Path $root 'new-project') -TimeoutSec 1|Out-Null}catch{$caught=$_.Exception.Message -match 'binding differs'}
if(-not $caught){throw 'Godot accepted a different project binding'}
Write-Output 'PASS: reuse ready API without launch; missing executable blocked; explicit Godot binding required; remote status never inferred.'
