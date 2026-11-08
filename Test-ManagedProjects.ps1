$ErrorActionPreference='Stop'
$testRoot=Join-Path $PSScriptRoot ('test-results/managed-'+[guid]::NewGuid().ToString('N'))
$helpers=Join-Path $testRoot 'hub';$workspace=Join-Path $testRoot 'projects'
New-Item -ItemType Directory -Path $helpers -Force|Out-Null
foreach($file in @('ManagedProjects.psm1','Initialize-ManagedWorkspace.ps1','New-ManagedProject.ps1','Resolve-HubProject.ps1','New-HubTask.ps1','Select-TaskRoute.ps1')){Copy-Item (Join-Path $PSScriptRoot $file) $helpers}
$layout=Join-Path $helpers 'layout.json';$registry=Join-Path $helpers 'projects.json'
@{schemaVersion=1;workspaceRoot=$workspace;categories=@('web','games','apps','media','learning');policyVersion='test'}|ConvertTo-Json|Set-Content $layout
@{schemaVersion=1;policyVersion='test';projects=@()}|ConvertTo-Json|Set-Content $registry
$new=Join-Path $helpers 'New-ManagedProject.ps1';$resolve=Join-Path $helpers 'Resolve-HubProject.ps1'
function Must-Fail([scriptblock]$Action,[string]$Pattern){$errorText=$null;try{& $Action|Out-Null}catch{$errorText=$_.Exception.Message};if(-not $errorText -or $errorText -notmatch $Pattern){throw "Expected $Pattern, got $errorText"}}
& $new -ProjectId preview -Kind web -Goal test -LayoutPath $layout -RegistryPath $registry -WhatIf|Out-Null
if(Test-Path $workspace){throw 'WhatIf wrote workspace'}
$p=& $new -ProjectId math-board-game -Kind games -Goal 'Test only' -LayoutPath $layout -RegistryPath $registry
if($p.root -ne (Join-Path $workspace 'games/math-board-game')){throw 'Wrong managed path'}
$r=& $resolve -ProjectId math-board-game -RegistryPath $registry
if($r.root -ne $p.root){throw 'Wrong resolved project'}
foreach($folder in @('art/source/blender','art/source/blockbench','public/assets/2d','public/assets/3d','src','tests')){if(-not(Test-Path (Join-Path $p.root $folder))){throw 'Missing required project folder'}}
$before=(Get-FileHash $registry).Hash
Must-Fail {& $new -ProjectId math-board-game -Kind web -Goal duplicate -LayoutPath $layout -RegistryPath $registry} 'already registered'
if((Get-FileHash $registry).Hash -ne $before){throw 'Duplicate modified registry'}
Must-Fail {& $new -ProjectId '../escape' -Kind web -Goal invalid -LayoutPath $layout -RegistryPath $registry} 'pattern'
$metaPath=Join-Path $p.root 'project.json';$meta=Get-Content $metaPath -Raw|ConvertFrom-Json;$meta.id='wrong';$meta|ConvertTo-Json -Depth 6|Set-Content $metaPath
Must-Fail {& $resolve -ProjectId math-board-game -RegistryPath $registry} 'identity differs'
$lock=[IO.File]::Open(($registry+'.lock'),'OpenOrCreate','ReadWrite','None')
try{Must-Fail {& $new -ProjectId locked -Kind apps -Goal test -LayoutPath $layout -RegistryPath $registry} 'another process|being used'}finally{$lock.Dispose()}
if(Test-Path (Join-Path $workspace 'apps/locked')){throw 'Locked registry still created project'}
$templateRoot=Join-Path $helpers 'templates/projects/vanilla-web'
New-Item -ItemType Directory -Path $templateRoot,(Join-Path $helpers 'templates/ui') -Force|Out-Null
foreach($name in @('index.html','styles.css','main.js')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot "templates/projects/vanilla-web/$name") -Destination (Join-Path $templateRoot $name)}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'templates/ui/tokens.css') -Destination (Join-Path $helpers 'templates/ui/tokens.css')
$template=& $new -ProjectId starter -Kind web -Goal 'Template test' -Template vanilla-web -LayoutPath $layout -RegistryPath $registry
foreach($name in @('index.html','styles.css','src/main.js','src/tokens.css')){if(-not(Test-Path -LiteralPath (Join-Path $template.root $name))){throw 'Template asset missing'}}
$metadata=Get-Content (Join-Path $template.root 'project.json') -Raw|ConvertFrom-Json
if($metadata.stack -ne 'vanilla-web'){throw 'Template stack not recorded'}
Write-Output 'PASS: managed layout, skeleton, registry identity, duplicate/traversal rejection, WhatIf, and creation lock.'
