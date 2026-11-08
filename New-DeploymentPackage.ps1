[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$OutputDirectory=(Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference='Stop'
$files=@(Get-Content "$PSScriptRoot\kit-files.json" -Raw|ConvertFrom-Json)
$version=(Get-Content "$PSScriptRoot\VERSION" -Raw).Trim()
if($version -notmatch '^\d+\.\d+\.\d+$'){throw 'Invalid version'}
foreach($file in $files){if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)){throw "Missing release file: $file"}}
if($PSCmdlet.ShouldProcess($OutputDirectory,'Build explicit-allowlist deployment package')){
    New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
    $stage=Join-Path $OutputDirectory ('package-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $stage|Out-Null
    foreach($file in $files){
        $destination=Join-Path $stage $file
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force|Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $destination
    }
    $hashes=@(foreach($file in $files){@{path=$file;sha256=(Get-FileHash -LiteralPath (Join-Path $stage $file)).Hash}})
    $hashes|ConvertTo-Json -Depth 5|Set-Content (Join-Path $stage 'checksums.json') -Encoding utf8
    $archive=Join-Path $OutputDirectory "ai-local-kit-$version.zip"
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -Force
    Get-FileHash -LiteralPath $archive -Algorithm SHA256
}
