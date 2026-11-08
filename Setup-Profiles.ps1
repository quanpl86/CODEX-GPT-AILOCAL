$ErrorActionPreference = 'Stop'
$ollama = 'F:\AI\Ollama\App\ollama.exe'
$profiles = Get-Content -LiteralPath "$PSScriptRoot\profiles.json" -Raw | ConvertFrom-Json
$modelDir = Join-Path $PSScriptRoot 'modelfiles'
New-Item -ItemType Directory -Path $modelDir -Force | Out-Null
foreach ($entry in $profiles.PSObject.Properties) {
    $profile = $entry.Value
    $file = Join-Path $modelDir ($entry.Name + '.Modelfile')
    $content = "FROM $($profile.base)`nPARAMETER num_ctx 8192`nPARAMETER num_predict 4096`nSYSTEM `"`"`"$($profile.system)`"`"`"`n"
    $parameters = @{num_ctx=8192; num_predict=4096}
    if ($null -ne $profile.num_gpu) { $parameters.num_gpu = $profile.num_gpu; $content += "PARAMETER num_gpu $($profile.num_gpu)`n" }
    [IO.File]::WriteAllText($file, $content, [Text.UTF8Encoding]::new($false))
    $body = @{model=$profile.model; from=$profile.base; system=$profile.system; parameters=$parameters; stream=$false} | ConvertTo-Json -Depth 6
    $result = Invoke-RestMethod 'http://127.0.0.1:11434/api/create' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 300
    if ($result.status -ne 'success') { throw "Could not create $($profile.model)" }
    Write-Output "$($profile.model): $($result.status)"
}
