[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$SkillsPath,[switch]$Force)
$ErrorActionPreference='Stop'
if(-not $SkillsPath){
    $codexRoot=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $SkillsPath=Join-Path $codexRoot 'skills'
}
$sources=@(Get-ChildItem (Join-Path $PSScriptRoot 'skills') -Directory -Filter 'ai-team-*')
if($sources.Count -ne 7){throw 'Expected the seven AI team skills'}
foreach($source in $sources){
    $dest=Join-Path (Join-Path $SkillsPath $source.Name) 'SKILL.md'
    if((Test-Path $dest) -and -not $Force -and (Get-FileHash $dest).Hash -ne (Get-FileHash (Join-Path $source.FullName 'SKILL.md')).Hash){throw "Existing skill differs: $dest. Review before -Force."}
}
foreach($source in $sources){
    $destDir=Join-Path $SkillsPath $source.Name
    if($PSCmdlet.ShouldProcess($destDir,'Install reusable AI team skill')){
        New-Item -ItemType Directory -Path $destDir -Force|Out-Null
        $dest=Join-Path $destDir 'SKILL.md'
        if((Test-Path $dest) -and (Get-FileHash $dest).Hash -ne (Get-FileHash (Join-Path $source.FullName 'SKILL.md')).Hash){Copy-Item $dest ($dest+'.backup-'+[guid]::NewGuid().ToString('N').Substring(0,8))}
        Copy-Item (Join-Path $source.FullName 'SKILL.md') $dest -Force
        Write-Output "Installed skill: $($source.Name)"
    }
}
