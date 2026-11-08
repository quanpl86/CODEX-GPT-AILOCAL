param([Parameter(Mandatory)][ValidateSet('protect','unprotect')][string]$Action)
$ErrorActionPreference='Stop'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
if($env:OS -ne 'Windows_NT'){throw 'Windows DPAPI is required'}
$value=[Console]::In.ReadToEnd()
if($Action -eq 'protect'){
    $secure=ConvertTo-SecureString -String $value -AsPlainText -Force
    try{[Console]::Write((ConvertFrom-SecureString -SecureString $secure))}finally{$secure.Dispose();$value=$null}
}else{
    $secure=ConvertTo-SecureString -String $value
    $pointer=[IntPtr]::Zero
    try{$pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure);[Console]::Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer))}
    finally{if($pointer -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)};$secure.Dispose();$value=$null}
}
