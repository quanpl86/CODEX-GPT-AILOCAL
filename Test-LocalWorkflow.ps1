# Offline contract tests: no model download, GPU allocation, or real HTTP requests.
$ErrorActionPreference = 'Stop'
$global:localWorkflowRequests = @()
$global:localWorkflowFailChat = $false
$global:localWorkflowEmptyChat = $false
$global:localWorkflowLoaded = $false
function Invoke-RestMethod {
    param($Uri, $Method, $ContentType, $Body, $TimeoutSec)
    $global:localWorkflowRequests += [PSCustomObject]@{uri=$Uri;body=$Body}
    if ($Uri -like '*/api/ps') { return @{models=if($global:localWorkflowLoaded){@(@{name='other-client-model'})}else{@()}} }
    if ($Uri -like '*/api/chat') {
        if ($global:localWorkflowFailChat) { throw 'Simulated Ollama failure' }
        return [PSCustomObject]@{
            model='local-web'; done=$true; done_reason='stop'
            message=@{content=if($global:localWorkflowEmptyChat){''}else{'Đề xuất: kiểm tra lỗi.'};thinking='Do not persist this field'}
            total_duration=1000000000; eval_count=8; eval_duration=500000000
        }
    }
    throw "Unexpected endpoint: $Uri"
}
function Assert-True($Condition, $Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-True ($null -ne $caught -and $caught -match $Pattern) "Expected error: $Pattern, got: $caught"
}
$testRoot = Join-Path $PSScriptRoot ('test-results\workflow-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
foreach ($file in @('Ask-Local.ps1','Invoke-LocalAdvice.ps1','profiles.json')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $testRoot
}
# Isolate resource probes from these offline HTTP contract tests.
Set-Content (Join-Path $testRoot 'Assert-LocalCapacity.ps1') 'param($Task)' -Encoding utf8
Set-Content (Join-Path $testRoot 'Ensure-Ollama.ps1') '# Startup isolated from offline contract tests' -Encoding utf8
$launcher = Join-Path $testRoot 'Ask-Local.ps1'
$wrapper = Join-Path $testRoot 'Invoke-LocalAdvice.ps1'
$text = & $launcher -Task web -Prompt 'Kiểm tra giao diện' -MaxTokens 64
Assert-True ($text -eq 'Đề xuất: kiểm tra lỗi.') 'Text output preserved'
$chat = $global:localWorkflowRequests | Where-Object uri -Like '*/api/chat' | Select-Object -Last 1
$body = [Text.Encoding]::UTF8.GetString($chat.body) | ConvertFrom-Json
Assert-True ($body.messages[0].content -eq 'Kiểm tra giao diện') 'UTF-8 prompt preserved'
Assert-True ($body.think -eq $false -and $body.options.num_ctx -eq 8192) 'Web runtime settings'
$answer = & $launcher -Task brain -Prompt 'Short check' -DisableThinking -PassThru -MaxTokens 64
Assert-True ($answer.done -and $answer.message.content) 'Structured response preserved'
$chat = $global:localWorkflowRequests | Where-Object uri -Like '*/api/chat' | Select-Object -Last 1
$body = [Text.Encoding]::UTF8.GetString($chat.body) | ConvertFrom-Json
Assert-True ($body.think -eq $false -and $body.model -eq 'local-brain') 'Explicit thinking override and routing'
$before = $global:localWorkflowRequests.Count
Assert-Throws { & $launcher -Prompt ('x' * 12001) } 'exceeds 12000'
Assert-True ($global:localWorkflowRequests.Count -eq $before) 'Oversized requests rejected before HTTP'
$global:localWorkflowLoaded = $true
Assert-Throws { & $launcher -Prompt 'Do not stop another client' } 'already has a model loaded'
Assert-True (@($global:localWorkflowRequests | Where-Object uri -Like '*/api/generate').Count -eq 0) 'No automatic unload requests'
$global:localWorkflowLoaded = $false
$lock = [IO.File]::Open((Join-Path $testRoot '.local-ai.request.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try { Assert-Throws { & $launcher -Prompt 'Concurrent call' } 'Another local request' } finally { $lock.Dispose() }
$global:localWorkflowFailChat = $true
Assert-Throws { & $launcher -Prompt 'Fail' } 'Simulated Ollama failure'
$global:localWorkflowFailChat = $false
$global:localWorkflowEmptyChat = $true
Assert-Throws { & $launcher -Prompt 'Empty' } 'no completed answer'
$global:localWorkflowEmptyChat = $false
# Also verifies that locks from failed requests have been released.
$path = & $wrapper -Task web -Prompt 'Offline wrapper test' -MaxTokens 64
$recordPath = Join-Path (Split-Path $path) 'result.json'
$record = Get-Content $recordPath -Raw | ConvertFrom-Json
Assert-True ($record.status -eq 'completed' -and $record.answer) 'Successful run recorded'
Assert-True ((Get-Content $recordPath -Raw) -notmatch 'Do not persist this field') 'Thinking field omitted'
Assert-True ((Get-Content $recordPath -Raw) -notmatch 'Offline wrapper test') 'Prompt omitted by default'
Assert-True ((Get-Content $path -Raw) -notmatch 'Offline wrapper test') 'Prompt omitted in Markdown too'
Assert-True (Test-Path -LiteralPath $path) 'Advice artifact exists'
$global:localWorkflowFailChat = $true
$beforePaths = @(Get-ChildItem "$testRoot\local-runs" -Directory | Select-Object -ExpandProperty Name)
Assert-Throws { & $wrapper -Task web -Prompt 'Offline failure record test' -MaxTokens 64 } 'Simulated Ollama failure'
$failedDir = Get-ChildItem "$testRoot\local-runs" -Directory | Where-Object Name -NotIn $beforePaths
$failed = Get-Content (Join-Path $failedDir.FullName 'result.json') -Raw | ConvertFrom-Json
Assert-True ($failed.status -eq 'failed' -and $failed.error) 'Failure recorded'
Write-Output 'PASS: routing, UTF-8, response contracts, input guard, concurrency lock, no external unload, failure recovery, prompt privacy, run artifacts.'
