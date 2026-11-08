param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9][a-z0-9-]{0,63}$')][string]$ProjectId,
    [string]$RegistryPath=(Join-Path $PSScriptRoot 'hub/projects.json')
)
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $RegistryPath)){throw 'Create hub/projects.json from the example and register exact project roots first.'}
$registry=Get-Content -LiteralPath $RegistryPath -Raw|ConvertFrom-Json
if($registry.schemaVersion -ne 1){throw 'Unsupported project registry schema'}
$matches=@($registry.projects|Where-Object id -eq $ProjectId)
if($matches.Count -ne 1 -or -not $matches[0].enabled){throw 'Project is missing, duplicated or disabled'}
$project=$matches[0]
$root=if([IO.Path]::IsPathRooted($project.root)){[IO.Path]::GetFullPath($project.root)}else{[IO.Path]::GetFullPath((Join-Path (Split-Path ([IO.Path]::GetFullPath($RegistryPath))) $project.root))}
if(-not(Test-Path -LiteralPath $root -PathType Container)){throw 'Registered project directory does not exist'}
if($root.TrimEnd('\','/') -eq [IO.Path]::GetPathRoot($root).TrimEnd('\','/')){throw 'Drive roots cannot be registered as projects'}
if((Get-Item -LiteralPath $root -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Project root must not be a reparse point'}
if($project.managed){
    Import-Module "$PSScriptRoot/ManagedProjects.psm1" -Force
    Assert-NoProjectLinks $root
    if($project.kind -notin @('web','games','apps','media','learning')){throw 'Managed project category invalid'}
    $expected=[IO.Path]::GetFullPath((Join-Path (Join-Path $project.layoutRoot $project.kind) $project.id))
    if($expected -ne $root){throw 'Managed project root violates category/ID layout'}
    $metadata=Get-Content -LiteralPath (Join-Path $root 'project.json') -Raw|ConvertFrom-Json
    if($metadata.id -ne $ProjectId -or $metadata.kind -ne $project.kind -or [IO.Path]::GetFullPath($metadata.root) -ne $root){throw 'Managed project identity differs from registry'}
    foreach($required in @('AGENTS.md','WORK-BOARD.md','README.md')){if(-not(Test-Path -LiteralPath (Join-Path $root $required) -PathType Leaf)){throw "Managed project governance file missing: $required"}}
}
[PSCustomObject]@{id=$project.id;root=$root;kind=$project.kind;agents=@($project.agents);mcp=@($project.mcp);policy_version=$registry.policyVersion;project_rules=Join-Path $root 'AGENTS.md'}
