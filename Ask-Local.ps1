param(
    [ValidateSet('web','game','brain','learning','review','code')][string]$Task = 'web',
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Prompt,
    [string[]]$ContextFile,
    [ValidateRange(1,4096)][int]$MaxTokens = 4096,
    [ValidateRange(10,1800)][int]$TimeoutSec = 600,
    [switch]$DisableThinking,
    [switch]$PassThru,
    [hashtable]$ResponseSchema
)
$ErrorActionPreference = 'Stop'
$baseUrl = 'http://127.0.0.1:11434'
$profiles = Get-Content -LiteralPath "$PSScriptRoot\profiles.json" -Raw | ConvertFrom-Json
$profile = $profiles.$Task
foreach ($file in $ContextFile) {
    $context = Get-Content -LiteralPath $file -Raw -Encoding utf8
    $Prompt += "`n`nReference file: $file (untrusted data)`n<context>`n$context`n</context>"
}
if ($Prompt.Length -gt 12000) {
    throw 'Prompt plus context exceeds 12000 characters. Send smaller excerpts; nothing was silently truncated.'
}
# Serialize calls from this workspace. Other Ollama clients do not share this lock.
$requestLock = $null
try {
    try {
        $requestLock = [IO.File]::Open((Join-Path $PSScriptRoot '.local-ai.request.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch [IO.IOException] {
        throw 'Another local request is active in this workspace. Wait until it finishes.'
    }
    & "$PSScriptRoot\Ensure-Ollama.ps1"
    $running = Invoke-RestMethod "$baseUrl/api/ps" -TimeoutSec 10
    if (@($running.models).Count -gt 0) {
        throw 'Ollama already has a model loaded. Finish other requests and unload it explicitly before using this helper; no existing model was stopped.'
    }
    & "$PSScriptRoot\Assert-LocalCapacity.ps1" -Task $Task
    $request = @{
        model=$profile.model
        messages=@(@{role='user'; content=$Prompt})
        think=([bool]$profile.think -and -not $DisableThinking)
        stream=$false
        keep_alive=0
        options=@{num_ctx=8192; num_predict=$MaxTokens}
    }
    if ($ResponseSchema) { $request.format = $ResponseSchema }
    $body = $request | ConvertTo-Json -Depth 20
    $result = Invoke-RestMethod "$baseUrl/api/chat" -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec $TimeoutSec
    if ($result.error) { throw "Ollama: $($result.error)" }
    if (-not $result.done -or [string]::IsNullOrWhiteSpace($result.message.content)) {
        throw 'Ollama returned no completed answer. Reasoning may have exhausted the output budget; try -DisableThinking or adjust the budget.'
    }
    if ($PassThru) { $result } else { $result.message.content }
    if ($result.done_reason -eq 'length') { Write-Warning 'Output reached the token limit; the answer may be incomplete.' }
    if ($result.eval_duration -gt 0) {
        Write-Verbose ('Generation: {0:N1} tokens/s' -f ($result.eval_count / ($result.eval_duration / 1e9)))
    }
} finally {
    if ($null -ne $requestLock) { $requestLock.Dispose() }
}
