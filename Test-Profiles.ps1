param([string[]]$Tasks = @('web','game','brain','learning','review'))
$ErrorActionPreference = 'Stop'
$url = 'http://127.0.0.1:11434'
$profiles = Get-Content "$PSScriptRoot\profiles.json" -Raw | ConvertFrom-Json
$results = @()
if (Test-Path "$PSScriptRoot\smoke-results.json") { $results = @(Get-Content "$PSScriptRoot\smoke-results.json" -Raw | ConvertFrom-Json | Where-Object { $_.task -notin $Tasks }) }
foreach ($entry in $profiles.PSObject.Properties) {
    if ($entry.Name -notin $Tasks) { continue }
    $profile = $entry.Value
    # Disable reasoning only for this short connectivity/inference smoke test.
    $r = & "$PSScriptRoot\Ask-Local.ps1" -Task $entry.Name -Prompt 'Return only the JavaScript expression for adding variables a and b. No explanation.' -DisableThinking -MaxTokens 64 -PassThru
    $results += [PSCustomObject]@{task=$entry.Name;model=$profile.model;done=$r.done;content=$r.message.content;tokens=$r.eval_count;tokens_per_second=if($r.eval_duration -gt 0){[math]::Round($r.eval_count/($r.eval_duration/1e9),2)}else{0};total_seconds=[math]::Round($r.total_duration/1e9,2)}
    $results | ConvertTo-Json -Depth 6 | Set-Content "$PSScriptRoot\smoke-results.json" -Encoding utf8
    if (-not $r.done -or [string]::IsNullOrWhiteSpace($r.message.content)) { throw "No answer: $($profile.model)" }
    Write-Output "$($profile.model): OK"
}
