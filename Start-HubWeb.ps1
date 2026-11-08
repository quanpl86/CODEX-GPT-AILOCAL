[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port=8765,[switch]$NoBrowser)
$ErrorActionPreference='Stop'
$node=(Get-Command node -ErrorAction Stop).Source
$env:HUB_PORT=[string]$Port
$webConfig=Join-Path $PSScriptRoot 'hub/web-config.json'
if(Test-Path -LiteralPath $webConfig){
    $config=Get-Content -LiteralPath $webConfig -Raw|ConvertFrom-Json
    if(-not $env:HUB_CODEX_MODEL -and $config.codexModel){$env:HUB_CODEX_MODEL=[string]$config.codexModel}
}
$codex=Join-Path $env:APPDATA 'npm/node_modules/@openai/codex/bin/codex.js'
if(-not $env:HUB_CODEX_JS -and (Test-Path -LiteralPath $codex)){$env:HUB_CODEX_JS=$codex}
$agy=Get-Command agy -ErrorAction SilentlyContinue
if(-not $env:HUB_AGY_EXE -and $agy){$env:HUB_AGY_EXE=$agy.Source}
$uri="http://127.0.0.1:$Port"
try{
    $existing=Invoke-RestMethod "$uri/api/state" -TimeoutSec 2
    if(-not $existing.adapters -or -not $existing.csrf -or $existing.hubRoot -ne $PSScriptRoot){throw 'Port occupied by another service or HUB checkout'}
}catch{
    # Verify the port is free rather than starting beside an unrelated listener.
    $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
    try{$probe.Start()}catch{throw "Port $Port is occupied; inspect it before starting HUB."}finally{$probe.Stop()}
    $state=Join-Path $PSScriptRoot 'hub/web-state'
    New-Item -ItemType Directory -Path $state -Force|Out-Null
    Start-Process -FilePath $node -ArgumentList @('"'+(Join-Path $PSScriptRoot 'web/server.mjs')+'"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $state 'server.log') -RedirectStandardError (Join-Path $state 'server-error.log')|Out-Null
    $ready=$false
    for($i=0;$i -lt 20;$i++){
        try{$null=Invoke-RestMethod "$uri/api/state" -TimeoutSec 2;$ready=$true;break}catch{Start-Sleep -Milliseconds 250}
    }
    if(-not $ready){throw 'HUB did not become ready; inspect hub/web-state/server-error.log'}
}
if(-not $NoBrowser){
    $chrome=@("$env:ProgramFiles/Google/Chrome/Application/chrome.exe","${env:ProgramFiles(x86)}/Google/Chrome/Application/chrome.exe")|Where-Object{Test-Path -LiteralPath $_}|Select-Object -First 1
    if($chrome){Start-Process -FilePath $chrome -ArgumentList $uri}else{Start-Process $uri}
}
Write-Output "HUB ready: $uri"
