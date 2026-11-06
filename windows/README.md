# Report skills for Windows + Kiro IDE

This folder installs the `/weekly-report`, `/monthly-report` and `/save-session` skills on
**Windows** for **Kiro IDE**. The rest of the repo targets Kiro CLI on macOS/Linux
(`setup.sh`, `curl`, `date`, `knowledge`); you do not need it.

**Nothing outside `windows/` is changed, and nothing personal is stored in the repo.**
The skills in `skills/` stay the single source of truth. The installer copies them into your
`~\.kiro` and appends the Windows/Kiro IDE notes and the team rules to each installed copy.
Your worker ID, name, Google IDs and keys live only in your own `~\.kiro` and `~\.config`.

Time needed: about 10 minutes without Google Sheets, 30-40 minutes with it.

---

## Contents

| File | Purpose |
|------|---------|
| `install.cmd` | **Double-click to install.** Runs `setup.ps1`. |
| `update.cmd` | Double-click after `git pull`: re-installs the skills, keeps your config. |
| `check.cmd` | Double-click to verify the installation (read-only). |
| `setup.ps1` | The installer itself (also callable from PowerShell). |
| `check.ps1` | The checker itself. |
| `addenda/common.md` | Appended to every skill: paths, current-date command, `sheets_mode`. |
| `addenda/<skill>.md` | Windows/Kiro IDE notes per skill (Apps Script calls, no-Sheets mode, no knowledge base). |
| `addenda/rules/<skill>.<rule>.md` | Team rules on top of the skills (e.g. Work days / Days off). |
| `scripts/Invoke-AppsScript.ps1` | Replaces the macOS `curl ... /dev/null` Apps Script calls. Installed to `~\.kiro\scripts\`. |
| `mcp/google-sheets.mcp.example.json` | Reference `google-sheets` MCP entry (the installer writes it for you). |

---

## 0. Prerequisites

- **Kiro IDE** for Windows, signed in.
- **Git** to clone this repo (or download the repo as ZIP and unpack it).
- **Windows PowerShell 5.1** - built into Windows 10/11, nothing to install.
- For Google Sheets only:
  - **uv** (provides `uvx`, which runs the MCP server). In PowerShell:
    `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"`, then **restart Kiro IDE**.
    Check with `uvx --version`.
  - A **Google account** for your reports (personal or work).

Get the repo:

```powershell
git clone https://github.com/amfibiotik/kiro-beskyd-reports.git
cd kiro-beskyd-reports
```

---

## 1. Google setup (skip if you choose "No Google Sheets")

Do all of this in the browser, signed in to the Google account that will own the reports.
At the end you will have **five values**: Apps Script URL, template ID, root folder ID,
year folder ID, and the path to a key file.

### 1.1 Google Cloud project and APIs

1. Open <https://console.cloud.google.com/>, project list (top left) -> **New Project**.
   Name it anything (e.g. `Kiro Reports`) -> **Create**, then select it in the project list.
2. **APIs & Services -> Library**: enable **Google Sheets API** and **Google Drive API**.
   Drive API is required too: the MCP server uses it to list folders and spreadsheets.

### 1.2 Service account and key

1. **IAM & Admin -> Service Accounts -> Create service account**. Any name. Skip the
   optional role and user steps -> **Done**. No project roles are needed.
2. Copy the service account **email** (`...@<project>.iam.gserviceaccount.com`).
3. Open the account -> **Keys -> Add key -> Create new key -> JSON**. A `.json` file downloads.
4. Move it **out of Downloads** to `C:\Users\<you>\.config\kiro-sheets-sa.json`
   (create the `.config` folder if needed). Not on the Desktop, not in OneDrive, not inside
   any repo.

> The key file is a password. Never commit it, never send it in chat, Teams or e-mail.
> If you lose it, create a new key and delete the old one on the same Keys tab.
> On a corporate Google Workspace, key creation may be blocked
> (`iam.disableServiceAccountKeyCreation`); then ask your admin, or use a personal account.

### 1.3 Drive folders

1. In <https://drive.google.com> create a folder for reports (e.g. `Weekly Reports`), and
   inside it a folder for the current year (e.g. `2026`). Month folders are created by the
   skill automatically.
2. Right-click the **root** folder -> **Share** -> paste the service account email ->
   **Editor** -> untick "Notify people" -> **Share**. Sharing the root covers all subfolders.
3. The folder ID is the part of the URL after `/folders/`. You can also paste the whole link
   into the installer, it extracts the ID.

### 1.4 Report template

The skills fill a template with 35 data rows (rows 2-36) and a `Total` row (row 37).

1. Get the team template (`.xlsx`, ask your lead or a teammate), and upload it into the
   **root** reports folder.
2. Open it and choose **File -> Save as Google Sheets**. Continue in the new tab (the title has
   no `.XLSX` badge). Rename it, e.g. `Report Template`.
3. Delete the uploaded `.xlsx` from the folder, so only the Google Sheet remains.
4. Check the Deliverables dropdown: select `G2:G36` -> **Data -> Data validation** -> the list
   must contain exactly `None`, `Source Code, Object Code, Documentation`,
   `Test Cases, Documentation, Reports`. Excel conversion sometimes splits these on commas;
   fix them if so (no red triangles in column G afterwards).
5. **File -> Settings -> Locale: United States**. Otherwise hours show as `7,5` instead of `7.5`.
6. The template ID is the part of its URL between `/d/` and `/edit`.

### 1.5 Apps Script Web App

The Web App creates spreadsheets and folders **as you**, because a service account has no
storage of its own in a personal Drive.

1. Open <https://script.google.com> -> **New project**.
2. Replace the content of `Code.gs` with the whole of [`../google/apps-script.gs`](../google/apps-script.gs).
3. Set your template ID on this line:
   `var TEMPLATE_ID = "__YOUR_TEMPLATE_SPREADSHEET_ID__";`
4. **Check this line** in `trimRows`: `var templateDataRows = 35;`
   If it says `5`, change it to `35` (the 35-row template needs it; with `5` the reports get
   dozens of empty rows and two Total rows).
5. Save (Ctrl+S).
6. **Deploy -> New deployment** -> gear icon -> **Web app**:
   - Execute as: **Me**
   - Who has access: **Anyone**. Not "Only myself": the calls come from a script, not from
     your browser, so "Only myself" makes every call fail.
7. **Deploy** -> **Authorize access** -> pick your account. On "Google hasn't verified this
   app" click **Advanced -> Go to ... (unsafe)** (it is your own script) -> **Allow**.
8. Copy the **Web app URL** (ends with `/exec`). Keep it private: whoever has it can create
   files in your Drive.

> Changing the code later: **Deploy -> Manage deployments -> Edit (pencil) -> Version: New
> version -> Deploy**. This keeps the same URL. "New deployment" would give you a new URL.

---

## 2. Install

Double-click **`windows\install.cmd`** (or run
`powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1`). Answer the questions:

| Step | What to enter |
|------|---------------|
| 1. Personal info | Your worker ID and your full name as it should appear in report titles. |
| 2. Projects | Jira project key + human name, one or more. |
| 3. Google | `1` monthly subfolders (recommended), `2` single folder, `3` no Google Sheets. Then the Apps Script URL, template, root folder and year folder (IDs or full links). |
| 4. MCP | Path to the key file (Enter accepts `~\.config\kiro-sheets-sa.json`) and whether to add the `google-sheets` server to `~\.kiro\settings\mcp.json` (recommended: yes). |

What the installer writes, all inside your `~\.kiro`:

- `skills\weekly-report`, `skills\monthly-report`, `skills\save-session` (`SKILL.md`)
- `scripts\Invoke-AppsScript.ps1`
- `holidays-<year>.yaml`
- `work-config.yaml` and `skills\weekly-report\folders.yaml` (your personal values)
- `settings\mcp.json`: only the `google-sheets` entry is added or replaced; your other MCP
  servers are kept.

Any existing file is backed up next to it as `<name>.backup.<timestamp>` before it is replaced.

Try it on a throw-away folder first if you like:
`powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 -KiroDir "$env:TEMP\kiro-test"`

---

## 3. Check

Double-click **`windows\check.cmd`**. It checks everything above and pings the Apps Script,
without changing anything and without printing your IDs or keys. Fix every `FAIL` line using
the hint printed under it.

Then in Kiro IDE:

1. Open the **MCP Servers** panel: `google-sheets` must be connected (green). If not, press
   Reconnect; the first start downloads the server and can take a minute.
2. Open a **new chat** (skills are loaded when a chat starts) and say:
   `weekly report current week`.

The agent takes today's date from Windows, collects your work log, asks about any day it has no
data for, shows the table, the percentage summary and the Work days / Days off rows, and only
after you confirm creates the spreadsheet in the month folder.

---

## 4. Google Sheets MCP by hand (only if you skipped it in the installer)

Add this under `mcpServers` in `~\.kiro\settings\mcp.json`, next to your other servers. Do not
replace the whole file. Use your own key path and root folder ID:

```json
"google-sheets": {
  "command": "uvx",
  "args": ["--with", "mcp==1.30.0", "mcp-google-sheets@0.6.3",
           "--include-tools", "list_spreadsheets,list_sheets,list_folders,get_sheet_data,update_cells"],
  "env": {
    "SERVICE_ACCOUNT_PATH": "C:/Users/<you>/.config/kiro-sheets-sa.json",
    "DRIVE_FOLDER_ID": "<root reports folder id>"
  },
  "disabled": false
}
```

`--with mcp==1.30.0` is required. `mcp-google-sheets` only asks for `mcp>=1.8.0`, so without
the pin `uvx` installs `mcp` 2.x, where `FastMCP` was removed, and the server crashes on start.

---

## 5. Using the skills

| Say in chat | What happens |
|-------------|--------------|
| `weekly report last week` / `тижневий звіт минулий тиждень` | Report for the previous Mon-Fri. |
| `weekly report current week` | Report for this week (up to today). |
| `monthly report` / `місячний звіт` | Month report from the weekly spreadsheets (previous month, or the current one during its last 3 business days). |
| `save session` / `зберегти сесію` | Saves a summary and the dialogue to `~\.kiro\work-planning`, so the next reports need fewer questions. |

Good habits:

- Say `save session` at the end of a working day; without saved sessions the agent has to
  ask you what you did on each day.
- **Check the Drive folder after a report is saved.** If Kiro shows no answer to a "create"
  step, the spreadsheet may still have been created; the agent should list the folder before
  retrying, and you should delete any empty duplicate it leaves.
- Reports are reviewed by managers: confirm the table before saying "save".

---

## 6. Updating

```powershell
git pull
```

then double-click **`windows\update.cmd`**, and start a new chat. Your `work-config.yaml`,
`folders.yaml` and `mcp.json` are not touched. If an installed `SKILL.md` was edited by hand,
it is backed up first.

---

## 7. Team rules and personal additions

- **Team rules** live in `windows/addenda/rules/<skill>.<rule>.md` and are appended to the
  matching skill on every install and update. Example: `weekly-report.work-days.md` adds the
  `Work days` / `Days off` rows. To add a rule for everyone, add a file here and open a PR.
- **Personal additions** (only for you) go into `~\.kiro\skill-addenda\<skill>.md`, outside the
  repo. They are appended last, survive updates, and are never committed.

### Work days / Days off

Both weekly and monthly reports end with two rows under the percentage block:

- **Work days**: every date with more than 0 hours counts as 1, including a worked weekend or
  official holiday.
- **Days off**: Mon-Fri days not worked because of an official Ukraine-team holiday (PTO
  calendar), your own day off, vacation or sick leave.
- A fully off week still needs no weekly report; the monthly report counts it as 5 Days off.

---

## 8. How the Windows adaptation works

| macOS/Linux (skills) | Windows + Kiro IDE (addenda) |
|----------------------|------------------------------|
| `date '+%Y-%m-%d %A %u'` | PowerShell one-liner with the same output; Sunday = 7, English day name |
| two-step `curl -o /dev/null -w "%{redirect_url}"` | `~\.kiro\scripts\Invoke-AppsScript.ps1 -Action ...` (same POST -> redirect -> GET) |
| `knowledge add` (Kiro CLI) | skipped and reported as skipped (not available in Kiro IDE) |
| `~/.kiro/work-log/` in the Friday check | `{work_log_dir}` from `work-config.yaml` |
| `sheets_mode` asked by setup but not used by the skills | `none` handled: chat + local copy, no Google calls |

---

## 9. Troubleshooting

| Problem | Fix |
|---------|-----|
| "running scripts is disabled on this system" | Use `install.cmd` / `update.cmd` / `check.cmd`, or run with `powershell -ExecutionPolicy Bypass -File ...`. |
| Helper prints `{"error":"folders.yaml not found ..."}` | Re-run `install.cmd` and choose option 1 or 2. |
| Ping fails / `Unexpected HTTP 404` | Wrong URL, or the deployment was removed. Copy the URL from Deploy -> Manage deployments. |
| Ping returns an HTML login page | "Who has access" is not "Anyone". Edit the deployment (new version), set Anyone. |
| Reports get many empty rows and two Total rows | `templateDataRows` is `5` in your Apps Script; set `35` and deploy a new version (step 1.5). |
| `update_cells` returns 403 | Share the root folder with the service account email as Editor. |
| Hours show as `7,5` | Set the spreadsheet locale to United States (step 1.4.5), also on the template. |
| Red triangles in the Deliverables column | Fix the dropdown values on the template (step 1.4.4). |
| MCP server does not start / `uvx` not found | Install uv, then restart Kiro IDE so `uvx` is on PATH. |
| MCP server fails with `No module named 'mcp.server.fastmcp'` | The `--with mcp==1.30.0` pin is missing; re-run `install.cmd` or fix the args (section 4). |
| Skill still mentions `curl` or `date` | The installed skill is old: run `update.cmd` and start a new chat. |

---

## 10. Not covered

- `link.sh` (maintainer symlinks) has no Windows port: file symlinks need admin rights or
  Developer Mode, and linking would bypass the addenda. Edit skills in the repo and run
  `update.cmd` instead.
- Kiro CLI on Windows is not tested; the addenda are written for Kiro IDE.
