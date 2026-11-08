$ErrorActionPreference='Stop'
try{
    $version=Invoke-RestMethod 'http://127.0.0.1:11434/api/version' -TimeoutSec 2
    if($version.version){return}
}catch{
    if($_.Exception.GetBaseException() -is [System.UnauthorizedAccessException]){throw}
}
$status=& "$PSScriptRoot\Ensure-ProjectService.ps1" -Service ollama
if(-not $status.local_ready){throw 'Ollama did not become ready. Check local startup status before retrying.'}
