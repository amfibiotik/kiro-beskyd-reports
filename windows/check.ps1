<#
.SYNOPSIS
  Read-only health check of a Windows + Kiro IDE installation of the report skills.

.DESCRIPTION
  Checks that the skills, the helper script, the holidays file, work-config.yaml,
  folders.yaml, the google-sheets MCP entry, the service-account key and uvx are in place,
  and pings the Apps Script Web App. Nothing is created or changed.
  Personal values are never printed: IDs and URLs are shown only as "set" / "missing",
  and the key file is checked for existence and type only (its contents are not shown).

.PARAMETER KiroDir
  Kiro directory to check. Defaults to $HOME\.kiro.

.PARAMETER SkipPing
  Do not call the Apps Script Web App.
#>
[CmdletBinding()]
param(
  [string]$KiroDir = (Join-Path $HOME ".kiro"),
  [switch]$SkipPing
)

# NOTE: keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less scripts as ANSI).

$script:Fails = 0
function Report([bool]$Ok, [string]$Label, [string]$Hint = "") {
  if ($Ok) { Write-Host ("  OK    " + $Label) }
  else {
    $script:Fails++
    Write-Host ("  FAIL  " + $Label)
    if ($Hint) { Write-Host ("        -> " + $Hint) }
  }
}
function Info([string]$Text) { Write-Host ("  --    " + $Text) }

function Get-YamlValue([string]$Path, [string]$Key) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $m = Select-String -LiteralPath $Path -Pattern ('^\s*' + [regex]::Escape($Key) + ':\s*"?([^"#\r\n]*?)"?\s*(#.*)?$') | Select-Object -First 1
  if ($m) { return $m.Matches[0].Groups[1].Value.Trim() }
  return $null
}

Write-Host ""
Write-Host "Kiro report skills - installation check"
Write-Host "Target: $KiroDir"
Write-Host ""

Write-Host "Skills"
foreach ($s in @("weekly-report", "monthly-report", "save-session")) {
  $p = Join-Path $KiroDir "skills\$s\SKILL.md"
  $ok = (Test-Path -LiteralPath $p) -and ((Get-Content -LiteralPath $p -Raw) -match "windows-kiro-ide addendum \($s\)")
  Report $ok "$s installed with the Windows addendum" "run windows\update.cmd"
}
$wr = Join-Path $KiroDir "skills\weekly-report\SKILL.md"
if (Test-Path -LiteralPath $wr) {
  Report ((Get-Content -LiteralPath $wr -Raw) -match "work-days-days-off") "team rule Work days / Days off present" "run windows\update.cmd"
}
Report (Test-Path -LiteralPath (Join-Path $KiroDir "scripts\Invoke-AppsScript.ps1")) "helper scripts\Invoke-AppsScript.ps1" "run windows\update.cmd"
$year = (Get-Date).Year
Report (Test-Path -LiteralPath (Join-Path $KiroDir "holidays-$year.yaml")) "holidays-$year.yaml" "copy shared\holidays-$year.yaml to $KiroDir (ask the team for the new list)"
Write-Host ""

Write-Host "Personal config"
$wc = Join-Path $KiroDir "work-config.yaml"
Report (Test-Path -LiteralPath $wc) "work-config.yaml" "run windows\install.cmd"
$mode = Get-YamlValue $wc "sheets_mode"
foreach ($k in @("worker_id", "full_name")) {
  $v = Get-YamlValue $wc $k
  Report ([bool]$v) "$k is set" "run windows\install.cmd"
}
if ($mode) { Info "sheets_mode: $mode" }
Write-Host ""

if ($mode -and $mode -ne "none") {
  Write-Host "Google Sheets"
  $fy = Join-Path $KiroDir "skills\weekly-report\folders.yaml"
  Report (Test-Path -LiteralPath $fy) "folders.yaml" "run windows\install.cmd and choose Google Sheets"
  foreach ($k in @("apps_script_url", "template_id", "root_folder_id", "year_folder_id")) {
    $v = Get-YamlValue $fy $k
    Report ([bool]$v -and $v -notmatch '^__') "$k is set" "run windows\install.cmd"
  }
  $fyYear = Get-YamlValue $fy "year"
  if ($fyYear -and $fyYear -ne "$year") { Info "folders.yaml year is $fyYear - the skill will roll over to $year on the first report (expected)" }

  $mcp = Join-Path $KiroDir "settings\mcp.json"
  $g = $null
  if (Test-Path -LiteralPath $mcp) {
    try { $g = (Get-Content -LiteralPath $mcp -Raw | ConvertFrom-Json).mcpServers."google-sheets" } catch { $g = $null }
  }
  Report ([bool]$g) "mcp.json has the google-sheets server" "see windows\README.md, step 4"
  if ($g) {
    $args = ($g.args -join " ")
    Report ($args -match "mcp==1\.") "google-sheets args pin mcp 1.x (--with mcp==1.30.0)" "without the pin the server crashes (mcp 2.x); see README troubleshooting"
    Report (-not $g.disabled) "google-sheets server is enabled"
    $key = $g.env.SERVICE_ACCOUNT_PATH
    $keyOk = $false
    if ($key -and (Test-Path -LiteralPath $key)) {
      try { $keyOk = ((Get-Content -LiteralPath $key -Raw | ConvertFrom-Json).type -eq "service_account") } catch { $keyOk = $false }
    }
    Report $keyOk "service-account key file exists and is a service_account key" "check SERVICE_ACCOUNT_PATH in mcp.json"
    Report ([bool]$g.env.DRIVE_FOLDER_ID) "DRIVE_FOLDER_ID is set"
  }
  Report ([bool](Get-Command uvx -ErrorAction SilentlyContinue)) "uvx is on PATH" "install uv, then restart Kiro IDE"

  if (-not $SkipPing) {
    $helper = Join-Path $KiroDir "scripts\Invoke-AppsScript.ps1"
    if (Test-Path -LiteralPath $helper) {
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $helper -Action ping -FoldersYaml $fy 2>&1 | Out-String
      Report ($out -match '"status"\s*:\s*"ok"') "Apps Script Web App answers ping" "check the URL and that 'Who has access' is 'Anyone' (README, step 1.5)"
    }
  }
  Write-Host ""
}

if ($script:Fails -eq 0) { Write-Host "All checks passed. Open a NEW chat in Kiro IDE and say: weekly report current week" }
else { Write-Host ("{0} check(s) failed - see the hints above." -f $script:Fails) }
Write-Host ""
exit $script:Fails
