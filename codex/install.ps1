# Usage: .\codex\install.ps1 -KitPath <path-to-kit> -TargetPath <project\.codex>
param(
    [Parameter(Mandatory = $true)]
    [string]$KitPath,
    [Parameter(Mandatory = $true)]
    [string]$TargetPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $KitPath)) {
    throw "Kit path does not exist: $KitPath"
}

$KitPath = [IO.Path]::GetFullPath($KitPath)
$TargetPath = [IO.Path]::GetFullPath($TargetPath)

function ConvertTo-TomlString($value) {
    $builder = [System.Text.StringBuilder]::new()
    foreach ($char in $value.ToCharArray()) {
        $code = [int][char]$char
        switch ($code) {
            0x08 { [void]$builder.Append("\b"); continue }
            0x09 { [void]$builder.Append("\t"); continue }
            0x0a { [void]$builder.Append("\n"); continue }
            0x0c { [void]$builder.Append("\f"); continue }
            0x0d { [void]$builder.Append("\r"); continue }
            0x22 { [void]$builder.Append('\"'); continue }
            0x5c { [void]$builder.Append("\\"); continue }
        }
        if ($code -lt 0x20 -or $code -gt 0x7e) {
            [void]$builder.Append(("\u{0:x4}" -f $code))
        }
        else {
            [void]$builder.Append($char)
        }
    }
    return '"' + $builder.ToString() + '"'
}

function ConvertTo-TomlLiteralBody($value) {
    $builder = [System.Text.StringBuilder]::new()
    foreach ($char in $value.ToCharArray()) {
        $code = [int][char]$char
        if ($code -eq 0x0d) {
            continue
        }
        if ($code -eq 0x09 -or $code -eq 0x0a -or ($code -ge 0x20 -and $code -le 0x7e)) {
            [void]$builder.Append($char)
        }
        else {
            [void]$builder.Append(("\u{0:x4}" -f $code))
        }
    }
    return $builder.ToString().Replace("'''", "''\u0027")
}

function Get-FrontmatterValue($frontmatter, $key) {
    foreach ($line in $frontmatter) {
        if ($line -match "^$([regex]::Escape($key)):\s*(.+)$") {
            return $matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

function Get-FrontmatterList($frontmatter, $key) {
    $items = @()
    $inList = $false
    foreach ($line in $frontmatter) {
        if ($line -match "^$([regex]::Escape($key)):\s*\[(.*)\]\s*$") {
            $rawItems = $matches[1] -split ","
            foreach ($item in $rawItems) {
                $value = $item.Trim().Trim('"').Trim("'")
                if ($value) { $items += $value }
            }
            $inList = $false
            continue
        }
        if ($line -match "^$([regex]::Escape($key)):\s*$") {
            $inList = $true
            continue
        }
        if ($inList) {
            if ($line -match "^\s*-\s*(.+)$") {
                $items += $matches[1].Trim().Trim('"').Trim("'")
            }
            elseif ($line -match "^\S") {
                $inList = $false
            }
        }
    }
    return $items
}

function ConvertTo-CodexName($value, $fallback) {
    if (-not $value) { $value = $fallback }
    $name = $value.ToLowerInvariant() -replace "[^a-z0-9]+", "_"
    $name = $name.Trim("_")
    if (-not $name) { $name = $fallback }
    return $name
}

function Convert-AgentToCodexToml($sourceFile, $destinationFile) {
    $lines = Get-Content -Path $sourceFile -Encoding UTF8
    $frontmatter = @()
    $bodyLines = $lines

    if ($lines.Count -gt 2 -and $lines[0] -eq "---") {
        $end = -1
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -eq "---") {
                $end = $i
                break
            }
        }
        if ($end -gt 0) {
            $frontmatter = $lines[1..($end - 1)]
            if ($end + 1 -lt $lines.Count) {
                $bodyLines = $lines[($end + 1)..($lines.Count - 1)]
            }
            else {
                $bodyLines = @()
            }
        }
    }

    $originalName = Get-FrontmatterValue $frontmatter "name"
    $name = ConvertTo-CodexName ([IO.Path]::GetFileNameWithoutExtension($sourceFile)) ([IO.Path]::GetFileNameWithoutExtension($sourceFile))
    $description = Get-FrontmatterValue $frontmatter "description"
    if (-not $description) { $description = "Migrated developer-kit agent." }
    $skills = Get-FrontmatterList $frontmatter "skills"
    $tools = Get-FrontmatterList $frontmatter "tools"

    $developerInstructions = ($bodyLines -join "`n").TrimEnd()
    if ($originalName -and $originalName -ne $name) {
        $developerInstructions += "`n`nOriginal Claude agent name: ``$originalName``."
    }
    if ($skills.Count -gt 0) {
        $developerInstructions += "`n`n## Skills`n`nUse these Codex skills when relevant:`n"
        foreach ($skill in $skills) {
            $developerInstructions += "`n- `$$skill"
        }
    }
    if ($tools.Count -gt 0) {
        $developerInstructions += "`n`n## Tools`n`nThe original Claude tool list was: $($tools -join ', '). Treat this as guidance, not a Codex permission boundary."
    }

    $content = @(
        "name = $(ConvertTo-TomlString $name)",
        "description = $(ConvertTo-TomlString $description)",
        "developer_instructions = '''",
        (ConvertTo-TomlLiteralBody $developerInstructions),
        "'''"
    ) -join "`n"

    $destinationDirectory = Split-Path -Parent $destinationFile
    if (-not (Test-Path $destinationDirectory)) {
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
    }
    [IO.File]::WriteAllText($destinationFile, $content + "`n", [Text.UTF8Encoding]::new($false))
}

function Ensure-CodexAgentConfig($targetPath) {
    $configFile = Join-Path $targetPath "config.toml"
    if (-not (Test-Path $configFile)) {
        $content = @(
            "[agents]",
            "max_threads = 4",
            "max_depth = 1",
            "job_max_runtime_seconds = 1800",
            ""
        ) -join "`n"
        [IO.File]::WriteAllText($configFile, $content, [Text.UTF8Encoding]::new($false))
        return
    }

    $existing = Get-Content -Raw -Path $configFile -Encoding UTF8
    if ($existing -notmatch "(?m)^\[agents\]\s*$") {
        Add-Content -Path $configFile -Encoding UTF8 -Value "`n[agents]`nmax_threads = 4`nmax_depth = 1`njob_max_runtime_seconds = 1800"
    }
}

New-Item -ItemType Directory -Force -Path `
    "$TargetPath\skills", `
    "$TargetPath\agents", `
    "$TargetPath\commands", `
    "$TargetPath\rules" | Out-Null

if (Test-Path "$KitPath\skills") {
    Copy-Item -Recurse -Force "$KitPath\skills\*" "$TargetPath\skills\"
}
if (Test-Path "$KitPath\agents") {
    Get-ChildItem "$KitPath\agents" -Filter "*.md" | ForEach-Object {
        $target = Join-Path "$TargetPath\agents" "$($_.BaseName).toml"
        Convert-AgentToCodexToml $_.FullName $target
    }
}
if (Test-Path "$KitPath\commands") {
    Get-ChildItem "$KitPath\commands" -Filter "*.md" | Copy-Item -Force -Destination "$TargetPath\commands\"
}
if (Test-Path "$KitPath\rules") {
    Get-ChildItem "$KitPath\rules" -File |
        Where-Object { $_.Extension -in @(".md", ".mdc") } |
        Copy-Item -Force -Destination "$TargetPath\rules\"
}

Ensure-CodexAgentConfig $TargetPath
