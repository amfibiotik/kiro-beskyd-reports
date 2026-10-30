<#
.SYNOPSIS
  Windows replacement for the two-step curl calls to the Apps Script Web App used
  by the weekly-report and monthly-report skills.

.DESCRIPTION
  The skills call the Apps Script Web App like this (macOS/Linux):

    REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" -X POST "$URL" -d '{...}')
    curl -s "$REDIRECT_URL"

  Google answers the POST with a 302 redirect to a one-time URL that holds the JSON
  result. This script does exactly the same two steps (POST without following the
  redirect, then GET the redirect target) and prints the JSON result.

  The Web App URL is read from folders.yaml (apps_script_url) unless -Url is given.
  The JSON body is built from typed parameters, so titles with quotes/apostrophes
  are escaped correctly.

  Compatible with Windows PowerShell 5.1 and PowerShell 7+. ASCII-only on purpose.

.EXAMPLE
  & "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action create_spreadsheet -Title "Report by John Doe 8 - 12 June 2026" -FolderId "<month folder id>"

.EXAMPLE
  & "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action trim_rows -SpreadsheetId "<id>" -DataRows 5

.EXAMPLE
  & "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action create_folder -Name "07-July" -ParentId "<year folder id>"

.EXAMPLE
  & "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action ping
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("create_spreadsheet", "create_folder", "trim_rows", "ping")]
  [string]$Action,
  [string]$Title,
  [string]$FolderId,
  [string]$Name,
  [string]$ParentId,
  [string]$SpreadsheetId,
  [int]$DataRows = -1,
  [string]$Url,
  [string]$FoldersYaml = (Join-Path $HOME ".kiro\skills\weekly-report\folders.yaml")
)

$ErrorActionPreference = "Stop"
# Older .NET defaults on Windows PowerShell 5.1 may not offer TLS 1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Fail([string]$Message) {
  # Emit a JSON error so the calling agent can parse every outcome the same way.
  Write-Output (@{ error = $Message } | ConvertTo-Json -Compress)
  exit 1
}

if (-not $Url) {
  if (-not (Test-Path -LiteralPath $FoldersYaml)) { Fail "folders.yaml not found at $FoldersYaml (pass -Url or run windows\setup.ps1)" }
  $line = Select-String -LiteralPath $FoldersYaml -Pattern '^\s*apps_script_url:\s*"?([^"#\r\n]+?)"?\s*(#.*)?$' | Select-Object -First 1
  if (-not $line) { Fail "apps_script_url not found in $FoldersYaml" }
  $Url = $line.Matches[0].Groups[1].Value.Trim()
}
if ($Url -notmatch '^https://script\.google\.com/') { Fail "apps_script_url does not look like an Apps Script Web App URL" }

function Read-Body($Response) {
  $reader = New-Object IO.StreamReader($Response.GetResponseStream())
  try { return $reader.ReadToEnd() } finally { $reader.Close(); $Response.Close() }
}

function Get-Url([string]$Target) {
  $get = [Net.HttpWebRequest]::Create($Target)
  $get.Method = "GET"
  $get.AllowAutoRedirect = $true
  return Read-Body ($get.GetResponse())
}

# ping = the Web App's doGet health check, handy for verifying the deployment.
if ($Action -eq "ping") {
  try { Write-Output (Get-Url $Url) } catch { Fail "GET failed: $($_.Exception.Message)" }
  exit 0
}

switch ($Action) {
  "create_spreadsheet" {
    if (-not $Title -or -not $FolderId) { Fail "create_spreadsheet needs -Title and -FolderId" }
    $payload = [ordered]@{ action = $Action; title = $Title; folder_id = $FolderId }
  }
  "create_folder" {
    if (-not $Name -or -not $ParentId) { Fail "create_folder needs -Name and -ParentId" }
    $payload = [ordered]@{ action = $Action; name = $Name; parent_id = $ParentId }
  }
  "trim_rows" {
    if (-not $SpreadsheetId -or $DataRows -lt 0) { Fail "trim_rows needs -SpreadsheetId and -DataRows" }
    $payload = [ordered]@{ action = $Action; spreadsheet_id = $SpreadsheetId; data_rows = $DataRows }
  }
}
$json = $payload | ConvertTo-Json -Compress
$bytes = [Text.Encoding]::UTF8.GetBytes($json)

# Step 1: POST, do NOT follow the redirect (same as curl -w "%{redirect_url}").
try {
  $post = [Net.HttpWebRequest]::Create($Url)
  $post.Method = "POST"
  $post.ContentType = "application/json"
  $post.AllowAutoRedirect = $false
  $post.ContentLength = $bytes.Length
  $s = $post.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
  $resp = $post.GetResponse()
} catch [Net.WebException] {
  if ($_.Exception.Response) { $resp = $_.Exception.Response } else { Fail "POST failed: $($_.Exception.Message)" }
}

$status = [int]$resp.StatusCode
$location = $resp.Headers["Location"]

if ($status -ge 300 -and $status -lt 400 -and $location) {
  $resp.Close()
  # Step 2: GET the redirect target to receive the JSON response.
  try { Write-Output (Get-Url $location) } catch { Fail "GET of redirect failed: $($_.Exception.Message)" }
} elseif ($status -eq 200) {
  # Some deployments answer directly; pass the body through.
  Write-Output (Read-Body $resp)
} else {
  $resp.Close()
  Fail "Unexpected HTTP $status from Apps Script (no redirect)"
}
