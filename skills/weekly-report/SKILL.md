---
name: weekly-report
description: "Generate weekly work report and save to Google Sheets. Use when: weekly report, звіт за тиждень, report to sheets."
---

# Weekly Report

## When to Invoke
- User says "weekly report", "звіт за тиждень", "report to sheets"
- With date parameter (any of these formats):
  - `last week` / `минулий тиждень` — previous Mon-Fri
  - `current week` / `this week` / `цей тиждень` / `поточний тиждень` — current week Mon-Fri (even if incomplete)
  - `June 8-12` / `8-12 червня` — explicit date range
  - `June 8` / `8 червня` — Monday date, calculate full week (Mon-Fri)

## MANDATORY: Date Determination Rules

**ALWAYS run `date '+%Y-%m-%d %A %u'` first** to get the actual current date and day of week (1=Mon, 7=Sun).

### Default behavior (no date parameter):
1. Run `date` system command — NEVER rely on model's internal date knowledge
2. If today is **Friday (day 5)** AND a saved session exists for today (`~/.kiro/work-log/YYYY-MM-DD.md`):
   → use **current week** (Mon-Fri of this week)
3. Otherwise → use **previous week** (Mon-Fri of last week)

### With `current week` / `цей тиждень` parameter:
- Always use current week Mon-Fri regardless of what day it is
- Report covers days up to today (or all Mon-Fri if today is Fri+)

### Week calculation:
- Week starts on **Monday** (ISO/Ukraine standard)
- Given today's date and day-of-week number (`%u`):
  - Current week Monday = today - (day_of_week - 1) days
  - Previous week Monday = current week Monday - 7 days
  - Friday = Monday + 4 days

### Holidays:
- Read `~/.kiro/holidays-2026.yaml` for official non-working days
- Skip these dates when generating report (don't ask user what they did)
- When starting a session, proactively mention if there's a holiday this week

### Missing days (no work-log, no Jira activity):
- Ask: "На [date] немає даних. Можливо sick-leave / лікарняний?"
- If user confirms sick-leave → skip that day entirely (no row in report)
- If user says they worked → ask what they did

### CRITICAL: Never guess dates. Always compute from `date` output.

## Config
Read `~/.kiro/work-config.yaml` for:
- `worker_id` (e.g. CW-0011)
- `activity` (e.g. "Soft. Dev")
- `default_hours` (e.g. 8)
- `projects` mapping (e.g. FOTL → "AI QA Tool")

## Google Sheets Folder Structure

Read folder registry from `~/.kiro/skills/weekly-report/folders.yaml`.
This file maps month folder IDs for the current year.

Format:
```yaml
apps_script_url: "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec"
root_folder_id: "YOUR_ROOT_FOLDER_ID"
year: 2026
months:
  1: {id: "FOLDER_ID", name: "01-January"}
  2: {id: "FOLDER_ID", name: "02-February"}
  # ... created as needed
```

When a new month folder is created, update this file with the new folder ID.

## Process

### Step 1: Determine Date Range
- Apply "MANDATORY: Date Determination Rules" above
- If user specifies explicit dates, use those
- Skip weekends and known holidays

### Step 2: Gather Data
For each day in range:
1. Read `~/.kiro/work-log/YYYY-MM-DD.md` (primary source)
2. If work-log is missing for a day, check Jira for tickets updated that day:
   - `jql: assignee = currentUser() AND updated >= "YYYY-MM-DD" AND updated < "YYYY-MM-DD+1"`
3. If still no data, ask the user what they did that day

### Step 3: Generate Report Table
Output format (tab-separated, ready for Google Sheets paste):

```
Worker ID	Date	Activity	Task Name	Project	Details	Deliverables	Time
CW-0011	06/08/2026	Soft. Dev	FOTL	AI QA Tool	FOTL-1236: designed feature X	Source Code, Object Code, Documentation	8
```

Last row (Total row):
```
						Total	{sum of hours}
```

### Column Rules

| Column | Rule |
|--------|------|
| Worker ID | From config: `worker_id` |
| Date | `MM/DD/YYYY` format (US format, as used in existing reports) |
| Activity | From config: `activity` |
| Task Name | Jira project key (FOTL, ECS, SIPBEE, etc.) |
| Project | Human name from config `projects` mapping. If unknown key, ask user. |
| Details | 1-2 sentences, English, start with ticket ID if applicable |
| Deliverables | `Source Code, Object Code, Documentation` if code was written; `None` if research/setup/meetings only |
| Time | From config: `default_hours` (usually 8) |

### Step 4: Handle Multi-Project Days
If a day has work on multiple projects, create separate rows splitting hours (ask user for split if unclear).

### Step 5: Present and Confirm
1. Show the generated table to the user
2. Ask for corrections
3. After confirmation, proceed to Step 6

### Step 6: Save to Google Sheets

1. **Determine target folder(s)** from `folders.yaml`:
   - Read the month number from the report's start date
   - If cross-month (e.g. "27 April - 1 May"), the file goes in BOTH month folders
   - Look up folder ID(s) from `folders.yaml`
   - If a month folder doesn't exist yet, create it via Apps Script (see below)

2. **Generate spreadsheet title**:
   - Same month: `Report by {full_name} DD - DD Month YYYY`
   - Cross-month: `Report by {full_name} DD Month - DD Month YYYY`
   - `full_name` is read from `~/.kiro/work-config.yaml`
   - Use the END date's year in the title

3. **Create spreadsheet via Apps Script Web App**:
   - Read `apps_script_url` from `folders.yaml`
   - Call Apps Script using two-step curl (Google redirects POST to a response URL):
     ```bash
     # Step 1: POST to get redirect URL
     REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" -X POST "$APPS_SCRIPT_URL" \
       -H "Content-Type: application/json" \
       -d '{"action": "create_spreadsheet", "title": "...", "folder_id": "..."}')
     # Step 2: GET the redirect URL to receive the JSON response
     curl -s "$REDIRECT_URL"
     ```
   - Response: `{"spreadsheet_id": "...", "url": "..."}`
   - This creates the file owned by user's account (no quota issues)

4. **Write data** using `update_cells` (MCP tool, works via service account with shared access):
   - Row 1: headers `["Worker ID", "Date", "Activity ", "Task Name", "Project", "Details", "Deliverables", "Time"]`
     - Note: "Activity " has a trailing space (matches existing format)
   - Rows 2-N: data rows
   - Last row: Total row — empty cells for columns A-F, "Total" in G, sum in H
   - Range: `A1:H{last_row}`

5. **For cross-month reports**: create the same spreadsheet in both month folders
   (two separate Apps Script calls with different folder IDs, same data written to each)

6. **Creating new month folders** (when needed):
   - Use same two-step curl pattern with:
     `{"action": "create_folder", "name": "07-July", "parent_id": "{root_folder_id}"}`
   - Response: `{"folder_id": "...", "name": "..."}`
   - Update `folders.yaml` with the new month entry

7. **Report success** with the spreadsheet URL(s)

### Step 7: Save Local Copy
Save the final report to `~/.kiro/work-log/reports/YYYY-MM-DD-weekly.md` for reference.

## Important
- All text in Details column must be in English
- Date format in cells: `MM/DD/YYYY` (US format)
- If work-log data is sparse, supplement from Jira and git log
- Never fabricate work — if a day has no data, ask the user
- Only ONE sheet per spreadsheet (Sheet1) — no extra sheets
- The spreadsheet should contain ONLY the report data (no formulas, no extra formatting) so Excel export is clean
- **Business value justification**: If an activity is NOT a Jira ticket or planned company task (e.g., workspace setup, personal tooling, automation skills, productivity improvements), add a brief parenthetical explaining its value to the company.
