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
[PSCustomObject]@{id=$project.id;root=$root;kind=$project.kind;agents=@($project.agents);mcp=@($project.mcp);policy_version=$registry.policyVersion;project_rules=Join-Path $root 'AGENTS.md'}
