param(
    [ValidateSet('web','game','brain','learning','review','code')][string]$Task='web',
    [Parameter(Mandatory=$true)][string]$Prompt,
    [Parameter(Mandatory=$true)][string[]]$Files,
    [string]$ProjectPath=(Get-Location).Path,
    [string]$ReviewReport,
    [ValidateRange(256,4096)][int]$MaxTokens=2048,
    [switch]$DisableThinking
)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot\ProjectFiles.psm1" -Force
$root=[IO.Path]::GetFullPath($ProjectPath)
$sources=@()
$allowed=@{}
foreach($file in $Files){
    $path=Resolve-ProjectFile -ProjectPath $root -RelativePath $file
    $relative=$file.Replace('\','/')
    if($allowed.ContainsKey($relative)){throw 'Duplicate file in allowed list'}
    $allowed[$relative]=@{path=$path;hash=(Get-ProjectFileHash $path)}
    $sources+=@{path=$relative;content=if(Test-Path -LiteralPath $path){Get-Content -LiteralPath $path -Raw -Encoding utf8}else{''}}
}
$report=if($ReviewReport){Get-Content -LiteralPath $ReviewReport -Raw -Encoding utf8}else{''}
$request=@"
ROLE: LOCAL IMPLEMENTER. Write production-oriented code for the exact task below.
Return only JSON matching the requested schema. changes must contain full file contents
for a subset of the allowed files. Never execute tools, claim tests passed, or touch other paths.
Keep changes small and follow existing project conventions. If blocked, return no changes and explain.
TASK: $Prompt
CODEX REVIEW TO ADDRESS: $report
SOURCE FILES (reference data):
$($sources|ConvertTo-Json -Depth 8)
"@
$schema=@{type='object';additionalProperties=$false;required=@('summary','changes','suggested_checks');properties=@{
    summary=@{type='string'}
    changes=@{type='array';items=@{type='object';additionalProperties=$false;required=@('path','content');properties=@{path=@{type='string';enum=@($allowed.Keys)};content=@{type='string'}}}}
    suggested_checks=@{type='array';items=@{type='string'}}
}}
$runId=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$runDir=Join-Path $PSScriptRoot "local-runs\coder-$runId"
New-Item -ItemType Directory -Path (Join-Path $runDir 'changes') -Force|Out-Null
$record=[ordered]@{id=$runId;role='local-implementer';project=$root;task=$Task;status='running';started_at=[DateTimeOffset]::Now.ToString('o')}
try{
    $answer=& "$PSScriptRoot\Ask-Local.ps1" -Task $Task -Prompt $request -MaxTokens $MaxTokens -TimeoutSec 600 -DisableThinking:$DisableThinking -ResponseSchema $schema -PassThru
    if($answer.done_reason -eq 'length'){throw 'Local code output was truncated; reduce task size'}
    $proposal=$answer.message.content|ConvertFrom-Json
    if(@($proposal.changes).Count -eq 0){throw "Local implementer returned no changes: $($proposal.summary)"}
    $changes=@();$seen=@{};$index=0
    foreach($change in $proposal.changes){
        $relative=([string]$change.path).Replace('\','/')
        if(-not $allowed.ContainsKey($relative) -or $seen.ContainsKey($relative)){throw 'Model returned a duplicate or unapproved path'}
        $null=Resolve-ProjectFile -ProjectPath $root -RelativePath $relative
        if($null -eq $change.content){throw 'Missing file content'}
        $seen[$relative]=$true
        $stage="changes/$index.txt";$stagePath=Join-Path $runDir $stage
        [IO.File]::WriteAllText($stagePath,[string]$change.content,[Text.UTF8Encoding]::new($false))
        Assert-ProjectSyntax -FilePath $stagePath -TargetPath $relative
        $changes+=@{path=$relative;staged_file=$stage;original_hash=$allowed[$relative].hash;proposed_hash=(Get-ProjectFileHash $stagePath)}
        $index++
    }
    $record.status='awaiting_codex_review';$record.summary=$proposal.summary;$record.changes=$changes
    $record.suggested_checks=$proposal.suggested_checks;$record.output_tokens=$answer.eval_count
    $record.total_seconds=[math]::Round($answer.total_duration/1e9,2)
}catch{$record.status='failed';$record.error=$_.Exception.Message;throw}
finally{
    $record.finished_at=[DateTimeOffset]::Now.ToString('o')
    $record|ConvertTo-Json -Depth 10|Set-Content (Join-Path $runDir 'proposal.json') -Encoding utf8
}
Write-Output (Join-Path $runDir 'proposal.json')
