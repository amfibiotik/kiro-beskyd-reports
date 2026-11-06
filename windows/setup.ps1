<#
.SYNOPSIS
  Windows + Kiro IDE installer for the /save-session, /weekly-report and
  /monthly-report skills. Windows counterpart of ../setup.sh.

.DESCRIPTION
  Does not modify anything in the repo. It installs into <KiroDir> (default ~\.kiro):
    - skills\<skill>\SKILL.md  = the repo's skills\<skill>\SKILL.md (unchanged)
                                 + windows\addenda\common.md
                                 + windows\addenda\<skill>.md
                                 + windows\addenda\rules\<skill>.*.md   (team rules)
                                 + <KiroDir>\skill-addenda\<skill>.md   (optional, personal)
    - scripts\Invoke-AppsScript.ps1  (Windows replacement for the two-step curl calls)
    - holidays-*.yaml                (from shared\)
    - work-config.yaml               (generated from your answers)
    - skills\weekly-report\folders.yaml  (generated, unless sheets_mode = none)
    - settings\mcp.json: adds/updates ONLY the "google-sheets" server (optional, asked)

  Existing files are backed up (.backup.<timestamp>) before being replaced.
  Nothing personal is ever written into the repo.
  Compatible with Windows PowerShell 5.1 and PowerShell 7+.

.PARAMETER KiroDir
  Target Kiro directory. Defaults to $HOME\.kiro. Point it at a temp folder to test.

.PARAMETER UpdateSkillsOnly
  Re-install only the skills (+ addenda) and the helper script, e.g. after `git pull`.
  No questions asked; work-config.yaml, folders.yaml and mcp.json are not touched.

.EXAMPLE
  .\windows\install.cmd            (double-click, same as the line below)
  powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1

.EXAMPLE
  .\windows\update.cmd             (same as: setup.ps1 -UpdateSkillsOnly)
#>
[CmdletBinding()]
param(
  [string]$KiroDir = (Join-Path $HOME ".kiro"),
  [switch]$UpdateSkillsOnly
)

$ErrorActionPreference = "Stop"

# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads BOM-less scripts
# as ANSI, so non-ASCII characters (emoji, Cyrillic) would be garbled.

$WindowsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $WindowsDir
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Skills = @("save-session", "weekly-report", "monthly-report")

# Pinned versions for the google-sheets MCP server (see README "Google Sheets in Kiro IDE").
$McpPackage = "mcp-google-sheets@0.6.3"
$McpPin = "mcp==1.30.0"
$McpTools = "list_spreadsheets,list_sheets,list_folders,get_sheet_data,update_cells"

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  # Set-Content -Encoding UTF8 adds a BOM on PS 5.1; YAML/Markdown are safer without it.
  [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Read-Utf8([string]$Path) {
  # Repo files are UTF-8 (skills contain Cyrillic). Strip a BOM if one is present.
  $t = [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
  if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
  return $t
}

function ConvertTo-YamlString([string]$Value) {
  return '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Backup-IfExists([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    $backup = "$Path.backup.$Stamp"
    Copy-Item -LiteralPath $Path -Destination $backup
    Write-Host "  ->  backed up existing $(Split-Path -Leaf $Path) to $(Split-Path -Leaf $backup)"
  }
}

function Read-Required([string]$Prompt) {
  while ($true) {
    $v = Read-Host $Prompt
    if ($v -and $v.Trim()) { return $v.Trim() }
    Write-Host "    (value is required)"
  }
}

function Read-DriveId([string]$Prompt) {
  # Accepts either a bare ID or a full Google Drive / Sheets URL and returns the ID.
  while ($true) {
    $v = Read-Required $Prompt
    if ($v -match '/folders/([A-Za-z0-9_-]{10,})') { return $Matches[1] }
    if ($v -match '/spreadsheets/d/([A-Za-z0-9_-]{10,})') { return $Matches[1] }
    if ($v -match '^[A-Za-z0-9_-]{10,}$') { return $v }
    Write-Host "    (paste the ID or the full Google Drive link)"
  }
}

function Read-AppsScriptUrl {
  while ($true) {
    $v = Read-Required "  Apps Script Web App URL (ends with /exec)"
    if ($v -match '^https://script\.google\.com/macros/s/[^/\s]+/exec$') { return $v }
    Write-Host "    (expected https://script.google.com/macros/s/.../exec - copy it from Deploy > Manage deployments)"
  }
}

function Install-Skills {
  $common = Read-Utf8 (Join-Path $WindowsDir "addenda\common.md")
  $rulesDir = Join-Path $WindowsDir "addenda\rules"
  foreach ($skill in $Skills) {
    $src = Join-Path $RepoRoot "skills\$skill\SKILL.md"
    $addendum = Join-Path $WindowsDir "addenda\$skill.md"
    $destDir = Join-Path $KiroDir "skills\$skill"
    $dest = Join-Path $destDir "SKILL.md"
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    $text = (Read-Utf8 $src).TrimEnd() + "`n" + $common.TrimEnd() + "`n"
    if (Test-Path -LiteralPath $addendum) { $text += (Read-Utf8 $addendum).TrimEnd() + "`n" }
    # Team rules for this skill, e.g. addenda\rules\weekly-report.work-days.md
    if (Test-Path -LiteralPath $rulesDir) {
      foreach ($rule in (Get-ChildItem -LiteralPath $rulesDir -Filter "$skill.*.md" | Sort-Object Name)) {
        $text += "`n" + (Read-Utf8 $rule.FullName).TrimEnd() + "`n"
      }
    }
    # Optional personal addendum (outside the repo, survives updates).
    $personal = Join-Path $KiroDir "skill-addenda\$skill.md"
    if (Test-Path -LiteralPath $personal) { $text += "`n" + (Read-Utf8 $personal).TrimEnd() + "`n" }
    $text = $text -replace "`r`n", "`n"

    # Back up only if the installed copy differs (e.g. hand-edited or older version).
    if ((Test-Path -LiteralPath $dest) -and ((Read-Utf8 $dest) -ne $text)) { Backup-IfExists $dest }
    Write-Utf8NoBom $dest $text
  }
  Write-Host "  OK  Skills installed (repo SKILL.md + Windows/Kiro IDE addenda + team rules)"

  $scriptsDir = Join-Path $KiroDir "scripts"
  New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null
  Copy-Item -Force -LiteralPath (Join-Path $WindowsDir "scripts\Invoke-AppsScript.ps1") -Destination $scriptsDir
  Write-Host "  OK  Helper installed: scripts\Invoke-AppsScript.ps1"
}

function Install-Holidays([bool]$OnlyMissing) {
  $files = Get-ChildItem -Path (Join-Path $RepoRoot "shared") -Filter "holidays-*.yaml"
  foreach ($h in $files) {
    $dest = Join-Path $KiroDir $h.Name
    if ($OnlyMissing -and (Test-Path -LiteralPath $dest)) { continue }
    Copy-Item -Force -LiteralPath $h.FullName -Destination $dest
    Write-Host "  OK  Holidays installed: $($h.Name)"
  }
}

function Set-McpGoogleSheets([string]$KeyPath, [string]$RootFolderId) {
  # Adds/updates ONLY mcpServers."google-sheets" in <KiroDir>\settings\mcp.json.
  # Other servers and settings are kept as they are.
  $settingsDir = Join-Path $KiroDir "settings"
  New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
  $mcpPath = Join-Path $settingsDir "mcp.json"

  $cfg = New-Object PSObject
  if (Test-Path -LiteralPath $mcpPath) {
    $raw = Read-Utf8 $mcpPath
    if ($raw.Trim()) {
      try { $cfg = $raw | ConvertFrom-Json } catch {
        Write-Host "  !!  $mcpPath is not valid JSON - left unchanged. Add the server by hand (README, step 4)."
        return
      }
    }
    Backup-IfExists $mcpPath
  }
  if (-not ($cfg.PSObject.Properties.Name -contains "mcpServers")) {
    $cfg | Add-Member -NotePropertyName mcpServers -NotePropertyValue (New-Object PSObject)
  }
  $server = [ordered]@{
    command  = "uvx"
    args     = @("--with", $McpPin, $McpPackage, "--include-tools", $McpTools)
    env      = [ordered]@{ SERVICE_ACCOUNT_PATH = ($KeyPath -replace '\\', '/'); DRIVE_FOLDER_ID = $RootFolderId }
    disabled = $false
  }
  if ($cfg.mcpServers.PSObject.Properties.Name -contains "google-sheets") {
    $cfg.mcpServers."google-sheets" = [pscustomobject]$server
  } else {
    $cfg.mcpServers | Add-Member -NotePropertyName "google-sheets" -NotePropertyValue ([pscustomobject]$server)
  }
  Write-Utf8NoBom $mcpPath (($cfg | ConvertTo-Json -Depth 20) + "`n")
  Write-Host "  OK  mcp.json: google-sheets server added/updated (other servers kept)"
}

# ---------------------------------------------------------------- update mode
if ($UpdateSkillsOnly) {
  Write-Host ""
  Write-Host "Updating skills in $KiroDir (config files are not touched)"
  Write-Host ""
  Install-Skills
  Install-Holidays $true
  Write-Host ""
  Write-Host "Done. Start a NEW Kiro IDE chat session to pick up the new skill text."
  Write-Host ""
  exit 0
}

# ---------------------------------------------------------------- full install
Write-Host ""
Write-Host "Kiro Weekly Report Setup (Windows + Kiro IDE)"
Write-Host "============================================="
Write-Host ""
Write-Host "This will install /save-session, /weekly-report and /monthly-report skills."
Write-Host "Target: $KiroDir"
Write-Host "For Google Sheets, finish the Google steps in windows\README.md first"
Write-Host "(or choose option 3 below to skip Google Sheets)."
Write-Host ""

Write-Host "Step 1/5: Personal info"
Write-Host "-----------------------"
$WorkerId = Read-Required "  Worker ID (e.g. CW-0000)"
$FullName = Read-Required "  Full name as it should appear in report titles (e.g. John Doe)"
Write-Host ""

Write-Host "Step 2/5: Projects"
Write-Host "------------------"
$Projects = New-Object System.Collections.Generic.List[string]
while ($true) {
  $key  = Read-Required "  Jira project key (e.g. FOTL)"
  $name = Read-Required "  Project human name (e.g. AI QA Tool)"
  $Projects.Add("  ${key}: $(ConvertTo-YamlString $name)")
  $more = Read-Host "  Add another project? (y/n)"
  if ($more -ne "y") { break }
  Write-Host ""
}
Write-Host ""

Write-Host "Step 3/5: Google integration"
Write-Host "----------------------------"
Write-Host "  How do you want to save reports?"
Write-Host "    1) Google Sheets, monthly subfolders (e.g. 11-November/)  [recommended]"
Write-Host "    2) Google Sheets, single folder (everything in one place)"
Write-Host "    3) No Google Sheets (chat + local file only)"
Write-Host ""
$choice = Read-Host "  Choose (1/2/3)"
switch ($choice) {
  "2"     { $SheetsMode = "single_folder" }
  "3"     { $SheetsMode = "none" }
  default { $SheetsMode = "monthly_folders" }
}

$Year = (Get-Date).Year
$AppsScriptUrl = ""; $TemplateId = ""; $RootFolderId = ""; $YearFolderId = ""
if ($SheetsMode -ne "none") {
  Write-Host ""
  Write-Host "  You can paste either the ID or the full Google link for the next three values."
  $AppsScriptUrl = Read-AppsScriptUrl
  $TemplateId    = Read-DriveId "  Template spreadsheet (your own copy of the template)"
  $RootFolderId  = Read-DriveId "  Root reports folder (holds per-year subfolders)"
  $YearFolderId  = Read-DriveId "  Current year folder ($Year, inside the root folder)"
}
Write-Host ""

$KeyPath = ""; $ConfigureMcp = $false
if ($SheetsMode -ne "none") {
  Write-Host "Step 4/5: Google Sheets MCP server in Kiro IDE"
  Write-Host "----------------------------------------------"
  $defaultKey = Join-Path $HOME ".config\kiro-sheets-sa.json"
  $k = Read-Host "  Service-account JSON key path [$defaultKey]"
  if (-not $k) { $k = $defaultKey }
  $KeyPath = $k.Trim().Trim('"')
  if (-not (Test-Path -LiteralPath $KeyPath)) {
    Write-Host "  !!  File not found: $KeyPath"
    Write-Host "      The MCP entry will still be written; put the key there before using the skills."
  }
  $a = Read-Host "  Add the google-sheets server to $KiroDir\settings\mcp.json now? (Y/n)"
  $ConfigureMcp = ($a -ne "n")
  Write-Host ""
}

Write-Host "Step 5/5: Installing..."
Write-Host "-----------------------"
foreach ($d in @("work-planning\work-log", "work-planning\sessions", "work-planning\reports")) {
  New-Item -ItemType Directory -Force -Path (Join-Path $KiroDir $d) | Out-Null
}
Install-Skills
Install-Holidays $false

$workConfigPath = Join-Path $KiroDir "work-config.yaml"
Backup-IfExists $workConfigPath
$workConfig = @"
# Kiro Work Config - generated by windows/setup.ps1
# Personal file: lives only in your ~\.kiro, never commit it.
worker_id: $(ConvertTo-YamlString $WorkerId)
full_name: $(ConvertTo-YamlString $FullName)
activity: "Soft. Dev"
default_hours: 8
projects:
$($Projects -join "`n")

# Global dirs - independent of which project folder Kiro was opened in
work_log_dir: "~/.kiro/work-planning/work-log"
sessions_dir: "~/.kiro/work-planning/sessions"
reports_dir: "~/.kiro/work-planning/reports"

# How reports are saved to Google Sheets:
#   monthly_folders - subfolders per month inside root_folder_id
#   single_folder  - all reports in root_folder_id directly
#   none           - no Google Sheets, chat + local file only
sheets_mode: "$SheetsMode"
"@
Write-Utf8NoBom $workConfigPath (($workConfig -replace "`r`n", "`n") + "`n")
Write-Host "  OK  work-config.yaml created"

$foldersPath = Join-Path $KiroDir "skills\weekly-report\folders.yaml"
if ($SheetsMode -ne "none") {
  Backup-IfExists $foldersPath
  $folders = @"
# Personal file: lives only in your ~\.kiro, never commit it.
apps_script_url: $(ConvertTo-YamlString $AppsScriptUrl)
template_id: $(ConvertTo-YamlString $TemplateId)
root_folder_id: $(ConvertTo-YamlString $RootFolderId)
year: $Year
year_folder_id: $(ConvertTo-YamlString $YearFolderId)
months: {}
"@
  Write-Utf8NoBom $foldersPath (($folders -replace "`r`n", "`n") + "`n")
  Write-Host "  OK  folders.yaml created"
  if ($ConfigureMcp) { Set-McpGoogleSheets $KeyPath $RootFolderId }
} else {
  Write-Host "  --  folders.yaml and MCP skipped (sheets_mode: none)"
}

Write-Host ""
Write-Host "Done!"
Write-Host ""
Write-Host "Next steps (details in windows\README.md):"
Write-Host "  1. Run windows\check.cmd - it verifies the installation and the Apps Script."
if ($SheetsMode -ne "none") {
  Write-Host "  2. In Kiro IDE open the MCP Servers panel: 'google-sheets' must be connected."
  Write-Host "  3. Open a NEW chat and say: weekly report current week"
} else {
  Write-Host "  2. Open a NEW chat in Kiro IDE and say: weekly report current week"
}
Write-Host ""
