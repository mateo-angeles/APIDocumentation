docfx.exe metadata .\docfxWindows.json

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Check if running on powershell 7+
if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue))
{
  throw "This step required PowerShell 7+ (ConvertFrom-Yaml). The GitHub 
  'windows-latest' runner includes pwsh."
}

$repo = Get-Location
$apiDirectory = Join-Path $repo "api"
$outputDirectory = Join-Path $repo "apidocs"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

function SafeName([string]$string) { $s -replace '[^A-Za-z0-9_.-]+','_' }

