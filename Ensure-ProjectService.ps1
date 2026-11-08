[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][ValidateSet('ollama','blender','blockbench','godot')][string]$Service,
    [string]$ExpectedGodotProject,
    [ValidateRange(1,120)][int]$TimeoutSec=30,
    [string]$ConfigPath=(Join-Path $PSScriptRoot 'integrations.json'),
    [switch]$StartTransport
)
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConfigPath)){throw 'Missing integrations.json. Configure verified executable paths first.'}
$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
$entry=$config.services.$Service
if(-not $entry){throw "No startup configuration for $Service"}
$stateDir=Join-Path $PSScriptRoot '.service-state'
$statePath=Join-Path $stateDir ($Service+'.json')
$startupLock=$null
try {
if(-not $WhatIfPreference){
    New-Item -ItemType Directory -Path $stateDir -Force|Out-Null
    try{$startupLock=[IO.File]::Open((Join-Path $stateDir 'startup.lock'),'OpenOrCreate','ReadWrite','None')}
    catch{throw 'Another service startup is in progress; wait for it to finish.'}
}
function Test-ServiceReady {
    if($Service -eq 'ollama'){
        try{$r=Invoke-RestMethod 'http://127.0.0.1:11434/api/version' -TimeoutSec 2;return -not [string]::IsNullOrWhiteSpace($r.version)}catch{return $false}
    }
    if($Service -eq 'godot' -and $entry.transportMode -ne 'stdio'){
        try{$null=Invoke-RestMethod "http://127.0.0.1:$($entry.port)/health" -TimeoutSec 2;return $true}catch{return $false}
    }
    $client=[Net.Sockets.TcpClient]::new()
    try{$task=$client.ConnectAsync('127.0.0.1',[int]$entry.port);return ($task.Wait(500) -and $client.Connected)}catch{return $false}finally{$client.Dispose()}
}
function Get-ServiceOwner {
    param([int]$Port)
    # netstat supplies a fresh listener snapshot; stale CIM TCP snapshots on this
    # Windows host have reported live listeners as Closed.
    $line=& netstat.exe -ano -p tcp|Where-Object{$_ -match ('^\s*TCP\s+(?:127\.0\.0\.1|0\.0\.0\.0):'+ $Port +'\s+0\.0\.0\.0:0\s+\S+\s+([1-9]\d*)\s*$')}|Select-Object -First 1
    if($line){
        $ownerId=[int](($line.Trim() -split '\s+')[-1])
        $process=Get-Process -Id $ownerId -ErrorAction Stop
        return [PSCustomObject]@{ExecutablePath=$process.Path;ProcessId=$ownerId}
    }
    return $null
}
if($Service -eq 'godot'){
    if(-not $ExpectedGodotProject){throw 'Godot requires -ExpectedGodotProject; no default project is selected implicitly.'}
    $godotConfig=Get-Content -LiteralPath $entry.projectConfig -Raw|ConvertFrom-Json
    $expected=[IO.Path]::GetFullPath($ExpectedGodotProject).TrimEnd('\','/')
    $actual=[IO.Path]::GetFullPath($godotConfig.project_path).TrimEnd('\','/')
    if($expected -ne $actual -or -not(Test-Path -LiteralPath (Join-Path $expected 'project.godot'))){throw 'Godot binding differs or project.godot is missing; nothing was launched or rebound.'}
    if([IO.Path]::GetFullPath($entry.executable) -ne [IO.Path]::GetFullPath($godotConfig.godot_path)){throw 'Godot executable differs from saved project config'}
    # Build project arguments from the verified binding, never a stale argument list.
    $entry.arguments=@('--editor','--path',('"'+$expected+'"'))
}
$ready=Test-ServiceReady
if($ready -and $Service -in @('blender','blockbench','godot')){
    $owner=Get-ServiceOwner -Port $entry.port
    if(-not $owner -and (Test-Path -LiteralPath $statePath)){
        $receipt=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
        $tracked=Get-Process -Id $receipt.pid -ErrorAction SilentlyContinue
        if($tracked -and $tracked.StartTime.ToUniversalTime().Ticks -eq $receipt.started_ticks -and $tracked.Path -eq $entry.executable){
            $owner=[PSCustomObject]@{ExecutablePath=$tracked.Path;ProcessId=$tracked.Id}
        }
    }
    if(-not $owner -or [IO.Path]::GetFullPath($owner.ExecutablePath) -ne [IO.Path]::GetFullPath($entry.executable)){throw 'Ready port belongs to an unknown/different application; verify ownership before reuse.'}
    if($Service -eq 'godot'){
        $info=Get-CimInstance Win32_Process -Filter "ProcessId=$($owner.ProcessId)"
        if(-not $info.CommandLine.Contains($expected)){throw 'Godot bridge belongs to a different/unknown project'}
    }
}
if(-not $ready){
    if(-not(Test-Path -LiteralPath $entry.executable -PathType Leaf)){throw "Executable missing: $($entry.executable)"}
    if($Service -in @('blender','godot')){
        $owner=Get-ServiceOwner -Port 9876
        if($owner){throw 'Port 9876 already occupied. Blender and Godot cannot start together with current defaults. No process was stopped.'}
    }
    $processName=[IO.Path]::GetFileNameWithoutExtension($entry.executable)
    $existing=@(Get-Process -Name $processName -ErrorAction SilentlyContinue)
    if($Service -eq 'godot' -and $existing.Count -gt 0){
        $matching=@(foreach($p in $existing){$info=Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)";if($info.CommandLine.Contains($expected)){$info}})
        if($matching.Count -eq 0){throw 'A different Godot project may be open. No project was switched.'}
    }
    if($existing.Count -eq 0){
        if($PSCmdlet.ShouldProcess($entry.executable,"Start $Service on demand")){
            $launch=@{FilePath=$entry.executable;WindowStyle='Hidden';PassThru=$true}
            if($entry.arguments){$launch.ArgumentList=@($entry.arguments)}
            $started=Start-Process @launch
            New-Item -ItemType Directory -Path $stateDir -Force|Out-Null
            @{pid=$started.Id;started_ticks=$started.StartTime.ToUniversalTime().Ticks}|ConvertTo-Json|Set-Content $statePath -Encoding utf8
        }else{return [PSCustomObject]@{service=$Service;status='planned';local_ready=$false;remote_verified=$false}}
    }
    if($Service -eq 'godot' -and $entry.transportMode -ne 'stdio'){
        if($godotConfig.package -notmatch '^@yanhuifair/godot-mcp@[0-9]+\.[0-9]+\.[0-9]+$'){throw 'Godot package must be an explicit verified version'}
        $node=(Get-Command node.exe -ErrorAction Stop).Source
        $npmRoot=Split-Path (Get-Command npx.cmd -ErrorAction Stop).Source
        $npxCli=Join-Path $npmRoot 'node_modules/npm/bin/npx-cli.js'
        if(-not(Test-Path $npxCli)){throw 'Cannot resolve installed npx CLI'}
        if($PSCmdlet.ShouldProcess($expected,'Start pinned Godot MCP HTTP service')){
            $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$node;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
            foreach($arg in @($npxCli,'--yes',$godotConfig.package,'-p',$expected,'-t','streamable-http','--host','127.0.0.1','--port',[string]$entry.port)){$psi.ArgumentList.Add($arg)}
            $null=[Diagnostics.Process]::Start($psi)
        }
    }
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSec)
    do{
        $ready=Test-ServiceReady
        if($ready){break}
        Start-Sleep -Milliseconds 500
    }while([DateTime]::UtcNow -lt $deadline)
}
if(-not $ready){
    $action=switch($Service){
        'blender' {'Enable BlenderMCP addon and its Auto-Start Server setting, or click Start MCP Server in Blender.'}
        'blockbench' {'Open the MCP Copilot panel and click Start. This installed plugin does not auto-start its listener.'}
        'godot' {'The editor may be open, but HTTP MCP server is not ready. Run the verified Godot launcher for the expected project.'}
        default {'Check Ollama startup and local networking permissions.'}
    }
    return [PSCustomObject]@{service=$Service;status='needs_app_setup';local_ready=$false;remote_verified=$false;action=$action}
}
$transportStatus='not_requested'
if($StartTransport -and $Service -ne 'ollama'){
    $profile=[string]$config.apps.$Service.profile
    $runningTransport=@(Get-CimInstance Win32_Process -Filter "Name='tunnel-client.exe'"|Where-Object{$_.CommandLine -match ('--profile\s+"?'+[regex]::Escape($profile)+'(?:"|\s|$)')})
    if($runningTransport.Count){$transportStatus='already_running_unverified'}
    elseif($PSCmdlet.ShouldProcess($profile,'Start MCP transport with existing protected credentials')){
        $transportStatus= & "$PSScriptRoot\Start-SavedMcpTransport.ps1" -App $Service -ConfigPath $ConfigPath
    }
}
[PSCustomObject]@{service=$Service;status='local_ready';local_ready=$true;remote_verified=$false;transport=$transportStatus;action='Use a read-only MCP status call to verify the active project before modifying data.'}
} finally { if($startupLock){$startupLock.Dispose()} }
