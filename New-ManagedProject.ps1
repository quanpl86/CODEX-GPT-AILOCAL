[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$')][ValidateLength(1,64)][string]$ProjectId,
    [Parameter(Mandatory=$true)][ValidateSet('web','games','apps','media','learning')][string]$Kind,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Goal,
    [ValidateSet('none','vanilla-web')][string]$Template='none',
    [string]$LayoutPath=(Join-Path $PSScriptRoot 'hub/layout.json'),
    [string]$RegistryPath=(Join-Path $PSScriptRoot 'hub/projects.json')
)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/ManagedProjects.psm1" -Force
$layout=Get-ManagedLayout $LayoutPath
if($Template -eq 'vanilla-web' -and $Kind -notin @('web','games','apps')){throw 'Web template requires web/games/apps category'}
$root=Join-Path (Join-Path $layout.root $Kind) $ProjectId
Assert-NoProjectLinks $root
if($ProjectId -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])$'){throw 'Reserved project name'}
if(Test-Path -LiteralPath $root){throw 'Project path already exists; use explicit onboarding instead of overwriting it.'}
if(-not(Test-Path -LiteralPath $RegistryPath)){throw 'Project registry missing; initialize the hub registry first.'}
if(-not $PSCmdlet.ShouldProcess($root,'Create governed project skeleton and register exact project root')){return}
$lock=$null
try{
    $lock=[IO.File]::Open(($RegistryPath+'.lock'),'OpenOrCreate','ReadWrite','None')
    $registry=Get-Content -LiteralPath $RegistryPath -Raw|ConvertFrom-Json
    if($registry.schemaVersion -ne 1){throw 'Unsupported registry schema'}
    if(@($registry.projects|Where-Object id -eq $ProjectId).Count){throw 'Project ID already registered'}
    $registeredRoots=@(foreach($p in $registry.projects){if([IO.Path]::IsPathRooted($p.root)){[IO.Path]::GetFullPath($p.root)}else{[IO.Path]::GetFullPath((Join-Path (Split-Path ([IO.Path]::GetFullPath($RegistryPath))) $p.root))}})
    if($root -in $registeredRoots){throw 'Project root already registered'}
    # All validation precedes writes. Existing repositories are never modified here.
    & "$PSScriptRoot/Initialize-ManagedWorkspace.ps1" -LayoutPath $LayoutPath|Out-Null
    if(Test-Path -LiteralPath $root){throw 'Project directory appeared during creation; refusing overwrite'}
    New-Item -ItemType Directory -Path $root -ErrorAction Stop|Out-Null
    $folders=@('docs','art/source/blender','art/source/blockbench','art/previews','art/briefs','exports')
    if($Kind -in @('web','games','apps')){$folders+=@('src','tests','public/assets/2d','public/assets/3d')}
    else{$folders+=@('content','sources','reviews')}
    foreach($folder in $folders){New-Item -ItemType Directory -Path (Join-Path $root $folder) -Force|Out-Null}
    if($Template -eq 'vanilla-web'){
        foreach($mapping in @(@('index.html','index.html'),@('styles.css','styles.css'),@('main.js','src/main.js'))){Copy-Item -LiteralPath (Join-Path $PSScriptRoot "templates/projects/vanilla-web/$($mapping[0])") -Destination (Join-Path $root $mapping[1])}
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'templates/ui/tokens.css') -Destination (Join-Path $root 'src/tokens.css')
    }
    $metadata=@{schemaVersion=1;id=$ProjectId;kind=$Kind;root=$root;policyVersion=$layout.policyVersion;hubRoot=$PSScriptRoot;goal=$Goal;stack=if($Template -eq 'none'){'not_selected'}else{$Template};mcpBindings=@();status='initialized_not_implemented'}
    $metadata|ConvertTo-Json -Depth 7|Set-Content (Join-Path $root 'project.json') -Encoding utf8
    $rules=@"
# Project $ProjectId

Registered root: $root
Category: $Kind
Governance version: $($layout.policyVersion)
Central hub: $PSScriptRoot

Before any write resolve project '$ProjectId' through the hub and read project.json,
WORK-BOARD.md, the task handoff, and hub docs/TEAM-CONTRACT.vi.md. Work only in this
registered root. Read-only questions never authorize source edits. Do not modify hub
policy, another project, app binding or credentials as a side effect of this task.
Local AI writes bounded code/tests in staging; Codex reviews/applies/tests and reports
failures; ChatGPT handles plans and user-authorized MCP asset work. Antigravity may
participate only after its adapter/project permissions are explicitly configured.
Select stack and acceptance before generating application code. Reuse existing modules,
keep contracts small, refactor incrementally and use one shared UI design system.
Track phase/task/owner/evidence in WORK-BOARD.md. Test actual behavior; web/UI changes
require external Chrome runtime verification, not only headless checks.
Source assets: art/source; review previews: art/previews; approved runtime 2D/3D exports:
public/assets for app/web/game, or exports for media/learning. Do not serve source
authoring files or secrets. Require exact output paths and verify active app/project.
An initialized skeleton is not an implemented or production-ready product.
"@
    $rules|Set-Content (Join-Path $root 'AGENTS.md') -Encoding utf8
    "# $ProjectId`n`nGoal: $Goal`n`nStatus: project skeleton only; stack and acceptance need planning.`n"|Set-Content (Join-Path $root 'README.md') -Encoding utf8
    "# Work board`n`n| Phase | Owner | Status | Evidence |`n|---|---|---|---|`n| Plan and stack | ChatGPT + Codex | Pending | Goal recorded; stack not selected |`n| Implementation | Local -> Codex | Pending | No code generated |`n| Verification | Codex QA | Pending | No runtime checks yet |`n"|Set-Content (Join-Path $root 'WORK-BOARD.md') -Encoding utf8
    "node_modules/`n.ai-local.apply.lock`n.env`n.env.*`n!.env.example`n.ai-local/local-runs/`n.service-state/`n"|Set-Content (Join-Path $root '.gitignore') -Encoding utf8
    $entry=[PSCustomObject]@{id=$ProjectId;root=$root;kind=$Kind;enabled=$true;agents=@('codex','chatgpt','local');mcp=@();managed=$true;layoutRoot=$layout.root;policyVersion=$layout.policyVersion}
    $registry.projects=@($registry.projects)+@($entry)
    $temporary=$RegistryPath+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try{$registry|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $temporary -Encoding utf8;Move-Item -LiteralPath $temporary -Destination $RegistryPath -Force}
    finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary}}
    [PSCustomObject]@{id=$ProjectId;root=$root;status='initialized_not_implemented';registered=$true}
}finally{if($lock){$lock.Dispose()}}
