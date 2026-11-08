param([Parameter(Mandatory)][string]$RequestPath,[string]$RegistryPath=(Join-Path (Split-Path $PSScriptRoot) 'hub/projects.json'))
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$OutputEncoding=[Text.UTF8Encoding]::new($false)
$hub=Split-Path $PSScriptRoot
Import-Module "$hub/ProjectFiles.psm1" -Force
Import-Module "$hub/ManagedProjects.psm1" -Force
$r=Get-Content -LiteralPath $RequestPath -Raw|ConvertFrom-Json
function Read-Document($root,$name){
    Assert-NoProjectLinks $root
    $file=Resolve-ProjectFile -ProjectPath $root -RelativePath $name
    if(-not(Test-Path -LiteralPath $file -PathType Leaf)){return ''}
    if((Get-Item -LiteralPath $file -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked documents are not allowed'}
    if((Get-Item -LiteralPath $file).Length -gt 131072){throw 'Document exceeds 128 KiB'}
    Get-Content -LiteralPath $file -Raw
}
function Get-VerifiedProposal($project,$proposalPath,$sha,$afterApply=$false,$applicationState=$false){
    $base=[IO.Path]::GetFullPath((Join-Path $hub 'local-runs')).TrimEnd('\','/')
    $full=[IO.Path]::GetFullPath($proposalPath)
    if(-not $full.StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Proposal must be inside hub local-runs'}
    $relative=[IO.Path]::GetRelativePath($base,$full)
    $null=Resolve-ProjectFile -ProjectPath $base -RelativePath $relative
    if((Get-FileHash -LiteralPath $full).Hash -ne $sha){throw 'Proposal changed after review'}
    $proposal=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json
    if([IO.Path]::GetFullPath($proposal.project) -ne $project.root -or $proposal.status -ne 'awaiting_codex_review'){throw 'Proposal project/status mismatch'}
    if($applicationState){
        $receiptFile=Resolve-ProjectFile -ProjectPath (Split-Path $full) -RelativePath 'apply-receipt.json'
        if(-not(Test-Path -LiteralPath $receiptFile -PathType Leaf)){return @{applied=$false}}
        $afterApply=$true
    }
    if($afterApply){
        $receiptFile=Resolve-ProjectFile -ProjectPath (Split-Path $full) -RelativePath 'apply-receipt.json'
        $receipt=Get-Content -LiteralPath $receiptFile -Raw|ConvertFrom-Json
        if($receipt.proposal_sha256 -ne $sha -or [IO.Path]::GetFullPath($receipt.project).TrimEnd('\','/') -ne $project.root.TrimEnd('\','/')){throw 'Applied receipt does not match reviewed proposal/project'}
    }
    $changes=@(foreach($change in $proposal.changes){
        $source=Resolve-ProjectFile -ProjectPath $project.root -RelativePath $change.path
        if($afterApply){if((Get-ProjectFileHash $source) -ne $change.proposed_hash){throw 'Source changed after apply; new proposal/review required'}}
        elseif((Get-ProjectFileHash $source) -ne $change.original_hash){throw 'Source changed since proposal'}
        if($change.staged_file -notmatch '^changes/[0-9]+\.txt$'){throw 'Invalid staging path'}
        $stage=Resolve-ProjectFile -ProjectPath (Split-Path $full) -RelativePath $change.staged_file
        if((Get-ProjectFileHash $stage) -ne $change.proposed_hash){throw 'Staged content changed'}
        @{path=$change.path;original=if(Test-Path -LiteralPath $source){[IO.File]::ReadAllText($source)}else{''};proposed=[IO.File]::ReadAllText($stage)}
    })
    if(-not $changes.Count){throw 'Empty proposal'}
    if($applicationState){return @{applied=$true;receipt=$receipt}}
    @{sha256=$sha;changes=$changes}
}
function Assert-PromptFile($file){
    if($file -match '(?i)(^|[/\\])(\.env[^/\\]*|\.mcp\.json|auth\.json|credentials[^/\\]*|secrets[^/\\]*|integrations\.json|projects\.json|web-config\.json|web-state|\.service-state|\.aws|\.azure|\.ssh|\.gnupg|node_modules)([/\\]|$)|\.(dpapi|pem|key|pfx)$'){throw 'Secret/runtime files cannot be sent to the model'}
}
try {
    $result=switch($r.action){
        'snapshot' {
            $registry=Get-Content -LiteralPath $RegistryPath -Raw|ConvertFrom-Json
            $projects=@(foreach($entry in $registry.projects){if($entry.enabled){
                try{$p=& "$hub/Resolve-HubProject.ps1" -ProjectId $entry.id -RegistryPath $RegistryPath
                    @{id=$p.id;root=$p.root;kind=$p.kind;agents=$p.agents;board=(Read-Document $p.root 'WORK-BOARD.md');rules=(Read-Document $p.root 'AGENTS.md');readme=(Read-Document $p.root 'README.md')}
                }catch{@{id=$entry.id;error=$_.Exception.Message}}
            }})
            $taskWarnings=@()
            $tasks=@(foreach($file in @(Get-ChildItem "$hub/hub/tasks/*/task.json" -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 100)){
                try{
                    $task=Get-Content -LiteralPath $file.FullName -Raw|ConvertFrom-Json
                    if($task.project.id -isnot [string] -or $task.goal -isnot [string] -or $task.status -isnot [string]){throw 'Invalid task record'}
                    $task
                }catch{$taskWarnings+=@("$($file.Directory.Name): invalid task record excluded; original retained")}
            })
            @{projects=$projects;tasks=$tasks;taskWarnings=$taskWarnings;profiles=(Get-Content "$hub/profiles.json" -Raw|ConvertFrom-Json);services=@('ollama','blender','blockbench','godot');version=(Get-Content "$hub/VERSION" -Raw).Trim()}
        }
        'createProject' { & "$hub/New-ManagedProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath -Kind $r.kind -Goal $r.goal -Template $r.template }
        'task' { & "$hub/New-HubTask.ps1" -ProjectId $r.project -RegistryPath $RegistryPath -Goal $r.message -Agent $r.agent -Mode $r.mode -Domain $r.domain -Complexity $r.complexity -Risk $r.risk }
        'service' {
            if($r.service -notin @('ollama','blender','blockbench','godot')){throw 'Unknown service'}
            if($r.service -eq 'godot'){throw 'Godot requires a verified project binding. Use the project-specific launcher; shared port 9876 must not be reassigned.'}
            & "$hub/Ensure-ProjectService.ps1" -Service $r.service -StartTransport
        }
        'context' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if($r.agent -notin $p.agents){throw 'Agent is not registered for this project'}
            $handoff=''
            if($r.taskId){
                if($r.taskId -notmatch '^\d{8}-\d{6}-[a-f0-9]{8}$'){throw 'Invalid task ID'}
                $taskDir=Join-Path $hub "hub/tasks/$($r.taskId)"
                $task=Get-Content -LiteralPath (Join-Path $taskDir 'task.json') -Raw|ConvertFrom-Json
                if($task.project.id -ne $p.id){throw 'Task belongs to another project'}
                $handoff=Read-Document $taskDir 'handoff.md'
            }
            @{root=$p.root;project=$p;metadata=(Read-Document $p.root 'project.json');rules=(Read-Document $p.root 'AGENTS.md');hubRules=(Read-Document $hub 'AGENTS.md');board=(Read-Document $p.root 'WORK-BOARD.md');contract=(Read-Document $hub 'docs/TEAM-CONTRACT.vi.md');handoff=$handoff}
        }
        'files' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            $pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue($p.root);$items=@()
            while($pending.Count -and $items.Count -lt 500){
                $folder=$pending.Dequeue()
                foreach($entry in Get-ChildItem -LiteralPath $folder -Force){
                    if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
                    if($entry.PSIsContainer){if($entry.Name -notin @('.git','.codex','.agents','.ai-local','node_modules','local-runs','test-results','dist','.service-state','web-state','tasks')){$pending.Enqueue($entry.FullName)};continue}
                    $relative=[IO.Path]::GetRelativePath($p.root,$entry.FullName).Replace('\','/')
                    try{Assert-PromptFile $relative}catch{continue}
                    if($entry.Extension -in @('.js','.mjs','.cjs','.ts','.tsx','.jsx','.html','.css','.md','.json','.ps1','.psm1','.gd','.py','.yml','.yaml','.txt')){$items+=@{path=$relative;bytes=$entry.Length}}
                    if($items.Count -ge 500){break}
                }
            }
            @{files=$items;limit=500;limited=($pending.Count -gt 0)}
        }
        'document' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            Assert-PromptFile $r.file
            if([IO.Path]::GetExtension($r.file) -notin @('.js','.mjs','.cjs','.ts','.tsx','.jsx','.html','.css','.md','.json','.ps1','.psm1','.gd','.py','.yml','.yaml','.txt')){throw 'Unsupported source document'}
            $file=Resolve-ProjectFile -ProjectPath $p.root -RelativePath $r.file
            if((Get-Item -LiteralPath $file).Length -gt 131072){throw 'Source document exceeds 128 KiB'}
            @{path=$r.file;content=[IO.File]::ReadAllText($file);sha256=(Get-FileHash -LiteralPath $file).Hash}
        }
        'board' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if($r.content -isnot [string] -or $r.content.Length -gt 12000 -or -not $r.content.Trim()){throw 'Invalid work board'}
            $file=Resolve-ProjectFile -ProjectPath $p.root -RelativePath 'WORK-BOARD.md'
            if((Get-ProjectFileHash $file) -ne $r.sha256){throw 'Board changed; reload before saving'}
            [IO.File]::WriteAllText($file,$r.content,[Text.UTF8Encoding]::new($false))
            @{saved=$true;sha256=(Get-FileHash -LiteralPath $file).Hash;author='user-via-hub';evidence='User-authored board update; not independent test verification'}
        }
        'local' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if('local' -notin $p.agents){throw 'Local AI is not registered'}
            & "$hub/Ask-Local.ps1" -Task web -Prompt $r.prompt -MaxTokens 1024 -TimeoutSec 300 -DisableThinking -PassThru
        }
        'stage' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if('local' -notin $p.agents){throw 'Local AI is not registered'}
            foreach($file in $r.files){
                Assert-PromptFile $file
            }
            $route=& "$hub/Select-TaskRoute.ps1" -Domain $r.domain -Complexity $r.complexity -Risk $r.risk
            if($r.risk -ne 'low' -or $r.complexity -eq 'high'){throw 'High risk/complexity needs a scoped reviewed task before local implementation.'}
            $task=if($r.domain -eq 'general'){'code'}else{$r.domain}
            $brief="$($r.message)`nProject rules (reference):`n$(Read-Document $p.root 'AGENTS.md')"
            $arguments=@{Task=$task;ProjectPath=$p.root;Files=@($r.files);Prompt=$brief;DisableThinking=$true}
            if($r.reviewReport){
                $report=& "$hub/New-ReviewReport.ps1" -TaskId $r.taskId -Finding 'Review or tests requested repair' -Expected $r.acceptance -Actual 'Previous proposal/checks did not meet acceptance; details in requested_change' -RequestedChange $r.reviewReport
                $reportPath=Join-Path $hub ('hub/web-state/repair-'+[guid]::NewGuid().ToString('N')+'.json')
                $report|ConvertTo-Json -Depth 6|Set-Content $reportPath
                $arguments.ReviewReport=$reportPath
            }
            $proposalPath=& "$hub/Invoke-LocalCoder.ps1" @arguments
            $proposal=Get-Content -LiteralPath $proposalPath -Raw|ConvertFrom-Json
            $full=@(foreach($change in $proposal.changes){@{path=$change.path;content=(Get-Content -LiteralPath (Join-Path (Split-Path $proposalPath) $change.staged_file) -Raw)}})
            @{status='awaiting_codex_review';proposal=$proposalPath;sha256=(Get-FileHash -LiteralPath $proposalPath).Hash;changes=$full;route=$route;tests='not_run';applied=$false}
        }
        'proposal' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if('codex' -notin $p.agents){throw 'Codex is not registered'}
            Get-VerifiedProposal $p $r.proposal $r.sha256
        }
        'applicationState' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if('codex' -notin $p.agents){throw 'Codex is not registered'}
            Get-VerifiedProposal $p $r.proposal $r.sha256 $false $true
        }
        'appliedProposal' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            $null=Get-VerifiedProposal $p $r.proposal $r.sha256 $true
            @{matched=$true;sha256=$r.sha256}
        }
        'sources' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if('codex' -notin $p.agents){throw 'Codex is not registered'}
            $sources=@(foreach($file in $r.files){Assert-PromptFile $file;$full=Resolve-ProjectFile -ProjectPath $p.root -RelativePath $file
                if((Test-Path -LiteralPath $full) -and (Get-Item -LiteralPath $full).Length -gt 65536){throw 'Source too large; split task'}
                @{path=$file;hash=(Get-ProjectFileHash $full);content=if(Test-Path -LiteralPath $full){[IO.File]::ReadAllText($full)}else{''}}
            })
            @{root=$p.root;sources=$sources}
        }
        'cloudStage' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if('codex' -notin $p.agents){throw 'Codex is not registered'}
            if(-not @($r.code.changes).Count -or @($r.code.changes).Count -gt 5){throw 'Invalid change count'}
            $allowed=@{};foreach($source in $r.sources){Assert-PromptFile $source.path;$allowed[$source.path]=$source}
            $id='codex-'+[guid]::NewGuid().ToString('N');$dir=Join-Path $hub "local-runs/$id"
            New-Item -ItemType Directory -Path "$dir/changes" -Force|Out-Null
            $changes=@();$seen=@{};$fullChanges=@();$index=0
            foreach($change in $r.code.changes){
                if(-not $allowed.ContainsKey($change.path) -or $seen.ContainsKey($change.path) -or $change.content -isnot [string]){throw 'Codex returned invalid or out-of-scope changes'}
                $seen[$change.path]=$true
                $target=Resolve-ProjectFile -ProjectPath $p.root -RelativePath $change.path
                if((Get-ProjectFileHash $target) -ne $allowed[$change.path].hash){throw 'Source changed during generation'}
                $stage="changes/$index.txt";$file=Join-Path $dir $stage
                [IO.File]::WriteAllText($file,$change.content,[Text.UTF8Encoding]::new($false))
                Assert-ProjectSyntax -FilePath $file -TargetPath $change.path
                $changes+=@{path=$change.path;original_hash=$allowed[$change.path].hash;proposed_hash=(Get-FileHash $file).Hash;staged_file=$stage}
                $fullChanges+=@{path=$change.path;content=$change.content};$index++
            }
            $proposal=Join-Path $dir 'proposal.json'
            @{id=$id;project=$p.root;role='codex-implementer-fallback';status='awaiting_codex_review';summary=$r.code.summary;changes=$changes}|ConvertTo-Json -Depth 9|Set-Content $proposal
            @{status='awaiting_codex_review';proposal=$proposal;sha256=(Get-FileHash $proposal).Hash;changes=$fullChanges;tests='not_run';applied=$false}
        }
        'apply' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            if('codex' -notin $p.agents){throw 'Codex is not registered'}
            if($p.root -eq $hub){throw 'Self-update of the running HUB requires Codex desktop review/integration.'}
            $null=Get-VerifiedProposal $p $r.proposal $r.sha256
            & "$hub/Apply-LocalProposal.ps1" -ProjectPath $p.root -ProposalPath $r.proposal -ReviewedSha256 $r.sha256|Out-Null
            Get-Content -LiteralPath (Join-Path (Split-Path $r.proposal) 'apply-receipt.json') -Raw|ConvertFrom-Json
        }
        'checks' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            $checks=@()
            foreach($file in $r.files){
                $full=Resolve-ProjectFile -ProjectPath $p.root -RelativePath $file
                if(-not(Test-Path -LiteralPath $full -PathType Leaf)){throw 'Check target missing'}
                $output='';$passed=$true
                if([IO.Path]::GetExtension($file) -in @('.js','.mjs','.cjs')){
                    $output=(& node --check $full 2>&1|Out-String);$passed=$LASTEXITCODE -eq 0
                }elseif([IO.Path]::GetExtension($file) -in @('.ps1','.psm1','.json')){
                    try{Assert-ProjectSyntax -FilePath $full -TargetPath $file}catch{$passed=$false;$output=$_.Exception.Message}
                }else{
                    $checks+=@{path=$file;name="Content fingerprint (not a syntax/test check): $file";passed=$true;output='Runtime/Chrome verification still required';sha256=(Get-FileHash -LiteralPath $full).Hash};continue
                }
                $checks+=@{path=$file;name="Syntax: $file";passed=$passed;output=$output.Trim();sha256=(Get-FileHash -LiteralPath $full).Hash}
            }
            foreach($file in $r.testFiles){
                if($file -notmatch '\.test\.(mjs|cjs|js)$'){throw 'Only explicitly selected *.test.js/mjs/cjs Node tests are supported'}
                $full=Resolve-ProjectFile -ProjectPath $p.root -RelativePath $file
                if(-not(Test-Path -LiteralPath $full -PathType Leaf)){throw 'Selected test file missing'}
                Push-Location $p.root
                try{$output=(& node --test $full 2>&1|Out-String);$passed=$LASTEXITCODE -eq 0}finally{Pop-Location}
                $checks+=@{path=$file;name="Node test: $file";passed=$passed;output=$output.Trim();sha256=(Get-FileHash -LiteralPath $full).Hash}
            }
            if(-not $checks.Count){throw 'No supported checks selected; define acceptance/checks before apply.'}
            @{passed=(@($checks|Where-Object{-not $_.passed}).Count -eq 0);checks=$checks;runtime_verified=$false;test_execution=(@($r.testFiles).Count -gt 0)}
        }
        'verifyHashes' {
            $p=& "$hub/Resolve-HubProject.ps1" -ProjectId $r.project -RegistryPath $RegistryPath
            foreach($item in $r.hashes){
                $file=Resolve-ProjectFile -ProjectPath $p.root -RelativePath $item.path
                if((Get-ProjectFileHash $file) -ne $item.sha256){throw 'Source changed since checks. Run checks and runtime verification again.'}
            }
            @{matched=$true}
        }
        default {throw 'Unsupported bridge action'}
    }
    '@@HUB@@'+(@{ok=$true;data=$result}|ConvertTo-Json -Depth 24 -Compress)
}catch{
    '@@HUB@@'+(@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress)
    # Keep protocol errors parseable; the Node boundary converts ok=false to a failed job.
}
