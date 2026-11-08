$ErrorActionPreference='Stop'
$router=Join-Path $PSScriptRoot 'Select-TaskRoute.ps1'
$expected=@{web='local-web';game='local-game';brain='local-brain';learning='local-learning';general='local-code'}
foreach($domain in $expected.Keys){
    $route=& $router -Domain $domain
    if($route.model -ne $expected[$domain] -or $route.writer_role -ne 'local-implementer' -or $route.require_chatgpt){throw "Wrong default route: $domain"}
}
$high=& $router -Domain game -Complexity high
if(-not $high.split_task -or -not $high.require_chatgpt -or $high.writer_role -ne 'local-implementer'){throw 'High complexity must be split and planned'}
$sensitive=& $router -Risk high
if(-not $sensitive.require_chatgpt -or $sensitive.writer_role -ne 'local-implementer'){throw 'Sensitive changes require review'}
foreach($argsToTest in @(@{Risk='critical'},@{FailureCount=2},@{FailureCount=10})){
    $route=& $router @argsToTest
    if($route.writer_role -ne 'codex' -or $route.model -ne 'current-codex-model' -or -not $route.require_chatgpt){throw 'Escalation gate failed'}
}
Write-Output 'PASS: domain routes, local-first default, high-complexity split, sensitive review and bounded escalation.'
