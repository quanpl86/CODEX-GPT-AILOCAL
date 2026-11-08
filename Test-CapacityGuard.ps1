$ErrorActionPreference='Stop'
$global:capacityMockMode='running'
function Invoke-RestMethod {
    param($Uri,$TimeoutSec)
    switch($global:capacityMockMode){
        'running' { return @{queue_running=@(@{id='fake'});queue_pending=@()} }
        'pending' { return @{queue_running=@();queue_pending=@(@{id='fake'})} }
        default { throw 'Mock HTTP failure' }
    }
}
$guard=Join-Path $PSScriptRoot 'Assert-LocalCapacity.ps1'
foreach($mode in @('running','pending')) {
    $global:capacityMockMode=$mode
    $caught=$false
    try { & $guard -Task web } catch { $caught=$_.Exception.Message -match 'active or queued' }
    if(-not $caught){throw "Guard failed for $mode queue"}
}
# Bind a test-only port: an open port with a failed queue API must fail closed.
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start()
try {
    $global:capacityMockMode='error'
    $port=$listener.LocalEndpoint.Port
    $caught=$false
    try { & $guard -Task web -ComfyPort $port } catch { $caught=$_.Exception.Message -match 'cannot be verified' }
    if(-not $caught){throw 'Guard failed to block unknown reachable server state'}
} finally { $listener.Stop() }
try { & $guard -Task web -ComfyPort $port }
catch { if($_.Exception.Message -notmatch 'Not enough free RAM'){throw "Closed test port was not distinguished from unknown ComfyUI state: $($_.Exception.Message)"} }
Write-Output 'PASS: running queue blocked, pending queue blocked, reachable server with unknown status blocked. No GPU work.'
