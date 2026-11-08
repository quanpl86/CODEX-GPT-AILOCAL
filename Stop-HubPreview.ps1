param([Parameter(Mandatory)][int]$ProcessId,[Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{32}$')][string]$Nonce)
$ErrorActionPreference='Stop'
$script=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'web/project-preview.mjs'))
$process=Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId"
if(-not $process){return}
if($process.Name -ne 'node.exe' -or $process.CommandLine.IndexOf($script,[StringComparison]::OrdinalIgnoreCase) -lt 0 -or -not $process.CommandLine.Contains($Nonce)){throw 'Process ownership mismatch; no process was stopped'}
Stop-Process -Id $ProcessId -ErrorAction Stop
