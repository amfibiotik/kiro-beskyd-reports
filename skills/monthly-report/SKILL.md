---
name: monthly-report
description: "Generate monthly work report by aggregating weekly reports from Google Sheets. Use when: monthly report, місячний звіт, report for month."
---

# Monthly Report

## When to Invoke
- User says "monthly report", "місячний звіт", "report for month"
- No parameters — always generates report for the previous month (or current month if it's the last business day)

## Overview

Aggregates all weekly reports for a given month from Google Sheets into a single monthly spreadsheet. Data source is exclusively Google Sheets (not local text files), because users may have manually edited weekly reports there.

## MANDATORY: Date Determination

**ALWAYS run `date '+%Y-%m-%d %A %u'` first.**

### Target Month Logic:
1. Get today's date
2. If today is within the **last 3 business days** of the current month → target = current month
3. Otherwise → target = previous month

Example: Today is July 1 → target = June 2026.
Example: Today is June 29 (Monday, last business day of June) → target = June 2026.

### Business Days Calculation:
- Exclude weekends (Sat, Sun)
- Read `~/.kiro/holidays-{YYYY}.yaml` for holidays (if exists)

## Config

Read from `~/.kiro/work-config.yaml`:
- `worker_id`
- `activity`
- `default_hours`
- `projects` mapping
- `full_name` (used in spreadsheet titles)

Read from `~/.kiro/skills/weekly-report/folders.yaml`:
- `apps_script_url`
- `root_folder_id`
- `months` → folder IDs per month

## Process

### Step 1: Check for Missing Weekly Report

Before aggregating, verify that all business days of the target month are covered by existing weekly reports.

1. Determine all business days in the target month (Mon-Fri minus holidays)
2. List all spreadsheets in the target month's folder from `folders.yaml`
3. Read each weekly spreadsheet → collect all dates (from Date column, `MM/DD/YYYY` format)
4. Also check next month's folder for cross-month reports containing target month dates
5. Compare: are there business days in the target month NOT covered by any weekly report?

**If days are missing AND they belong to a cross-month week (last week of the month):**
- This is the typical edge case (e.g., June 29-30 missing, week is June 29 - July 3)
- Monthly-report handles this SELF-CONTAINED — no need to ask user to run `/weekly-report` separately
- Gather data for the missing target-month days only:
  - Read `{work_log_dir}/YYYY-MM-DD.md` for each missing date (path from work-config.yaml)
  - Also scan `{sessions_dir}/YYYY-MM-DD-*-summary.md` for context
  - If work-log missing, check `{legacy_sessions_dir}/YYYY-MM-DD-*-summary.md`
  - If still no data, check Jira: `assignee = currentUser() AND updated >= "YYYY-MM-DD" AND updated < "YYYY-MM-DD+1"`
  - If still no data AND date ≤ today → ask user what they did
  - If date > today → skip silently (hasn't happened yet)
  - **Skip days that belong to a different month** — silently, without asking
- Generate rows for those days (same format as weekly-report)
- Save them to the appropriate weekly spreadsheet using append mode:
  - Find or create the cross-month weekly spreadsheet (title: "Report by {full_name} DD Month - DD Month YYYY")
  - If spreadsheet exists → append new rows (never modify existing rows)
  - If spreadsheet doesn't exist → create it with only the target-month days
- Continue to Step 2 (the newly saved data will now be read from Google Sheets)

**If a full non-cross-month week is entirely missing:**
- Stop and ask: "Тижневий звіт за [dates] відсутній. Виконай /weekly-report спершу."

**Edge case: Cross-month week where future days don't exist yet:**
- If today is July 1 and the week is June 29 - July 3:
  - June 29, 30 belong to target month (June) — collect data for these
  - July 1-3 are in a different month — skip silently regardless of whether it's today or future
  - DO NOT require data for non-target-month days

### Step 2: Read All Weekly Reports from Google Sheets

For each spreadsheet in the target month's folder:
1. Read all data using `get_sheet_data` (sheet: "Sheet1")
2. Parse rows (skip header row, skip Total row)
3. Filter: keep ONLY rows where the Date falls within the target month
   - Parse date from `MM/DD/YYYY` format
   - Check: does this date's month match target month?
   - This handles cross-month weekly reports correctly (e.g., "27 April - 1 May" in May folder — only keep May dates)

Also check the NEXT month's folder for cross-month reports that may contain days from the target month:
- If next month folder exists in `folders.yaml`, list its spreadsheets
- Look for reports whose title contains the target month name (e.g., "29 June - 3 July" would be in July folder but contains June dates)
- Read those and filter for target month dates only

### Step 3: Sort and Deduplicate

1. Collect all filtered rows from all weekly reports
2. Sort by date (ascending)
3. Deduplicate: if same date appears in multiple reports (e.g., cross-month duplicates in both month folders), keep ONE copy — prefer the version from the target month's folder (as user may have edited it there)

### Step 4: Calculate Total

- Sum the "Time" column for all rows
- This should be `business_days_covered × default_hours` (but use actual values from reports, not calculated)

### Step 5: Present Report

Show the aggregated table to the user:
- All rows sorted by date
- Total hours at the bottom
- Count of business days covered

Ask: "Все вірно? Зберігаю?"

### Step 6: Save to Google Sheets

1. **Target folder**: same month folder from `folders.yaml` where weekly reports live

2. **Spreadsheet title**: `Report by {full_name} {Month} {YYYY}`
   - Example: `Report by John Doe June 2026`

3. **Create spreadsheet** via Apps Script Web App (same as weekly-report):
   ```bash
   # Step 1: POST to get redirect URL
   REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" -X POST "$APPS_SCRIPT_URL" \
     -H "Content-Type: application/json" \
     -d '{"action": "create_spreadsheet", "title": "...", "folder_id": "..."}')
   # Step 2: GET the redirect URL to receive the JSON response
   curl -s "$REDIRECT_URL"
   ```

4. **Write data** using `update_cells` MCP tool:
   - Row 1: headers `["Worker ID", "Date", "Activity ", "Task Name", "Project", "Details", "Deliverables", "Time"]`
   - Rows 2-N: all aggregated data rows (sorted by date)
   - Last row: Total row — empty cells for columns A-F, "Total" in G, sum of hours in H
   - Range: `A1:H{last_row}`

5. **Report success** with the spreadsheet URL

### Step 7: Save Local Copy

Read `reports_dir` from `~/.kiro/work-config.yaml` (default: `~/.kiro/work-planning/reports`).
Save to `{reports_dir}/YYYY-MM-monthly.md` with:
- Month and year
- Total hours
- Total business days
- Count of rows

## Important Rules

- **Data source is Google Sheets ONLY** — never use local text copies of weekly reports. Users edit Google Sheets manually and those edits must be captured.
- **Date format in cells**: `MM/DD/YYYY` (US format, consistent with weekly reports)
- **Date validation**: When reading weekly reports, verify dates are MM/DD/YYYY. If first position > 12 — clearly DD/MM error, alert user. If ambiguous (e.g., `08/06/2026`) — cross-check: does this date match the week range in the spreadsheet title? If not — alert user and ask how to proceed. Never silently copy wrong-format dates into the monthly report.
- **Only ONE sheet** per spreadsheet (Sheet1)
- **No formulas, no extra formatting** — plain values only
- **Preserve exact text** from weekly reports — do NOT rewrite, summarize, or modify Details column content. Copy rows byte-for-byte as they appear in Google Sheets, even if you see typos or inconsistencies.
- **Cross-month logic**: when a weekly report spans two months, include only the days belonging to the target month
- **Total row format**: matches weekly report format exactly (empty cells A-F, "Total" in G, hours in H)
- **Never fabricate data** — if something looks wrong, ask the user
- **One ticket per line** rule from weekly reports carries over — don't merge or reformat multi-line Details cells. When writing to Google Sheets, use actual newline characters in JSON data arrays (not literal `\n` text).
