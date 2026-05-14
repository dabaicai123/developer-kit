# Usage: .\install.ps1 [-Kit java|frontend|base|agent|all] [-Target .] [-Platform both|claude|codex]
param(
    [string]$Kit = "java",
    [string]$Target = ".",
    [ValidateSet("both", "claude", "codex")]
    [string]$Platform = "both"
)

$Repo = "https://github.com/dabaicai123/developer-kit.git"
$Tmp = Join-Path $env:TEMP "developer-kit-$(Get-Random)"

git clone --depth 1 $Repo $Tmp
if ($LASTEXITCODE -ne 0) {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
    exit $LASTEXITCODE
}

function Copy-KitFiles($name, $dst) {
    $src = Join-Path $Tmp "kits\$name"
    if (-not (Test-Path $src)) {
        Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
        throw "Unknown kit: $name (expected: java | frontend | base | agent | all)"
    }

    New-Item -ItemType Directory -Force -Path "$dst\skills","$dst\agents","$dst\commands","$dst\rules" | Out-Null
    if (Test-Path "$src\skills")   { Copy-Item -Recurse -Force "$src\skills\*"    "$dst\skills\" }
    if (Test-Path "$src\agents")   { Get-ChildItem "$src\agents" -Filter "*.md"   | Copy-Item -Force -Destination "$dst\agents\" }
    if (Test-Path "$src\commands") { Get-ChildItem "$src\commands" -Filter "*.md" | Copy-Item -Force -Destination "$dst\commands\" }
    if (Test-Path "$src\rules")    { Get-ChildItem "$src\rules" -Filter "*.md"    | Copy-Item -Force -Destination "$dst\rules\" }
}

function Install-KitForPlatform($name, $platform) {
    if ($platform -eq "claude") {
        $dst = Join-Path $Target ".claude"
        Copy-KitFiles $name $dst
        Write-Host "Installed $name -> $dst"
    }
    elseif ($platform -eq "codex") {
        $dst = Join-Path $Target ".codex"
        Copy-KitFiles $name $dst
        Write-Host "Installed $name -> $dst"
    }
    else {
        throw "Unknown platform: $platform (expected: both | claude | codex)"
    }
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

if ($Kit -eq "all") { Install-Kit "java"; Install-Kit "frontend"; Install-Kit "base"; Install-Kit "agent" }
else                { Install-Kit $Kit }

Remove-Item -Recurse -Force $Tmp

if ($Platform -eq "codex" -or $Platform -eq "both") {
    Write-Host "Codex note: restart Codex after installing so new skills are discovered."
}
