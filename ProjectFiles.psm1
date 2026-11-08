function Resolve-ProjectFile {
    param([Parameter(Mandatory=$true)][string]$ProjectPath,[Parameter(Mandatory=$true)][string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains(':')) { throw 'Only project-relative paths are allowed' }
    $parts = $RelativePath.Replace('\','/').Split('/')
    if (@($parts | Where-Object { $_ -in @('','.','..') -or $_ -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' -or $_.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $_.EndsWith('.') -or $_.EndsWith(' ') }).Count) { throw 'Invalid project-relative path' }
    if ($parts[0] -in @('.git','.codex','.agents','.ai-local','local-runs')) { throw 'Protected project directory' }
    $root = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\','/')
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'Project directory does not exist' }
    $path = [IO.Path]::GetFullPath((Join-Path $root ($parts -join [IO.Path]::DirectorySeparatorChar)))
    if (-not $path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes project' }
    $cursor = $root
    foreach ($part in @('') + $parts) {
        if ($part) { $cursor=Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item=Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse points are not allowed in proposal paths' }
        }
    }
    if (Test-Path -LiteralPath $path -PathType Container) { throw 'Expected a file path, found a directory' }
    return $path
}
function Get-ProjectFileHash {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
    return $null
}
function Assert-ProjectSyntax {
    param([string]$FilePath,[string]$TargetPath)
    if ([IO.Path]::GetExtension($TargetPath) -in @('.ps1','.psm1')) {
        $parseErrors=$null;$tokens=$null
        [System.Management.Automation.Language.Parser]::ParseFile($FilePath,[ref]$tokens,[ref]$parseErrors)|Out-Null
        if($parseErrors.Count){throw "Generated PowerShell syntax is invalid for $TargetPath`: $($parseErrors[0].Message)"}
    } elseif ([IO.Path]::GetExtension($TargetPath) -eq '.json') {
        try { Get-Content -LiteralPath $FilePath -Raw|ConvertFrom-Json|Out-Null }
        catch { throw "Generated JSON syntax is invalid for $TargetPath" }
    }
}
Export-ModuleMember -Function Resolve-ProjectFile,Get-ProjectFileHash,Assert-ProjectSyntax
