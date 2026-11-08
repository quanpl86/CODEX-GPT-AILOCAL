[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][ValidateSet('blender','blockbench','godot')][string]$App,
    [string]$ExpectedGodotProject
)
$ErrorActionPreference='Stop'
$configPath=Join-Path $PSScriptRoot 'integrations.json'
if(-not(Test-Path $configPath)){throw 'Create integrations.json from integrations.example.json and verify machine/project paths before starting app tools.'}
$manifest=Get-Content $configPath -Raw|ConvertFrom-Json
$entry=$manifest.apps.$App
if(-not (Test-Path -LiteralPath $entry.launcher)){throw "Launcher missing: $($entry.launcher)"}
if($App -in @('blender','godot')){
    $client=[Net.Sockets.TcpClient]::new()
    try{$attempt=$client.ConnectAsync('127.0.0.1',9876);$open=$attempt.Wait(700)-and $client.Connected}catch{$open=$false}finally{$client.Dispose()}
    if($open){throw 'TCP 9876 is already occupied. Verify its owner before starting Blender/Godot; no process was stopped.'}
}
if($App -eq 'godot'){
    if(-not $ExpectedGodotProject){throw 'Specify -ExpectedGodotProject explicitly. The shared launcher can target another project.'}
    $configPath=Join-Path $env:APPDATA '3D-MCP\godot-mcp.json'
    $config=Get-Content $configPath -Raw|ConvertFrom-Json
    $expected=[IO.Path]::GetFullPath($ExpectedGodotProject).TrimEnd('\','/')
    $actual=[IO.Path]::GetFullPath($config.project_path).TrimEnd('\','/')
    if($expected -ne $actual){throw "Shared Godot launcher targets a different project: $actual. Configure the intended project first; no binding was changed."}
    if(-not (Test-Path -LiteralPath (Join-Path $expected 'project.godot'))){throw 'Expected project.godot is missing'}
}
if($PSCmdlet.ShouldProcess($entry.launcher,'Run existing interactive app MCP launcher')){
    Write-Host 'Launcher may ask you to open the app/addon or enter a credential locally. Never paste keys into chat.'
    & $entry.launcher
    if($LASTEXITCODE -ne 0){throw "MCP launcher exited with code $LASTEXITCODE"}
}
