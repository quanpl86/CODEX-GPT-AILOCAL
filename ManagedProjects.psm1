function Get-ManagedLayout {
    param([string]$LayoutPath)
    $layout=Get-Content -LiteralPath $LayoutPath -Raw|ConvertFrom-Json
    if($layout.schemaVersion -ne 1){throw 'Unsupported workspace layout'}
    $root=[IO.Path]::GetFullPath($layout.workspaceRoot).TrimEnd('\','/')
    if($root -eq [IO.Path]::GetPathRoot($root).TrimEnd('\','/')){throw 'Workspace must not be a drive root'}
    if(@($layout.categories).Count -ne 5 -or @($layout.categories|Where-Object{$_ -notin @('web','games','apps','media','learning')}).Count -or @($layout.categories|Select-Object -Unique).Count -ne 5){throw 'Invalid workspace categories'}
    [PSCustomObject]@{root=$root;categories=@($layout.categories);policyVersion=$layout.policyVersion}
}
function Assert-NoProjectLinks {
    param([string]$Path)
    $cursor=[IO.Path]::GetFullPath($Path)
    while($cursor){
        if(Test-Path -LiteralPath $cursor){if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse points are not allowed in managed project paths'}}
        $parent=Split-Path $cursor -Parent
        if($parent -eq $cursor){break};$cursor=$parent
    }
}
Export-ModuleMember -Function Get-ManagedLayout,Assert-NoProjectLinks
