[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][string]$ProposalPath,
    [Parameter(Mandatory=$true)][string]$ProjectPath,
    [Parameter(Mandatory=$true)][string]$ReviewedSha256
)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot\ProjectFiles.psm1" -Force
if((Get-FileHash -LiteralPath $ProposalPath -Algorithm SHA256).Hash -ne $ReviewedSha256){throw 'Proposal changed after review'}
$proposal=Get-Content -LiteralPath $ProposalPath -Raw|ConvertFrom-Json
$root=[IO.Path]::GetFullPath($ProjectPath).TrimEnd('\','/')
if($root -ne ([IO.Path]::GetFullPath($proposal.project).TrimEnd('\','/'))){throw 'Wrong project for proposal'}
if($proposal.status -ne 'awaiting_codex_review'){throw 'Proposal is not ready for review/apply'}
$runDir=Split-Path ([IO.Path]::GetFullPath($ProposalPath))
if(Test-Path -LiteralPath (Join-Path $runDir 'apply-receipt.json')){throw 'Proposal already applied; generate a new proposal for further changes'}
$applyLock=$null
try {
if(-not $WhatIfPreference){
    try{$applyLock=[IO.File]::Open((Join-Path $root '.ai-local.apply.lock'),'OpenOrCreate','ReadWrite','None')}
    catch [IO.IOException]{throw 'Another applier owns this project. Wait before applying.'}
}
$writes=@();$seen=@{}
foreach($change in $proposal.changes){
    if($seen.ContainsKey($change.path)){throw 'Duplicate target path'}
    $seen[$change.path]=$true
    $dest=Resolve-ProjectFile -ProjectPath $root -RelativePath $change.path
    if((Get-ProjectFileHash $dest) -ne $change.original_hash){throw "Source changed since proposal: $($change.path)"}
    if($change.staged_file -notmatch '^changes/[0-9]+\.txt$'){throw 'Invalid staging path'}
    $stage=Resolve-ProjectFile -ProjectPath $runDir -RelativePath $change.staged_file
    if(-not (Test-Path -LiteralPath $stage -PathType Leaf) -or (Get-ProjectFileHash $stage) -ne $change.proposed_hash){throw 'Staged content changed after review'}
    Assert-ProjectSyntax -FilePath $stage -TargetPath $change.path
    $writes+=@{dest=$dest;stage=$stage;path=$change.path;existed=(Test-Path -LiteralPath $dest);old=if(Test-Path -LiteralPath $dest){,[IO.File]::ReadAllBytes($dest)}else{$null}}
}
if($writes.Count -eq 0){throw 'Proposal has no changes'}
if($PSCmdlet.ShouldProcess($root,"Apply $($writes.Count) reviewed local-generated file(s)")){
    $written=@()
    $receiptTemp=Join-Path $runDir ('apply-receipt-'+[guid]::NewGuid().ToString('N')+'.tmp')
    try{
        foreach($write in $writes){
            $null=Resolve-ProjectFile -ProjectPath $root -RelativePath $write.path
            $written+=,$write
            New-Item -ItemType Directory -Path (Split-Path $write.dest) -Force|Out-Null
            [IO.File]::WriteAllBytes($write.dest,[IO.File]::ReadAllBytes($write.stage))
        }
        $receipt=@{proposal_sha256=$ReviewedSha256;applied_at=[DateTimeOffset]::Now.ToString('o');project=$root;files=@($writes.path);tests='not_run';role='codex-applier'}
        $receipt|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $receiptTemp -Encoding utf8
        Move-Item -LiteralPath $receiptTemp -Destination (Join-Path $runDir 'apply-receipt.json') -ErrorAction Stop
    }catch{
        $original=$_.Exception;$rollbackErrors=@()
        foreach($write in $written){try{if(-not $write.existed){if(Test-Path -LiteralPath $write.dest){Remove-Item -LiteralPath $write.dest -Force -ErrorAction Stop}}else{[IO.File]::WriteAllBytes($write.dest,[byte[]]$write.old)}}catch{$rollbackErrors+=$_.Exception.Message}}
        if($rollbackErrors.Count){throw "Apply failed: $($original.Message). Rollback also failed: $($rollbackErrors -join '; ')"}
        throw
    }finally{if(Test-Path -LiteralPath $receiptTemp){Remove-Item -LiteralPath $receiptTemp -Force -ErrorAction Stop}}
    Write-Output 'Reviewed code applied. Tests and runtime verification are still required.'
}
}finally{if($applyLock){$applyLock.Dispose()}}
