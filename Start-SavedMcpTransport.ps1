param([Parameter(Mandatory=$true)][ValidateSet('blender','blockbench','godot')][string]$App,[Parameter(Mandatory=$true)][string]$ConfigPath)
$ErrorActionPreference='Stop'
$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
$transport=$config.transport
$profile=[string]$config.apps.$App.profile
if($profile -notmatch '^[a-z0-9-]+$'){throw 'Invalid transport profile'}
if(-not(Test-Path -LiteralPath $transport.executable)){throw 'Transport executable missing'}
$keyPath=if($App -eq 'blender'){$transport.blenderKeyStore}else{$transport.sharedKeyStore}
if(-not(Test-Path -LiteralPath $keyPath)){return [PSCustomObject]@{status='needs_credentials';action='Run the existing interactive launcher once to save the Runtime API key locally. Never send the key in chat.'}}
# Never print/decrypt credentials into command lines or parent environment.
try{$secure=(Get-Content -LiteralPath $keyPath -Raw).Trim()|ConvertTo-SecureString -ErrorAction Stop}
catch{return [PSCustomObject]@{status='needs_credentials';action='Saved credential could not be decrypted for this account. Use the existing interactive launcher to repair it; nothing was reset.'}}
$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try{
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$transport.executable;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
    $psi.ArgumentList.Add('run');$psi.ArgumentList.Add('--profile');$psi.ArgumentList.Add($profile)
    $healthPort=switch($App){'blender'{8080};'blockbench'{8081};'godot'{8082}}
    $psi.ArgumentList.Add('--health.listen-addr');$psi.ArgumentList.Add("127.0.0.1:$healthPort")
    $psi.Environment['CONTROL_PLANE_API_KEY']=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    if($App -eq 'blender'){$psi.Environment['BLENDER_HOST']='localhost';$psi.Environment['BLENDER_PORT']='9876'}
    $process=[Diagnostics.Process]::Start($psi)
    $psi.Environment.Remove('CONTROL_PLANE_API_KEY')|Out-Null
    if($process.WaitForExit(1000)){throw 'Transport exited during startup. Check profile/credential permissions using the existing launcher.'}
    [PSCustomObject]@{status='started_unverified';pid=$process.Id;profile=$profile;action='Verify a read-only remote MCP call; process startup is not authentication proof.'}
}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$secure.Dispose()}
