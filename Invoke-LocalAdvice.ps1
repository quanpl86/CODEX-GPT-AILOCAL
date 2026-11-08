param(
    [Parameter(Mandatory=$true)][ValidateSet('web','game','brain','learning','review','code')][string]$Task,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Prompt,
    [string[]]$ContextFile,
    [ValidateRange(64,4096)][int]$MaxTokens = 1024,
    [ValidateRange(10,1800)][int]$TimeoutSec = 300,
    [switch]$DisableThinking,
    [switch]$SavePrompt
)
$ErrorActionPreference = 'Stop'
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$runDir = Join-Path $PSScriptRoot "local-runs\$runId"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$profiles = Get-Content "$PSScriptRoot\profiles.json" -Raw | ConvertFrom-Json
$record = [ordered]@{
    id=$runId; started_at=[DateTimeOffset]::Now.ToString('o'); task=$Task
    model=$profiles.$Task.model; prompt_saved=[bool]$SavePrompt; prompt_characters=$Prompt.Length; context_files=@($ContextFile)
    thinking=([bool]$profiles.$Task.think -and -not $DisableThinking)
    status='running'; max_tokens=$MaxTokens; timeout_seconds=$TimeoutSec
}
if ($SavePrompt) { $record.prompt = $Prompt }
$recordPath = Join-Path $runDir 'result.json'
$record | ConvertTo-Json -Depth 8 | Set-Content $recordPath -Encoding utf8
try {
    $arguments = @{Task=$Task; Prompt=$Prompt; MaxTokens=$MaxTokens; TimeoutSec=$TimeoutSec; PassThru=$true; DisableThinking=$DisableThinking}
    if ($ContextFile) { $arguments.ContextFile = $ContextFile }
    $answer = & "$PSScriptRoot\Ask-Local.ps1" @arguments
    $record.status = if ($answer.done_reason -eq 'length') { 'truncated' } else { 'completed' }
    $record.answer = $answer.message.content
    $record.done_reason = $answer.done_reason
    $record.total_seconds = [math]::Round($answer.total_duration / 1e9, 2)
    $record.output_tokens = $answer.eval_count
    # Store the final answer and metrics, not the model's internal thinking field.
    $requestText = if ($SavePrompt) { $Prompt } else { 'Prompt omitted by default. See result.json for task, model and metrics.' }
    $report = @"
# Local advice: $Task

Model: $($record.model) | Status: $($record.status)

This is an unverified model proposal. Codex must review it before applying changes.

## Request

$requestText

## Answer

$($record.answer)
"@
    $reportPath = Join-Path $runDir 'advice.md'
    $report | Set-Content $reportPath -Encoding utf8
    Write-Output $reportPath
} catch {
    $record.status = 'failed'
    $record.error = $_.Exception.Message
    throw
} finally {
    $record.finished_at = [DateTimeOffset]::Now.ToString('o')
    $record | ConvertTo-Json -Depth 8 | Set-Content $recordPath -Encoding utf8
}
