$ErrorActionPreference='Stop'
foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object Extension -In '.ps1','.psm1'){
    $parseErrors=$null;$tokens=$null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)|Out-Null
    if($parseErrors.Count){throw ($parseErrors|Out-String)}
}
Write-Output 'PASS: PowerShell syntax'
foreach($test in @('Test-LocalWorkflow.ps1','Test-CapacityGuard.ps1','Test-LocalCoder.ps1','Test-TaskRouting.ps1','Test-Installer.ps1')){
    & (Join-Path $PSScriptRoot $test)
}
$report=& "$PSScriptRoot\New-ReviewReport.ps1" -TaskId qa-1 -Finding 'Unexpected result' -Expected 'A' -Actual 'B' -RequestedChange 'Fix the domain rule'
if($report.from_role -ne 'codex-reviewer' -or $report.to_role -ne 'local-implementer' -or $report.expected -ne 'A'){throw 'Repair report contract failed'}
$caught=$false
try{& "$PSScriptRoot\New-ReviewReport.ps1" -TaskId qa-1 -Finding x -Expected a -Actual b -RequestedChange c -Severity invalid|Out-Null}catch{$caught=$true}
if(-not $caught){throw 'Invalid review severity accepted'}
Write-Output 'PASS: structured review report'
Write-Output 'All offline checks passed. This does not run live model inference, application MCPs or hosted CI.'
