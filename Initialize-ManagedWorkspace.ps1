[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$LayoutPath=(Join-Path $PSScriptRoot 'hub/layout.json'))
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/ManagedProjects.psm1" -Force
$layout=Get-ManagedLayout $LayoutPath
Assert-NoProjectLinks $layout.root
$rules=@'
# Managed AI projects

New projects must be created through the central hub New-ManagedProject.ps1.
Allowed categories: web, games, apps, media, learning. Each project has a unique
registered ID, project.json, AGENTS.md and WORK-BOARD.md. Resolve the registered ID
and validate its root/identity before writing. Do not infer a project from an open app.
Do not move, overwrite or register an existing repository implicitly.
Ask/review-only tasks are read-only. Publish, payments and external writes require
their actual task authorization. One writer per file; preserve secrets and user work.
Read the child's AGENTS.md and hub handoff before implementation. Local code stays
in staging until Codex reviews/applies/tests; ChatGPT owns plan and MCP asset tasks.
Keep source assets separate from runtime exports, and verify actual outputs.
Rules are guidance plus tool validation, not a substitute for client sandbox permissions.
'@
$rulesPath=Join-Path $layout.root 'AGENTS.md'
if(Test-Path $rulesPath){if((Get-Content $rulesPath -Raw).Trim() -ne $rules.Trim()){throw 'Workspace AGENTS.md differs; review it before updating. Nothing was overwritten.'}}
if($PSCmdlet.ShouldProcess($layout.root,'Create managed categories and shared agent rules')){
    New-Item -ItemType Directory -Path $layout.root -Force|Out-Null
    foreach($category in $layout.categories){New-Item -ItemType Directory -Path (Join-Path $layout.root $category) -Force|Out-Null}
    if(-not(Test-Path $rulesPath)){[IO.File]::WriteAllText($rulesPath,$rules+"`n",[Text.UTF8Encoding]::new($false))}
    Write-Output $layout.root
}
