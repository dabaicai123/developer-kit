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

function Install-Kit($name) {
    if ($Platform -eq "both") {
        Install-KitForPlatform $name "claude"
        Install-KitForPlatform $name "codex"
    }
    else {
        Install-KitForPlatform $name $Platform
    }
}

if ($Kit -eq "all") {
    Install-Kit "java"
    Install-Kit "frontend"
    Install-Kit "base"
    Install-Kit "agent"
}
else {
    Install-Kit $Kit
}

if ($Tmp) {
    Remove-Item -Recurse -Force $Tmp
}

if ($Platform -eq "codex" -or $Platform -eq "both") {
    Write-Host "Codex note: restart Codex after installing so new skills and agents are discovered."
    Write-Host "Codex note: Claude agents are converted to Codex subagents, for example devkit_java_feature."
    Write-Host "Codex note: ensure ~/.codex/config.toml has [features] skills = true."
}
