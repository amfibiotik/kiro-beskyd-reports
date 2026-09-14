# Google Setup Guide

Step-by-step guide to set up Google integration for `/weekly-report`.

## Overview

You need:
1. A Google Cloud project with Sheets API enabled + a service account
2. A Google Drive folder structure for reports
3. A template spreadsheet
4. An Apps Script Web App that creates spreadsheets from the template

---

## Step 1: Create Google Cloud Project & Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (e.g., "Kiro Weekly Reports")
3. Enable **Google Sheets API**:
   - APIs & Services → Library → search "Google Sheets API" → Enable
4. Create a Service Account:
   - APIs & Services → Credentials → Create Credentials → Service Account
   - Name: `kiro-sheets` (or any name)
   - Skip optional permissions
5. Create a key:
   - Click on the service account → Keys → Add Key → Create new key → JSON
   - Download the JSON file
   - Save it somewhere safe (e.g., `~/.config/kiro-sheets-sa.json`)

**Important**: This JSON file is your "password". Never commit it to git.

The service account email will look like: `kiro-sheets@your-project.iam.gserviceaccount.com`

---

## Step 2: Configure Kiro CLI MCP (google-sheets tool)

Add the google-sheets MCP server to your Kiro CLI config with the service account credentials.
Refer to Kiro CLI documentation for MCP server configuration.

The service account JSON path goes into the MCP config so that `update_cells` tool works.

---

## Step 3: Create Drive Folder Structure

The reports use a two-level structure: a **root** folder that holds one **year**
folder per year, and month subfolders created automatically inside the current year.

```
Weekly Reports/            ← root_folder_id
└── 2026/                  ← year_folder_id (one per year)
    ├── 01-January/        ← month folders (auto-created by the skill)
    ├── 02-February/
    └── ...
```

1. In Google Drive, create the root folder, e.g. `Weekly Reports`
2. Inside it, create the current year folder, e.g. `2026`
3. Copy BOTH folder IDs from their URLs: `https://drive.google.com/drive/folders/THIS_IS_THE_ID`
   - root folder ID → `root_folder_id`
   - year folder ID → `year_folder_id`
4. Share the **root** folder with your service account email (Editor access):
   - Right-click folder → Share → paste SA email → Editor
   - (sharing the root also covers the year and month subfolders inside it)
5. Month subfolders are created automatically by the skill, inside the year folder.
   On the first report of a new year, the skill also creates the next year folder
   automatically (see "Year Rollover" in the skill) — no manual work needed.

---

## Step 4: Template Spreadsheet

**Beskyd team**: use the shared template (already has correct headers + formatting):
- ID: `1QFF7_g70qDo7AFXVrfkn5Q-YodxcxWcjSXqqoMP-1hs`
- [Open template](https://docs.google.com/spreadsheets/d/1QFF7_g70qDo7AFXVrfkn5Q-YodxcxWcjSXqqoMP-1hs/edit)
- Share it with your service account email (Viewer is enough)

**Or create your own**:
1. Create a new Google Spreadsheet
2. Set up the header row in A1:H1:
   ```
   Worker ID | Date | Activity  | Task Name | Project | Details | Deliverables | Time
   ```
   (Note: "Activity " has a trailing space — matches existing format)
3. Optionally set column widths, formatting, etc.
4. Copy the spreadsheet ID from its URL
5. Share this spreadsheet with your service account email (Viewer is enough)

---

## Step 5: Deploy Apps Script Web App

1. Go to [script.google.com](https://script.google.com) → New project
2. Replace the contents of `Code.gs` with the code from `google/apps-script.gs` in this repo
3. **Replace `__YOUR_TEMPLATE_SPREADSHEET_ID__`** with the ID from Step 4
4. Save (Ctrl+S)
5. Deploy:
   - Deploy → New deployment
   - Type: Web app
   - Execute as: **Me**
   - Who has access: **Anyone**
6. Click Deploy → Authorize (grant Drive access when prompted)
7. Copy the Web App URL

---

## Step 6: Run setup.sh

Now you have all the values needed:
- Worker ID (from your company)
- Full name
- Apps Script URL (from Step 5)
- Template spreadsheet ID (from Step 4)
- Root folder ID (from Step 3)
- Current year folder ID (from Step 3)
- Service account JSON path (from Step 1)

Run `bash setup.sh` and provide these when prompted.

---

## Verification

After setup, test with Kiro CLI:
```
> weekly report current week
```

It should:
1. Determine the current week dates
2. Check work logs for those days
3. Generate a report table
4. After confirmation, create a spreadsheet in your Drive folder

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `update_cells` returns 403 | Share the spreadsheet/folder with the service account email (Editor) |
| Apps Script returns error | Check that TEMPLATE_ID is correct and template is shared with your account |
| Curl returns empty response | Use the two-step redirect pattern (POST → follow redirect → GET) |
| Month folder not created | Check that root_folder_id in folders.yaml matches your Drive folder |
