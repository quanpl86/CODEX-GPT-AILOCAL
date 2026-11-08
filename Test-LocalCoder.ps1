$ErrorActionPreference='Stop'
$testRoot=Join-Path $PSScriptRoot ('test-results\coder-'+[guid]::NewGuid().ToString('N'))
$helper=Join-Path $testRoot 'helper';$project=Join-Path $testRoot 'project'
New-Item -ItemType Directory -Path $helper,(Join-Path $project 'src') -Force|Out-Null
foreach($file in @('Invoke-LocalCoder.ps1','Apply-LocalProposal.ps1','ProjectFiles.psm1')){Copy-Item (Join-Path $PSScriptRoot $file) $helper}
@'
param($Task,$Prompt,$MaxTokens,$TimeoutSec,[switch]$DisableThinking,$ResponseSchema,[switch]$PassThru)
[PSCustomObject]@{done_reason=$global:coderMockDoneReason;message=@{content=($global:coderMockProposal|ConvertTo-Json -Depth 8)};eval_count=20;total_duration=1000000000}
'@|Set-Content (Join-Path $helper 'Ask-Local.ps1') -Encoding utf8
$coder=Join-Path $helper 'Invoke-LocalCoder.ps1';$apply=Join-Path $helper 'Apply-LocalProposal.ps1'
$source=Join-Path $project 'src/item.txt'
[IO.File]::WriteAllText($source,'old',[Text.UTF8Encoding]::new($false))
$global:coderMockDoneReason='stop'
$global:coderMockProposal=@{summary='test';changes=@(@{path='src/item.txt';content='new'});suggested_checks=@('Never execute a model suggestion blindly')}
function Expect-Failure([scriptblock]$Action,[string]$Pattern){
    $message=$null;try{& $Action|Out-Null}catch{$message=$_.Exception.Message}
    if($null -eq $message -or $message -notmatch $Pattern){throw "Expected $Pattern; received $message"}
}
$proposalPath=& $coder -Task web -ProjectPath $project -Files 'src/item.txt' -Prompt 'Update allowed file'
if([IO.File]::ReadAllText($source) -ne 'old'){throw 'Coder wrote source before review'}
$sha=(Get-FileHash $proposalPath).Hash
& $apply -ProposalPath $proposalPath -ProjectPath $project -ReviewedSha256 $sha -WhatIf|Out-Null
if([IO.File]::ReadAllText($source) -ne 'old'){throw 'WhatIf wrote source'}
Expect-Failure {& $apply -ProposalPath $proposalPath -ProjectPath $project -ReviewedSha256 ('0'*64)} 'changed after review'
[IO.File]::WriteAllText($source,'stale')
Expect-Failure {& $apply -ProposalPath $proposalPath -ProjectPath $project -ReviewedSha256 $sha} 'Source changed'
[IO.File]::WriteAllText($source,'old',[Text.UTF8Encoding]::new($false))
$proposal=Get-Content $proposalPath -Raw|ConvertFrom-Json
$stage=Join-Path (Split-Path $proposalPath) $proposal.changes[0].staged_file
$stageBytes=[IO.File]::ReadAllBytes($stage)
[IO.File]::WriteAllText($stage,'tamper')
Expect-Failure {& $apply -ProposalPath $proposalPath -ProjectPath $project -ReviewedSha256 $sha} 'Staged content changed'
[IO.File]::WriteAllBytes($stage,$stageBytes)
& $apply -ProposalPath $proposalPath -ProjectPath $project -ReviewedSha256 $sha|Out-Null
if([IO.File]::ReadAllText($source) -ne 'new'){throw 'Reviewed apply failed'}
$receipt=Get-Content (Join-Path (Split-Path $proposalPath) 'apply-receipt.json') -Raw|ConvertFrom-Json
if($receipt.tests -ne 'not_run'){throw 'Receipt invented test results'}
Import-Module (Join-Path $helper 'ProjectFiles.psm1') -Force
foreach($badPath in @('../escape.txt','.git/config','src/file.txt:stream','NUL.txt','src/../escape.txt')){
    Expect-Failure {Resolve-ProjectFile -ProjectPath $project -RelativePath $badPath} 'Invalid|Protected|relative'
}
$global:coderMockProposal.changes=@(@{path='outside.txt';content='no'})
Expect-Failure {& $coder -ProjectPath $project -Files 'src/item.txt' -Prompt 'Reject unapproved output'} 'unapproved path'
$global:coderMockDoneReason='length'
Expect-Failure {& $coder -ProjectPath $project -Files 'src/item.txt' -Prompt 'Reject truncation'} 'truncated'
$global:coderMockDoneReason='stop'
$global:coderMockProposal.changes=@(@{path='src/bad.ps1';content='param('})
Expect-Failure {& $coder -ProjectPath $project -Files 'src/bad.ps1' -Prompt 'Reject invalid syntax'} 'syntax is invalid'
if(Test-Path (Join-Path $project 'src/bad.ps1')){throw 'Invalid generated script reached source'}
Write-Output 'PASS: local code staged only; reviewed hash, stale source, tamper, paths, allowlist, truncation and apply receipt verified.'
