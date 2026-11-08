$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot ('test-results/hub-'+[guid]::NewGuid().ToString('N'))
$project=Join-Path $root 'child';$helper=Join-Path $root 'hub'
New-Item -ItemType Directory -Path $project,$helper -Force|Out-Null
foreach($file in @('Resolve-HubProject.ps1','New-HubTask.ps1','Select-TaskRoute.ps1')){Copy-Item (Join-Path $PSScriptRoot $file) $helper}
$registry=Join-Path $helper 'projects.json'
$data=@{schemaVersion=1;policyVersion='test';projects=@(@{id='child';root=$project;kind='web';enabled=$true;agents=@('codex');mcp=@()})}
$data|ConvertTo-Json -Depth 7|Set-Content $registry
$resolve=Join-Path $helper 'Resolve-HubProject.ps1';$newTask=Join-Path $helper 'New-HubTask.ps1'
$r=& $resolve -ProjectId child -RegistryPath $registry
if($r.root -ne $project){throw 'Resolved wrong project'}
$task=& $newTask -ProjectId child -Agent codex -Mode ask -Goal 'Read only' -RegistryPath $registry
$record=Get-Content $task.record -Raw|ConvertFrom-Json
if($record.execution_started -or $record.project.root -ne $project -or $record.mode -ne 'ask'){throw 'Task scope or status invalid'}
if(@(Get-ChildItem $project -Force).Count){throw 'Dispatch wrote into child source'}
$caught=$false;try{& $newTask -ProjectId child -Agent antigravity -Goal test -RegistryPath $registry|Out-Null}catch{$caught=$_.Exception.Message -match 'not registered'}
if(-not $caught){throw 'Unregistered agent accepted'}
$data.projects[0].enabled=$false;$data|ConvertTo-Json -Depth 7|Set-Content $registry
$caught=$false;try{& $resolve -ProjectId child -RegistryPath $registry|Out-Null}catch{$caught=$_.Exception.Message -match 'disabled'}
if(-not $caught){throw 'Disabled project accepted'}
Write-Output 'PASS: registered project scope, read-only handoff, no source writes, unregistered agent and disabled project blocked.'
