<#
.SYNOPSIS
  Windows + Kiro IDE installer for the /save-session, /weekly-report and
  /monthly-report skills. Windows counterpart of ../setup.sh.

.DESCRIPTION
  Does not modify anything in the repo. It installs into <KiroDir> (default ~\.kiro):
    - skills\<skill>\SKILL.md  = the repo's skills\<skill>\SKILL.md (unchanged)
                                 + windows\addenda\common.md
                                 + windows\addenda\<skill>.md
    - scripts\Invoke-AppsScript.ps1  (Windows replacement for the two-step curl calls)
    - holidays-*.yaml                (from shared\)
    - work-config.yaml               (generated from your answers)
    - skills\weekly-report\folders.yaml  (generated, unless sheets_mode = none)

  Existing generated files are backed up (.backup.<timestamp>) before being replaced.
  Compatible with Windows PowerShell 5.1 and PowerShell 7+.

.PARAMETER KiroDir
  Target Kiro directory. Defaults to $HOME\.kiro. Point it at a temp folder to test.

.PARAMETER UpdateSkillsOnly
  Re-install only the skills (+ addenda) and the helper script, e.g. after `git pull`.
  No questions asked; work-config.yaml and folders.yaml are not touched.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 -UpdateSkillsOnly
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
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Skills = @("save-session", "weekly-report", "monthly-report")

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  # Set-Content -Encoding UTF8 adds a BOM on PS 5.1; YAML/Markdown are safer without it.
  [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Read-Utf8([string]$Path) {
  # Repo files are UTF-8 (skills contain Cyrillic); read them explicitly as UTF-8.
  return [System.IO.File]::ReadAllText($Path, $Utf8)
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

function Install-Skills {
  $common = Read-Utf8 (Join-Path $WindowsDir "addenda\common.md")
  foreach ($skill in $Skills) {
    $src = Join-Path $RepoRoot "skills\$skill\SKILL.md"
    $addendum = Join-Path $WindowsDir "addenda\$skill.md"
    $destDir = Join-Path $KiroDir "skills\$skill"
    $dest = Join-Path $destDir "SKILL.md"
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    $text = (Read-Utf8 $src).TrimEnd() + "`n" + $common.TrimEnd() + "`n"
    if (Test-Path -LiteralPath $addendum) { $text += (Read-Utf8 $addendum).TrimEnd() + "`n" }
    $text = $text -replace "`r`n", "`n"

    # Back up only if the installed copy differs (e.g. hand-edited or older version).
    if ((Test-Path -LiteralPath $dest) -and ((Read-Utf8 $dest) -ne $text)) { Backup-IfExists $dest }
    Write-Utf8NoBom $dest $text
  }
  Write-Host "  OK  Skills installed (repo SKILL.md + Windows/Kiro IDE addenda)"

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

# ---------------------------------------------------------------- update mode
if ($UpdateSkillsOnly) {
  Write-Host ""
  Write-Host "Updating skills in $KiroDir (config files are not touched)"
  Write-Host ""
  Install-Skills
  Install-Holidays $true
  Write-Host ""
  Write-Host "Done. Restart the Kiro IDE chat session to pick up the new skill text."
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
Write-Host "Make sure you've completed the Google steps in windows\README.md first"
Write-Host "(or choose option 3 below to skip Google Sheets)."
Write-Host ""

Write-Host "Step 1/4: Personal info"
Write-Host "-----------------------"
$WorkerId = Read-Required "  Worker ID (e.g. CW-0011)"
$FullName = Read-Required "  Full name (e.g. John Doe)"
Write-Host ""

Write-Host "Step 2/4: Projects"
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

Write-Host "Step 3/4: Google integration"
Write-Host "----------------------------"
Write-Host "  How do you want to save reports?"
Write-Host "    1) Monthly subfolders (e.g. 06-June/)"
Write-Host "    2) Single folder (everything in one place)"
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
  $AppsScriptUrl = Read-Required "  Apps Script Web App URL"
  $TemplateId    = Read-Required "  Template spreadsheet ID"
  $RootFolderId  = Read-Required "  Root Drive folder ID (holds per-year subfolders)"
  $YearFolderId  = Read-Required "  Current year folder ID (subfolder for $Year inside root)"
}
Write-Host ""

Write-Host "Step 4/4: Installing..."
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
# Do not commit this file (contains personal info)
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
apps_script_url: $(ConvertTo-YamlString $AppsScriptUrl)
template_id: $(ConvertTo-YamlString $TemplateId)
root_folder_id: $(ConvertTo-YamlString $RootFolderId)
year: $Year
year_folder_id: $(ConvertTo-YamlString $YearFolderId)
months: {}
"@
  Write-Utf8NoBom $foldersPath (($folders -replace "`r`n", "`n") + "`n")
  Write-Host "  OK  folders.yaml created"
} else {
  Write-Host "  --  folders.yaml skipped (sheets_mode: none)"
}

Write-Host ""
Write-Host "Done!"
Write-Host ""
if ($SheetsMode -ne "none") {
  Write-Host "Next steps (see windows\README.md):"
  Write-Host "  1. Add the google-sheets MCP server to $KiroDir\settings\mcp.json"
  Write-Host "     (example: windows\mcp\google-sheets.mcp.example.json)"
  Write-Host "  2. Check the Apps Script deployment:"
  Write-Host "     & `"$KiroDir\scripts\Invoke-AppsScript.ps1`" -Action ping"
  Write-Host "  3. In Kiro IDE chat: 'weekly report current week'"
} else {
  Write-Host "Next: in Kiro IDE chat say 'weekly report current week'."
}
Write-Host ""
