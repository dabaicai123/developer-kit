# Usage: .\claude\install.ps1 -KitPath <path-to-kit> -TargetPath <project\.claude>
param(
    [Parameter(Mandatory = $true)]
    [string]$KitPath,
    [Parameter(Mandatory = $true)]
    [string]$TargetPath
)

if (-not (Test-Path $KitPath)) {
    throw "Kit path does not exist: $KitPath"
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
    Get-ChildItem "$KitPath\agents" -Filter "*.md" | Copy-Item -Force -Destination "$TargetPath\agents\"
}
if (Test-Path "$KitPath\commands") {
    Get-ChildItem "$KitPath\commands" -Filter "*.md" | Copy-Item -Force -Destination "$TargetPath\commands\"
}
if (Test-Path "$KitPath\rules") {
    Get-ChildItem "$KitPath\rules" -Filter "*.md" | Copy-Item -Force -Destination "$TargetPath\rules\"
}
