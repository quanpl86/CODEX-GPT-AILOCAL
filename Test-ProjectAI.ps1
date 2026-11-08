$ErrorActionPreference='Stop'
$scriptFiles=@(Get-ChildItem -LiteralPath $PSScriptRoot -File)+@(Get-ChildItem -LiteralPath "$PSScriptRoot/web" -Recurse -File)
foreach($file in $scriptFiles | Where-Object Extension -In '.ps1','.psm1'){
    $parseErrors=$null;$tokens=$null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)|Out-Null
    if($parseErrors.Count){throw ($parseErrors|Out-String)}
}
Write-Output 'PASS: PowerShell syntax'
foreach($test in @('Test-LocalWorkflow.ps1','Test-CapacityGuard.ps1','Test-LocalCoder.ps1','Test-TaskRouting.ps1','Test-Installer.ps1','Test-ServiceStartup.ps1','Test-HubRouting.ps1','Test-ManagedProjects.ps1','Test-WebWorkflow.ps1')){
    & (Join-Path $PSScriptRoot $test)
}
$report=& "$PSScriptRoot\New-ReviewReport.ps1" -TaskId qa-1 -Finding 'Unexpected result' -Expected 'A' -Actual 'B' -RequestedChange 'Fix the domain rule'
if($report.from_role -ne 'codex-reviewer' -or $report.to_role -ne 'local-implementer' -or $report.expected -ne 'A'){throw 'Repair report contract failed'}
$caught=$false
try{& "$PSScriptRoot\New-ReviewReport.ps1" -TaskId qa-1 -Finding x -Expected a -Actual b -RequestedChange c -Severity invalid|Out-Null}catch{$caught=$true}
if(-not $caught){throw 'Invalid review severity accepted'}
Write-Output 'PASS: structured review report'
$webFixture=Join-Path $PSScriptRoot ('test-results/web-suite-'+[guid]::NewGuid().ToString('N'))
foreach($relative in @(Get-Content "$PSScriptRoot/kit-files.json" -Raw|ConvertFrom-Json)){
    $target=Join-Path $webFixture $relative
    New-Item -ItemType Directory -Path (Split-Path $target) -Force|Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $relative) -Destination $target
    if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $relative)).Hash){throw 'Test fixture source hash mismatch'}
}
& node --test "$webFixture/web/hub.test.mjs" "$webFixture/web/workflow.test.mjs" "$webFixture/web/provider-settings.test.mjs" "$webFixture/web/preview.test.mjs" "$webFixture/web/request-journal.test.mjs" "$webFixture/web/admissions.test.mjs"
if($LASTEXITCODE -ne 0){throw 'Web HUB tests failed'}
& node --check "$PSScriptRoot/web/public/app.js"
if($LASTEXITCODE -ne 0){throw 'Web UI syntax check failed'}
Write-Output 'All offline checks passed. This does not run live model inference, application MCPs or hosted CI.'
