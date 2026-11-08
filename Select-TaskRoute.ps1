param(
    [ValidateSet('web','game','brain','learning','general')][string]$Domain='web',
    [ValidateSet('low','medium','high')][string]$Complexity='low',
    [ValidateSet('low','high','critical')][string]$Risk='low',
    [ValidateRange(0,10)][int]$FailureCount=0
)
$profiles=@{web='local-web';game='local-game';brain='local-brain';learning='local-learning';general='local-code'}
$escalate=$Risk -eq 'critical' -or $FailureCount -ge 2
[PSCustomObject]@{
    writer_role=if($escalate){'codex'}else{'local-implementer'}
    model=if($escalate){'current-codex-model'}else{$profiles[$Domain]}
    reviewer_role='codex'
    require_chatgpt=($Complexity -eq 'high' -or $Risk -ne 'low' -or $escalate)
    split_task=($Complexity -eq 'high')
    reason=if($Risk -eq 'critical'){'Critical change requires cloud implementation/review'}elseif($FailureCount -ge 2){'Two local failures: escalate only this task'}elseif($Complexity -eq 'high'){'Split into bounded tasks before model execution'}else{'Local-first implementation with Codex verification'}
}
