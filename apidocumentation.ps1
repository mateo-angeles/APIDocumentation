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

function GetSnippet {
  param([string]$filePath, [int]$startLine, [int]$radius = 40)
  if (-not $filePath) {return ""}
  $path = Resolve-Path -LiteralPath $filePath -ErrorAction SilentlyContinue
  if (-not $path) { return "" }
  $lines = Get-Content -LiteralPath $path -Encoding UTF8
  $indexZero = [Math]::Max(0, $startLine - 1 - $radius)
  $indexOne = [Math]::Min($lines.Count - 1, $startLine - 1 + $radius)
  ($lines[$indexZero, $indexOne] -join "`n")
}

function BuildPrompt {
  param($item, [string]$snippet)
  $uid = $item.uid
  $name = $item.name
  $kind = $item.type
  if (-not $kind) { $kind = $Item.kind }
  $returnType = $item.syntax.return.type
  $parameterSpecifications = @()
  foreach ($parameter in ($item.syntax.parameters ?? @()))
  {
    $parameterSpecifications += @{ name = ($parameter.id ?? $parameter.name);
    type = $parameter.type }
  }
  $parametersJson = $parameterSpecifications | ConverTo-Json -Compress
@"
  You are a C# API documentation assistant. Only use facts present in the provided
  signature and snippet. If unsure, say "Unknown". Keep the summary to five sentences.

  Output JSON with this exact schema:
  {
    "summary": string,
    "params": { "<name>": string, ... },
    "returns": string | null,
    "remarks": string | null
  }

  # Symbol
  UID: $uid
  Kind: $kind
  Name: $name
  ReturnType: $returnType
  Parameters: $parametersJson

  # Snippet (context, may be partial)
  ```csharp
  $snippet
"@
}

function CallLLM {
  param([string]$prompt)

  $body = @{
    model = $env:LLMModel
    temperature = 0
    maxTokens = 300
    messages = @(
      @{ role = 'system'; content = 'You write concise, accurate C# XML documentation.
      Do not invent behavior.'},
      @{ role = 'user'; content = $prompt }
    )
  } | ConvertTo-Json -Depth 8
  $headers = @{
    authorization = 'Bearer $($env:LLMApiKey)'
    'Content Type' = 'application/json'
  }

  $response = Invoke -RestMethod -Method Post -Uri `
  $env:LLMBaseUrl -Header $headers -Body $body -TimeoutSec 120

  # Adjust to your provider's response shape if needed.
  $content = $response.choices[0].message.content
  if ($content -match '^```') {
    $content = $content -replace '^```(?:json)?\s*', '' -replace '\s*```$', ''
  }
  $content | ConvertFrom-Json
}

$count = 0
$ymls = Get-ChildItem -Path $apiDirectory -Recurse -Filter *.yml
foreach ($yml in $ymls) {
  $raw = Get-Content -LiteralPath $y.FullName -Raw -Encoding UTF8
  $doc = ConvertFrom-Yaml $raw
  $items = $doc.items
  if (-not $items) { continue }
