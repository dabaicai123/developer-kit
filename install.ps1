# Usage: .\install.ps1 [-Kit java|frontend|base|agent|all] [-Target .]
param(
    [string]$Kit = "java",
    [string]$Target = "."
)

$Repo = "https://github.com/dabaicai123/developer-kit.git"
$Tmp = Join-Path $env:TEMP "developer-kit-$(Get-Random)"

git clone --depth 1 $Repo $Tmp

function Install-Kit($name) {
    $src = Join-Path $Tmp "kits\$name"
    $dst = Join-Path $Target ".claude"
    New-Item -ItemType Directory -Force -Path "$dst\skills","$dst\agents","$dst\commands","$dst\rules" | Out-Null
    if (Test-Path "$src\skills")   { Copy-Item -Recurse -Force "$src\skills\*"    "$dst\skills\" }
    if (Test-Path "$src\agents")   { Copy-Item -Force "$src\agents\*.md"          "$dst\agents\" }
    if (Test-Path "$src\commands") { Copy-Item -Force "$src\commands\*.md"        "$dst\commands\" }
    if (Test-Path "$src\rules")    { Copy-Item -Force "$src\rules\*.md"           "$dst\rules\" }
    Write-Host "Installed $name -> $dst"
}

if ($Kit -eq "all") { Install-Kit "java"; Install-Kit "frontend"; Install-Kit "base"; Install-Kit "agent" }
else                { Install-Kit $Kit }

Remove-Item -Recurse -Force $Tmp
