[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$ProjectPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
$target = [IO.Path]::GetFullPath($ProjectPath)
if ($target.TrimEnd('\','/') -eq [IO.Path]::GetPathRoot($target).TrimEnd('\','/')) { throw 'ProjectPath must be a project directory, not a drive root.' }
$kit = Join-Path $target '.ai-local'
$files = @(Get-Content "$PSScriptRoot\kit-files.json" -Raw|ConvertFrom-Json)
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw "Missing source: $file" }
    $dest = Join-Path $kit $file
    if ((Test-Path -LiteralPath $dest) -and -not $Force) {
        $same = (Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file)).Hash
        if (-not $same) { throw "Existing file differs: $dest. Review changes before using -Force." }
    }
}
$agentsPath = Join-Path $target 'AGENTS.md'
$begin = '<!-- BEGIN PROJECT LOCAL AI -->'
$end = '<!-- END PROJECT LOCAL AI -->'
$section = @'
<!-- BEGIN PROJECT LOCAL AI -->
## Local-first AI delivery

ChatGPT plans and reviews milestones; local AI implements bounded code/test tasks;
Codex reviews, applies, tests and owns Git/CI. Read .ai-local/docs/TEAM-CONTRACT.vi.md.
`& ./.ai-local/Invoke-LocalCoder.ps1 -Task web -ProjectPath (Get-Location).Path -Files src/example.ts -Prompt 'Precise task and acceptance'`
Profiles: web/UI -> web; games -> game; general code -> code; agents -> brain;
learning systems -> learning; difficult second opinions -> review. Check resources first.
Review staged changes, apply only the reviewed proposal SHA using Apply-LocalProposal.ps1,
run real checks, then send a narrow ReviewReport for local repairs. Two failed local rounds
or critical risk justify escalating that part to cloud. Do not invoke all models per task.
Run sequentially. Do not load local models during ComfyUI jobs. Input is limited
to 12000 characters including selected context. Failed/truncated answers are not
successful reviews. If local AI is unavailable, Codex continues and discloses it.
Reuse the existing design system and modules; fix causes, avoid patchwork and excess layers.
For web/UI changes verify the actual final app in external Chrome as requested, not only
headless tests. Track phase/task/owner/evidence in the project's existing work board.
ChatGPT collaboration requires a separate workspace-specific C2C pairing and Project;
never reuse AI-LOCAL's connector, chat URL, credentials, or MCP project binding.
<!-- END PROJECT LOCAL AI -->
'@
[string]$existing = if (Test-Path -LiteralPath $agentsPath) { Get-Content -LiteralPath $agentsPath -Raw -Encoding utf8 } else { '' }
$beginCount = [regex]::Matches($existing,[regex]::Escape($begin)).Count
$endCount = [regex]::Matches($existing,[regex]::Escape($end)).Count
if ($beginCount -ne $endCount -or $beginCount -gt 1 -or ($beginCount -eq 1 -and $existing.IndexOf($begin) -gt $existing.IndexOf($end))) {
    throw 'Malformed managed AGENTS.md markers; expected one ordered pair or no markers.'
}
if ($existing.Contains($begin)) {
    $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
    $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{param($m) $section})
} else { $updated = $existing + "`n`n" + $section + "`n" }
if ($PSCmdlet.ShouldProcess($target, 'Install local AI helpers and merge managed AGENTS.md instructions')) {
    New-Item -ItemType Directory -Path $kit -Force | Out-Null
    foreach ($file in $files) {
        $dest=Join-Path $kit $file
        New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $dest -Force
    }
    if ((Test-Path -LiteralPath $agentsPath) -and $updated -ne $existing) {
        Copy-Item -LiteralPath $agentsPath -Destination ($agentsPath + '.backup-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    }
    [IO.File]::WriteAllText($agentsPath, $updated, [Text.UTF8Encoding]::new($false))
    $ignorePath = Join-Path $target '.gitignore'
    $ignore = if (Test-Path $ignorePath) { Get-Content $ignorePath -Raw } else { '' }
    $entries = @('.ai-local/local-runs/','.ai-local/test-results/','.ai-local/.local-ai.request.lock','AGENTS.md.backup-*')
    foreach ($entry in $entries) { if ($entry -notin ($ignore -split '\r?\n')) { $ignore += "`n$entry" } }
    [IO.File]::WriteAllText($ignorePath, $ignore.TrimEnd()+"`n", [Text.UTF8Encoding]::new($false))
    Write-Output "Installed: $kit"
    Write-Output 'Local scripts only. No model download, C2C pairing, global config or application MCP binding was changed.'
}
