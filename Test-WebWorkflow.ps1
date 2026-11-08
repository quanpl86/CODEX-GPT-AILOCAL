$ErrorActionPreference='Stop'
$id=[guid]::NewGuid().ToString('N')
$fixture=Join-Path $PSScriptRoot "test-results/web-workflow-$id"
$project=Join-Path $fixture 'project'
$run=Join-Path $PSScriptRoot "local-runs/gateway-$id"
New-Item -ItemType Directory -Path "$project/src","$run/changes" -Force|Out-Null
$registry=Join-Path $fixture 'projects.json'
@{schemaVersion=1;policyVersion='test';projects=@(@{id='fixture';root=$project;kind='web';enabled=$true;agents=@('local','codex');mcp=@()})}|ConvertTo-Json -Depth 7|Set-Content $registry
$source=Join-Path $project 'src/score.mjs';Set-Content $source 'export const score=1;'
$stage=Join-Path $run 'changes/0.txt';Set-Content $stage 'export const score=2;'
$proposal=Join-Path $run 'proposal.json'
@{project=$project;status='awaiting_codex_review';changes=@(@{path='src/score.mjs';original_hash=(Get-FileHash $source).Hash;proposed_hash=(Get-FileHash $stage).Hash;staged_file='changes/0.txt'})}|ConvertTo-Json -Depth 6|Set-Content $proposal
$sha=(Get-FileHash $proposal).Hash
function Gateway($request){
    $file=Join-Path $fixture 'request.json';$request|ConvertTo-Json -Depth 6|Set-Content $file
    $output=& "$PSScriptRoot/web/bridge.ps1" -RequestPath $file -RegistryPath $registry
    $line=@($output|Where-Object {$_ -is [string] -and $_.StartsWith('@@HUB@@')})[-1]
    if(-not $line){throw 'Bridge protocol missing'}; $line.Substring(7)|ConvertFrom-Json
}
$r=Gateway @{action='proposal';project='fixture';proposal=$proposal;sha256=$sha}
if(-not $r.ok -or $r.data.changes[0].original -notmatch 'score=1' -or $r.data.changes[0].proposed -notmatch 'score=2'){throw 'Full original/proposed review context missing'}
$r=Gateway @{action='applicationState';project='fixture';proposal=$proposal;sha256=$sha}
if(-not $r.ok -or $r.data.applied){throw 'Unapplied proposal detected as applied'}
$r=Gateway @{action='proposal';project='fixture';proposal=(Join-Path $fixture 'outside.json');sha256=$sha}
if($r.ok -or $r.error -notmatch 'inside hub local-runs'){throw 'Outside proposal accepted'}
Set-Content $source 'stale'
$r=Gateway @{action='apply';project='fixture';proposal=$proposal;sha256=$sha}
if($r.ok -or $r.error -notmatch 'Source changed'){throw 'Stale source accepted'}
Set-Content $source 'export const score=1;'
Set-Content $stage 'tampered'
$r=Gateway @{action='proposal';project='fixture';proposal=$proposal;sha256=$sha}
if($r.ok -or $r.error -notmatch 'Staged content changed'){throw 'Tampered staging accepted'}
Set-Content $stage 'export const score=2;'
$r=Gateway @{action='apply';project='fixture';proposal=$proposal;sha256=$sha}
if(-not $r.ok -or $r.data.tests -ne 'not_run' -or (Get-Content $source -Raw) -notmatch 'score=2'){throw 'Reviewed apply failed'}
$r=Gateway @{action='applicationState';project='fixture';proposal=$proposal;sha256=$sha}
if(-not $r.ok -or -not $r.data.applied -or $r.data.receipt.proposal_sha256 -ne $sha){throw 'Durable applied receipt not detected'}
$r=Gateway @{action='appliedProposal';project='fixture';proposal=$proposal;sha256=$sha}
if(-not $r.ok){throw 'Applied proposal not verified'}
Set-Content $source 'export const score=99;'
$r=Gateway @{action='appliedProposal';project='fixture';proposal=$proposal;sha256=$sha}
if($r.ok){throw 'Changed applied source accepted as reviewed'}
Set-Content $source 'export const score=2;'
$r=Gateway @{action='apply';project='fixture';proposal=$proposal;sha256=$sha}
if($r.ok){throw 'Duplicate apply accepted'}
$r=Gateway @{action='checks';project='fixture';files=@('src/score.mjs');testFiles=@()}
if(-not $r.ok -or -not $r.data.passed -or $r.data.runtime_verified){throw 'Syntax evidence incorrect'}
Set-Content (Join-Path $project 'score.test.mjs') 'import assert from "node:assert/strict"; import {score} from "./src/score.mjs"; assert.equal(score,2);'
$r=Gateway @{action='checks';project='fixture';files=@('src/score.mjs');testFiles=@('score.test.mjs')}
if(-not $r.ok -or -not $r.data.passed -or -not $r.data.test_execution){throw 'Actual Node tests failed'}
$r=Gateway @{action='checks';project='fixture';files=@('src/score.mjs');testFiles=@('../outside.test.mjs')}
if($r.ok){throw 'Outside test path accepted'}
$r=Gateway @{action='document';project='fixture';file='../projects.json'}
if($r.ok){throw 'Outside source read accepted'}
$r=Gateway @{action='document';project='fixture';file='.env'}
if($r.ok){throw 'Secret document read accepted'}
$r=Gateway @{action='sources';project='fixture';files=@('src/score.mjs')}
if(-not $r.ok){throw 'Source context missing'}
$sources=$r.data.sources
$r=Gateway @{action='cloudStage';project='fixture';sources=$sources;code=@{summary='malicious';changes=@(@{path='outside.mjs';content='bad'})}}
if($r.ok){throw 'Cloud out-of-scope proposal accepted'}
$r=Gateway @{action='cloudStage';project='fixture';sources=$sources;code=@{summary='fixture';changes=@(@{path='src/score.mjs';content='export const score=3;'})}}
if(-not $r.ok -or (Get-Content $source -Raw) -notmatch 'score=2'){throw 'Cloud staging failed or wrote source'}
$r=Gateway @{action='board';project='fixture';content='# Plan';sha256='stale'}
if($r.ok){throw 'Stale board write accepted'}
$r=Gateway @{action='verifyHashes';project='fixture';hashes=@(@{path='src/score.mjs';sha256='stale'})}
if($r.ok){throw 'Runtime acceptance with stale source accepted'}
$linkFixture=Join-Path ([IO.Path]::GetTempPath()) "hub-document-link-$id"
New-Item -ItemType Directory -Path (Join-Path $linkFixture 'project') -Force|Out-Null
$linkedParent=Join-Path $linkFixture 'linked-parent'
New-Item -ItemType Junction -Path $linkedParent -Target $linkFixture|Out-Null
try {
    $linkedRoot=Join-Path $linkedParent 'project'
    $config=Get-Content $registry -Raw|ConvertFrom-Json
    $config.projects[0].root=$linkedRoot
    $config|ConvertTo-Json -Depth 7|Set-Content $registry
    $r=Gateway @{action='context';project='fixture';agent='codex'}
    if($r.ok -or $r.error -notmatch 'Reparse'){throw 'Document read through a linked ancestor accepted'}
} finally {
    $config.projects[0].root=$project;$config|ConvertTo-Json -Depth 7|Set-Content $registry
    $linkItem=Get-Item -LiteralPath $linkedParent -Force
    if($linkItem.FullName -eq [IO.Path]::GetFullPath($linkedParent) -and ($linkItem.Attributes -band [IO.FileAttributes]::ReparsePoint)){Remove-Item -LiteralPath $linkedParent -Force}
    [IO.Directory]::Delete((Join-Path $linkFixture 'project'));[IO.Directory]::Delete($linkFixture)
}
Write-Output 'PASS: real web gateway full review context, proposal boundary/tamper/stale rejection, apply, duplicate protection and actual Node checks.'
