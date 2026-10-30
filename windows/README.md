# Windows + Kiro IDE setup

This folder makes the `/weekly-report`, `/monthly-report` and `/save-session` skills work
on **Windows** in **Kiro IDE**. The rest of the repo targets Kiro CLI on macOS/Linux
(`setup.sh`, `curl`, `date`, `knowledge`).

**Nothing outside `windows/` is modified.** The skills in `skills/` stay the single source
of truth. The Windows installer copies them into `~\.kiro` unchanged and appends a short
Windows/Kiro IDE addendum to each installed copy. When the skills are updated in the repo,
`git pull` + `setup.ps1 -UpdateSkillsOnly` picks the changes up with no merge conflicts.

## What's in here

| File | Purpose |
|------|---------|
| `setup.ps1` | Windows installer (counterpart of `../setup.sh`). Also `-UpdateSkillsOnly` for updates. |
| `addenda/common.md` | Appended to every installed skill: paths, current-date command, `sheets_mode`. |
| `addenda/<skill>.md` | Skill-specific Windows/Kiro IDE notes (Apps Script calls, `sheets_mode: none`, knowledge base). |
| `scripts/Invoke-AppsScript.ps1` | Replaces the two-step `curl ... /dev/null` Apps Script calls. Installed to `~\.kiro\scripts\`. |
| `mcp/google-sheets.mcp.example.json` | Example `google-sheets` MCP server entry for Kiro IDE. |

## Prerequisites

- **Kiro IDE** on Windows.
- **Windows PowerShell 5.1** (built in) or PowerShell 7+.
- **uv / uvx** (only for Google Sheets): `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"`, or `pip install uv`.
- A **Google account** (only for Google Sheets), and Jira access (optional, for report data).

## 1. Google setup (skip if you choose "no Google Sheets")

Follow [`../google/GOOGLE_SETUP.md`](../google/GOOGLE_SETUP.md), with these Windows/Kiro IDE notes:

1. **Enable both APIs**: Google Sheets API **and Google Drive API** (the MCP server needs Drive
   to list spreadsheets and folders).
2. **Service-account key**: save the JSON outside any repo, e.g.
   `C:\Users\<you>\.config\kiro-sheets-sa.json`. It is a password: never commit it and never
   paste its contents into chat. Only its *path* goes into the MCP config.
   - On a corporate Google Workspace, key creation may be blocked by policy
     (`iam.disableServiceAccountKeyCreation`). Ask your admin, or use the OAuth option of the
     MCP server instead.
3. **Drive folders and template**: as in GOOGLE_SETUP Steps 3-4. Share the **root** folder
   with the service-account email (Editor). Your own account must be able to open the
   template, because the Apps Script copies it as you.
4. **Apps Script**: as in GOOGLE_SETUP Step 5 (Execute as: Me, Who has access: Anyone). Keep
   the Web App URL private; anyone with it can create files in your Drive.

Note down: Apps Script URL, template ID, root folder ID, current-year folder ID, key path.

## 2. Install

From the repo root, in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

Answer the prompts (worker ID, name, projects, Google mode and IDs). Existing
`work-config.yaml` / `folders.yaml` are backed up before being replaced.

Test without touching your real config:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 -KiroDir "$env:TEMP\kiro-test"
```

## 3. Connect Google Sheets in Kiro IDE

Add the `google-sheets` entry from [`mcp/google-sheets.mcp.example.json`](mcp/google-sheets.mcp.example.json)
to your **user** MCP config `~\.kiro\settings\mcp.json`. If the file already exists, add the
entry under `mcpServers` next to your other servers; do not replace the file. Set:

- `SERVICE_ACCOUNT_PATH`: path to the JSON key (forward slashes are fine in JSON).
- `DRIVE_FOLDER_ID`: the root reports folder ID.

The server version is pinned (`mcp-google-sheets@0.6.3`) and limited to the five tools the
skills use. `--with mcp==1.30.0` is required: `mcp-google-sheets` only asks for `mcp>=1.8.0`,
so without the pin `uvx` installs `mcp` 2.x, where `FastMCP` was removed, and the server
crashes on start (`No module named 'mcp.server.fastmcp'`). Kiro IDE reconnects MCP servers automatically when the file changes; check the
server status in the Kiro panel (MCP Servers).

## 4. Verify

```powershell
# Apps Script deployment responds (expects {"status":"ok",...})
& "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action ping
```

Then in Kiro IDE chat: `weekly report current week`. The agent should take the date from the
PowerShell command, gather your work log, show the table and the percentage summary, and
(after you confirm) create the spreadsheet in the right month folder.

## Updating

```powershell
git pull
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 -UpdateSkillsOnly
```

This re-installs the skills (+ addenda) and the helper only. Your config is not touched. If
an installed `SKILL.md` was edited by hand, it is backed up first. Start a new Kiro chat
session afterwards.

## How the Windows adaptation works

| macOS/Linux (skills) | Windows + Kiro IDE (addenda) |
|----------------------|------------------------------|
| `date '+%Y-%m-%d %A %u'` | PowerShell one-liner with the same output; Sunday = 7, invariant English day name |
| two-step `curl -o /dev/null -w "%{redirect_url}"` | `~\.kiro\scripts\Invoke-AppsScript.ps1 -Action ...` (same POST -> redirect -> GET) |
| `knowledge add` (Kiro CLI) | skipped and reported as skipped (not available in Kiro IDE) |
| `~/.kiro/work-log/` in the Friday check | `{work_log_dir}` from `work-config.yaml` |
| `sheets_mode` asked by setup but not used by the skills | `none` handled: chat + local copy, no Google calls |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "running scripts is disabled on this system" | Run with `powershell -ExecutionPolicy Bypass -File ...` as shown above. |
| Helper prints `{"error":"folders.yaml not found ..."}` | Run `setup.ps1` with a Google mode (1 or 2), or pass `-Url`. |
| Helper prints `Unexpected HTTP 404` | Wrong Apps Script URL, or the deployment was removed. Re-deploy and update `folders.yaml`. |
| `update_cells` returns 403 | Share the root folder (Editor) and the template (Viewer) with the service-account email. |
| MCP server does not start / `uvx` not found | Install uv, then restart Kiro IDE so `uvx` is on PATH. |
| MCP server fails with `No module named 'mcp.server.fastmcp'` | The `--with mcp==1.30.0` pin is missing from the args (see Step 3). |
| Skill still uses `curl` or `date` | The installed skill is outdated: run `setup.ps1 -UpdateSkillsOnly` and start a new chat. |

## Not covered

- `link.sh` (maintainer symlinks) has no Windows port. On Windows file symlinks need admin or
  Developer Mode, and linking would bypass the addenda. Edit skills in the repo and run
  `-UpdateSkillsOnly` instead.
- Kiro CLI on Windows is not tested. The addenda are written for Kiro IDE.
