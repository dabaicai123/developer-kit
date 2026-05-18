# Usage: .\install.ps1 [-Kit java|frontend|base|agent|all] [-Target .] [-Platform both|claude|codex]
param(
    [string]$Kit = "java",
    [string]$Target = ".",
    [ValidateSet("both", "claude", "codex")]
    [string]$Platform = "both"
)

$ErrorActionPreference = "Stop"

function Resolve-InstallTarget($path) {
    if ([IO.Path]::IsPathRooted($path)) {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
    }
    else {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            (Join-Path (Get-Location).ProviderPath $path)
        )
    }
    $system32 = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path $env:WINDIR "System32"))

    if ($resolved.TrimEnd("\") -ieq $system32.TrimEnd("\")) {
        throw "Target resolves to $resolved. Run this installer from your project root or pass -Target <project-path>."
    }

    return $resolved
}

$Target = Resolve-InstallTarget $Target

$Repo = "https://github.com/dabaicai123/developer-kit.git"
$Tmp = $null

if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "kits"))) {
    $RepoRoot = $PSScriptRoot
}
else {
    $Tmp = Join-Path $env:TEMP "developer-kit-$(Get-Random)"
    git clone --depth 1 $Repo $Tmp
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
        exit $LASTEXITCODE
    }
    $RepoRoot = $Tmp
}

function Install-ProjectInstructions {
    $agentsSource = Join-Path $RepoRoot "AGENTS.md"
    $agentsTarget = Join-Path $Target "AGENTS.md"
    if ((Test-Path $agentsSource) -and -not (Test-Path $agentsTarget)) {
        Copy-Item -Force $agentsSource $agentsTarget
        Write-Host "Added AGENTS.md -> $agentsTarget"
    }

    $claudeTarget = Join-Path $Target "CLAUDE.md"
    $claudeContent = @(
        "# CLAUDE.md",
        "",
        "Project instructions live in [AGENTS.md](AGENTS.md).",
        "",
        "Read and follow AGENTS.md before making changes in this repository."
    ) -join "`n"
    [IO.File]::WriteAllText($claudeTarget, $claudeContent + "`n", [Text.UTF8Encoding]::new($false))
    Write-Host "Updated CLAUDE.md -> $claudeTarget"
}

function Install-KitForPlatform($name, $platform) {
    $src = Join-Path $RepoRoot "kits\$name"
    if (-not (Test-Path $src)) {
        if ($Tmp) { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
        throw "Unknown kit: $name (expected: java | frontend | base | agent | all)"
    }

    $installer = Join-Path $RepoRoot "$platform\install.ps1"
    if (-not (Test-Path $installer)) {
        if ($Tmp) { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
        throw "Missing installer for platform: $platform"
    }

    $dst = Join-Path $Target ".$platform"
    & $installer -KitPath $src -TargetPath $dst
    if (-not $?) {
        if ($Tmp) { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
        exit 1
    }
    Write-Host "Installed $name -> $dst"
}

function Get-SelectedKits {
    if ($Kit -eq "all") {
        return @("java", "frontend", "base", "agent")
    }
    return @($Kit)
}

function Get-SelectedPlatforms {
    if ($Platform -eq "both") {
        return @("claude", "codex")
    }
    return @($Platform)
}

function Assert-KitExists($name) {
    $src = Join-Path $RepoRoot "kits\$name"
    if (-not (Test-Path $src)) {
        if ($Tmp) { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
        throw "Unknown kit: $name (expected: java | frontend | base | agent | all)"
    }
}

function Remove-ManagedKitFilesForPlatform($platform) {
    $dst = Join-Path $Target ".$platform"
    if (-not (Test-Path $dst)) {
        return
    }

    Get-ChildItem (Join-Path $RepoRoot "kits") -Directory | ForEach-Object {
        $kitPath = $_.FullName

        $skillsPath = Join-Path $kitPath "skills"
        if (Test-Path $skillsPath) {
            Get-ChildItem $skillsPath -Directory | ForEach-Object {
                Remove-Item -Recurse -Force (Join-Path $dst "skills\$($_.Name)") -ErrorAction SilentlyContinue
            }
        }

        $agentsPath = Join-Path $kitPath "agents"
        if (Test-Path $agentsPath) {
            Get-ChildItem $agentsPath -Filter "*.md" | ForEach-Object {
                $extension = if ($platform -eq "codex") { ".toml" } else { ".md" }
                Remove-Item -Force (Join-Path $dst "agents\$($_.BaseName)$extension") -ErrorAction SilentlyContinue
            }
        }

        $commandsPath = Join-Path $kitPath "commands"
        if (Test-Path $commandsPath) {
            Get-ChildItem $commandsPath -Filter "*.md" | ForEach-Object {
                Remove-Item -Force (Join-Path $dst "commands\$($_.Name)") -ErrorAction SilentlyContinue
            }
        }

        $rulesPath = Join-Path $kitPath "rules"
        if (Test-Path $rulesPath) {
            Get-ChildItem $rulesPath -File |
                Where-Object { $_.Extension -in @(".md", ".mdc") } |
                ForEach-Object {
                    Remove-Item -Force (Join-Path $dst "rules\$($_.Name)") -ErrorAction SilentlyContinue
                }
        }
    }

    Write-Host "Removed existing developer-kit entries -> $dst"
}

function Install-Kit($name) {
    if ($Platform -eq "both") {
        Install-KitForPlatform $name "claude"
        Install-KitForPlatform $name "codex"
    }
    else {
        Install-KitForPlatform $name $Platform
    }
}

$kitsToInstall = Get-SelectedKits
$kitsToInstall | ForEach-Object { Assert-KitExists $_ }
Get-SelectedPlatforms | ForEach-Object { Remove-ManagedKitFilesForPlatform $_ }
$kitsToInstall | ForEach-Object { Install-Kit $_ }

Install-ProjectInstructions

if ($Tmp) {
    Remove-Item -Recurse -Force $Tmp
}

if ($Platform -eq "codex" -or $Platform -eq "both") {
    Write-Host "Codex note: restart Codex after installing so new skills and agents are discovered."
    Write-Host "Codex note: Claude agents are converted to Codex subagents, for example devkit_java_feature."
    Write-Host "Codex note: ensure ~/.codex/config.toml has [features] skills = true."
}
