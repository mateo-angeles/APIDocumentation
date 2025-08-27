param(
    [string]$Solution = ".\APIDocumentation.sln",
    [string]$DocfxJson = ".\docfxWindows.json",
    [string]$APIDirectory = ".\api",
    [string]$OverwriteDirectory = ".\apidocs"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OverwriteDirectory | Out-Null

# 2) DocFX metadata
docfx metadata $DocfxJson

# 3) Gather undocumented items
$ymls = Get-Childitem $APIDirectory -Filter *.yml -Recurse
$items = @()

foreach ($y in $ymls) {
    $text = Get-Content $y.FullName -Raw
    $blocks = ($text -split "(?m)^-\s+uid:\s") | Where-Object { $_ -ne "" }
    foreach ($b in $blocks) {
        $uid = ($b -split "`n")[0].Trim()
        
    }
}