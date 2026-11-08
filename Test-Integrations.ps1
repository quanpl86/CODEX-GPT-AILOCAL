$ErrorActionPreference = 'Stop'
$configPath=Join-Path $PSScriptRoot 'integrations.json'
if(-not(Test-Path $configPath)){$configPath=Join-Path $PSScriptRoot 'integrations.example.json'}
$manifest = Get-Content $configPath -Raw | ConvertFrom-Json
$apps = @()
foreach ($entry in $manifest.apps.PSObject.Properties) {
    $ports = @()
    foreach ($port in $entry.Value.ports) {
        $client = [Net.Sockets.TcpClient]::new()
        try { $attempt=$client.ConnectAsync('127.0.0.1',$port); $open=$attempt.Wait(700) -and $client.Connected }
        catch { $open=$false } finally { $client.Dispose() }
        $ports += @{port=$port;listening=$open}
    }
    $apps += @{app=$entry.Name;launcher_exists=(Test-Path -LiteralPath $entry.Value.launcher);ports=$ports;tool_call_verified=$false}
}
$ollama = try { Invoke-RestMethod 'http://127.0.0.1:11434/api/ps' -TimeoutSec 3 } catch { $null }
$queue = try { Invoke-RestMethod 'http://127.0.0.1:8188/queue' -TimeoutSec 3 } catch { $null }
$freeRAM = try { [math]::Round((Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).FreePhysicalMemory/1MB,2) } catch { $null }
$status = [ordered]@{
    checked_at=[DateTimeOffset]::Now.ToString('o');apps=$apps
    ollama_reachable=($null -ne $ollama);loaded_models=@($ollama.models | ForEach-Object {$_.name})
    comfyui_reachable=($null -ne $queue)
    comfyui_running=if($null -ne $queue){@($queue.queue_running).Count}else{$null}
    comfyui_pending=if($null -ne $queue){@($queue.queue_pending).Count}else{$null}
    free_ram_gib=$freeRAM
    port_conflict=$manifest.portConflict
    note='Read-only probes. Listening ports do not establish MCP authentication or correct project binding.'
}
$status | ConvertTo-Json -Depth 8 | Set-Content "$PSScriptRoot\integration-status.json" -Encoding utf8
$status | ConvertTo-Json -Depth 8
