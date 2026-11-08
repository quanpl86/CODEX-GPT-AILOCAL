param(
    [Parameter(Mandatory=$true)][string]$ProjectId,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Goal,
    [ValidateSet('ask','implement','review','asset','media','learning')][string]$Mode='ask',
    [ValidateSet('codex','chatgpt','antigravity','local')][string]$Agent='codex',
    [ValidateSet('web','game','brain','learning','general')][string]$Domain='general',
    [ValidateSet('low','medium','high')][string]$Complexity='low',
    [ValidateSet('low','high','critical')][string]$Risk='low',
    [string]$RegistryPath=(Join-Path $PSScriptRoot 'hub/projects.json')
)
$ErrorActionPreference='Stop'
$project=& "$PSScriptRoot/Resolve-HubProject.ps1" -ProjectId $ProjectId -RegistryPath $RegistryPath
if($Agent -notin $project.agents){throw 'This agent is not registered for this project'}
$route=& "$PSScriptRoot/Select-TaskRoute.ps1" -Domain $Domain -Complexity $Complexity -Risk $Risk
$id=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$dir=Join-Path $PSScriptRoot "hub/tasks/$id"
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$task=[ordered]@{id=$id;status='ready_for_handoff';project=$project;mode=$Mode;requested_agent=$Agent;goal=$Goal;route=$route;created_at=[DateTimeOffset]::Now.ToString('o');execution_started=$false}
$task|ConvertTo-Json -Depth 12|Set-Content (Join-Path $dir 'task.json') -Encoding utf8
$instructions=@"
# Hub task $id

Project: $($project.id)
Working root: $($project.root)
Mode: $Mode
Assigned agent: $Agent
Goal: $Goal
Policy version: $($project.policy_version)

Read the hub AGENTS.md and docs/TEAM-CONTRACT.vi.md, then this project's AGENTS.md
and existing plan before acting. Do not write into another project or modify the
hub policy as a side effect. Ask mode is read-only. This task does not authorize
publication, purchases, new credentials or unrelated cloud writes.
Local implements bounded tasks in staging; Codex reviews/applies/tests; ChatGPT
plans/reviews milestones and handles only the project's registered, verified MCPs.
Do not reuse another project's ChatGPT connector, Godot binding or open asset file.
For assets read docs/ASSET-PIPELINE.vi.md and agree source/export paths in this project.
Record actual checks and a concise handoff. Do not mark execution started or done
merely because this task package was generated.
"@
$instructions|Set-Content (Join-Path $dir 'handoff.md') -Encoding utf8
[PSCustomObject]@{task_id=$id;project=$project.id;root=$project.root;handoff=(Join-Path $dir 'handoff.md');record=(Join-Path $dir 'task.json');status='ready_for_handoff';execution_started=$false}
