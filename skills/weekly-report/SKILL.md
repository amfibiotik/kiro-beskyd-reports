---
name: weekly-report
description: "Generate weekly work report and save to Google Sheets. Use when: weekly report, звіт, report to sheets."
---

# Weekly Report

## When to Invoke
- User says "weekly report", "звіт", "report to sheets"
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
3. If today is **Saturday or Sunday (day 6-7)** → use **current week** (the week that just ended, Mon-Fri)
4. If today is **Mon-Thu (day 1-4)** → the request is ambiguous. Do NOT guess.
   The user may want the previous (finished) week, OR the current incomplete week
   (e.g. because the month ends mid-week and a monthly report needs those days, or
   an upcoming vacation means the week must be submitted early — reasons the skill
   cannot know). **ASK the user** which week they mean before proceeding:

   > Сьогодні {day}, тиждень ще не закінчився. Який тиждень формуємо?
   > 1 — поточний неповний тиждень (Пн-сьогодні: {mon}-{today})
   > 2 — минулий тиждень, що вже завершився ({prev_mon}-{prev_fri})
   > 3 — інший діапазон (вкажу дати)

   Wait for the answer. If option 1 → current week Mon..today. If option 2 →
   previous week Mon-Fri. If option 3 → use the dates the user gives.

   **Victor's stated default (learned 2026-10-12):** on a plain weekday request with
   no date, Victor almost always means the **previous finished week** (option 2). He
   only wants the current incomplete week when the month changes mid-week on a
   weekday — i.e. the current week straddles a month boundary and those early days
   must be closed for the monthly report. Absent such a month-change, assume he means
   the previous week. Still confirm briefly rather than silently guessing, but lead
   with option 2 as the expected answer.

### With `current week` / `цей тиждень` parameter:
- Always use current week Mon-Fri regardless of what day it is
- Report covers days up to today (or all Mon-Fri if today is Fri+)

### Week calculation:
- Week starts on **Monday** (ISO/Ukraine standard)
- Given today's date and day-of-week number (`%u`):
  - Current week Monday = today - (day_of_week - 1) days
  - Previous week Monday = current week Monday - 7 days
  - Friday = Monday + 4 days

### CRITICAL: Two distinct date concepts — do not confuse them
The skill tracks TWO separate things:
1. **Report days** — the actual working days that get ROWS in the table. For an
   incomplete current week this is Mon..today (e.g. only 28, 29, 30). Holidays,
   sick-leave, and future days are excluded.
2. **Week bounds** — the ISO Monday and Friday of the week the report belongs to.
   These are ALWAYS the full Mon and Fri, regardless of how many report days exist.

**Week bounds drive the spreadsheet title and the target month folder(s); report
days drive the table rows.** This separation is what lets a mid-week report and its
later Friday completion land in the SAME spreadsheet (see Step 6.2 and append mode).

Example — this week's report requested on Wed 30 Sep:
- Report days: 28, 29, 30 Sep (3 rows)
- Week bounds: Mon 28 Sep — Fri 2 Oct → title `... 28 September - 2 October 2026`,
  folders = September AND October (cross-month). On Friday the same title is
  regenerated, append adds 1 & 2 Oct to the same file.

### Holidays:
- Determine current year from `date` output
- Read `~/.kiro/holidays-{YYYY}.yaml` (e.g. `holidays-2026.yaml`)
- If file exists: skip holiday dates when generating report
- If file does NOT exist:
  - January 1 is always a holiday regardless
  - After January 2: ask user "Файл holidays-{YYYY}.yaml відсутній. Можливо, забули оновити? Можу допомогти створити."
- When starting a session, proactively mention if there's a holiday this week

### Missing days (no work-log, no Jira activity):
- Ask: "На [date] немає даних. Можливо sick-leave / лікарняний?"
- If user confirms sick-leave → skip that day entirely (no row in report)
- If user says they worked → ask what they did
- **NEVER offer a "don't remember / skip the day" option.** Every past working day was spent doing something — a day is either worked (ask what) or an official absence (sick-leave / vacation / day off). "Forgot" is not a valid outcome; keep asking until the day is accounted for.

### CRITICAL: Never guess dates. Always compute from `date` output.

## Config
Read `~/.kiro/work-config.yaml` for:
- `worker_id` (e.g. CW-0011)
- `activity` (e.g. "Soft. Dev")
- `default_hours` (e.g. 8)
- `projects` mapping (e.g. FOTL → "AI QA Tool")
- `full_name` (e.g. "John Doe") — used in spreadsheet titles

## Google Sheets Folder Structure

Read folder registry from `~/.kiro/skills/weekly-report/folders.yaml`.
This file maps month folder IDs for the current year. It contains personal Drive
IDs and is NOT committed to the repo — each user generates their own via setup.sh.

Format:
```yaml
apps_script_url: "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec"
template_id: "YOUR_TEMPLATE_ID"
# root_folder_id = top-level reports folder; holds one subfolder per YEAR.
# Month folders must NEVER be created directly here — they go inside year_folder_id.
root_folder_id: "YOUR_ROOT_FOLDER_ID"
# year = the year that year_folder_id and the months map below describe.
# year_folder_id = the subfolder for that year inside root. All month folders live here.
year: 2026
year_folder_id: "YOUR_YEAR_FOLDER_ID"
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
Read paths from `~/.kiro/work-config.yaml`:
- `work_log_dir` — daily logs (default: `~/.kiro/work-planning/work-log`)
- `sessions_dir` — session summaries (default: `~/.kiro/work-planning/sessions`)
- `legacy_sessions_dir` — old sessions (for historical data)

For each day in range:
1. Read `{work_log_dir}/YYYY-MM-DD.md` (primary source)
2. Scan `{sessions_dir}/YYYY-MM-DD-*-summary.md` for additional context
3. If work-log is missing for a day, also scan `{legacy_sessions_dir}/YYYY-MM-DD-*-summary.md`
4. If still no data, check Jira for tickets updated that day:
   - `jql: assignee = currentUser() AND updated >= "YYYY-MM-DD" AND updated < "YYYY-MM-DD+1"`
5. If still no data, ask the user what they did that day

### Step 2.1: Calendar Data (optional)
If user says "з календарем" / "with calendar", or if `calendar_flow_url` exists in work-config:
1. Ask user to:
   - Open flow: `{calendar_flow_url}` (from work-config)
   - Click "Run" (Запустити)
   - Open OneDrive → `{calendar_onedrive_path}` → copy file contents
   - Paste JSON here
2. Parse the JSON: extract meetings where `isAllDay: false` and `showAs != "free"`
3. Use meeting subjects to supplement Details column (e.g., "Meetings: Project Sync, 1-1 with Manager")
4. Skip: canceled events (subject starts with "Canceled:"), all-day events (sick leaves, vacations), events where user is optional attendee

### Step 3: Generate Report Table
Output format (tab-separated, ready for Google Sheets paste):

```
Worker ID	Date	Activity	Task Name	Project	Details	Deliverables	Time
CW-0011	06/08/2026	Soft. Dev	FOTL	AI QA Tool	FOTL-1236: designed Merged Allure Reports + Runs Tab feature	Source Code, Object Code, Documentation	8
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
| Deliverables | `Source Code, Object Code, Documentation` if code was written; `None` otherwise (research, meetings, demo prep, documentation-only days). **Only these two values** — never use partial combinations like "Documentation" or "Test Cases, Reports". |
| Time | From config: `default_hours` (usually 8) |

### Step 4: Split Days by Activity Type (Project)
Each working day is broken into one row per activity type, using the Project values
from the Active Project Override (`AFFIRM`, `Meeting`, `Onboarding`,
`Technical Design`, `Tooling/Automation`, or a new value for a new activity type).

- Read the day's work-log / sessions / Jira and propose how its hours split across
  activity types (e.g. 6h `AFFIRM` + 2h `Meeting`). Present the proposed split and
  let Viktor adjust before saving.
- A day that was clearly one activity type stays a single row.
- Task Name mirrors the Project value for these internal activity types (no Jira key).
- The percentage summary (Step 3.5) is a straight group-by of this split — do not
  re-estimate hours there.

### Step 3.5: Time Categorization (Percentage Summary)

**MANDATORY — manager requirement (set 2026-10-25, revised 2026-10-26).**
Every weekly and monthly report MUST include a percentage breakdown of time per
category, relative to total billed hours. This produces a small summary table that
is appended BELOW the Total row (see Step 6, sub-step "Write percentage summary").

**The categories ARE the distinct values of the Project column in the main table.**
This is no longer a free-text layer — it is a direct roll-up of the main table.
Meetings, onboarding, tooling, etc. appear as their own Project rows in the main
table (see Active Project Override), so they automatically become their own
percentage lines. Nothing is folded under `AFFIRM` that was not actually AFFIRM work.

**How to build the summary:**

1. **Categories = unique Project values** present in the main table for this report.
   Do NOT invent labels that differ from the Project column; the summary must match
   the table exactly (e.g. `AFFIRM`, `Meeting`, `Onboarding`, `Technical Design`,
   `Tooling/Automation`).

2. **Hours per category = sum of the Time column** across all main-table rows that
   share that Project value. Because the main table already splits multi-activity
   days into separate rows (per the override), this is a straight group-by, not a
   re-estimate.

3. **No separate split step / no user re-estimation here.** The hour allocation was
   already decided when the main table rows were built (Step 4). The summary just
   aggregates them. If the user wants to change the split, that is a change to the
   main-table rows, which then flows into the summary.

4. **Validation — the summary MUST reconcile:** the sum of per-category hours MUST
   equal the report's Total hours (the Check row). If it does not reconcile, the
   main table is wrong — fix the rows, never fudge the summary.

5. **Compute percentages** as `category_hours / total_hours`, rounded to the nearest
   whole percent. Rounding may make the displayed percents sum to 99% or 101% — that
   is acceptable; the Hours column is the source of truth and the Check row shows the
   real total. Do NOT fudge individual percents to force exactly 100%.

### Step 5: Present and Confirm
1. Show the generated main table to the user
2. Show the percentage summary table (categories, Hours, % of total, Check row)
3. Ask for corrections (to either table)
4. After confirmation, proceed to Step 6

### Step 6: Save to Google Sheets

1. **Determine target folder(s)** from `folders.yaml`:
   - Read the report's year from the report's END date (same year used in the title)
   - **Year check FIRST**: if the report's year != `year` in `folders.yaml`, perform **Year rollover** (see dedicated section below) before anything else. This creates the new year folder and resets the month map.
   - Determine cross-month by the WEEK BOUNDS (Monday and Friday of the report's
     ISO week), not by the days that happen to have rows. If Monday and Friday fall
     in different months → this is a **cross-month week**.
   - **CRITICAL — cross-month single-file rule (do NOT create two copies):**
     A cross-month week's report lives in ONLY ONE folder at a time. Never write the
     same report into both month folders — that creates divergent duplicates.
     - **Ending month** = the month of the week's Monday (the month that is finishing).
     - **New month** = the month of the week's Friday (the month that is starting).
     - **CREATE (first run of the week, typically mid-week):** write the report ONLY
       into the **ending month** folder. Additionally, create the **new month** folder
       ahead of time (empty, no spreadsheet) so it exists in `folders.yaml` for later.
     - **APPEND (completing the week, typically Friday):** see Step 3 append rules —
       the existing file is read from the **ending month** folder, and the completed
       full report is written into the **new month** folder. The old copy in the
       ending month is left in place (not deleted); it is fine that it stays partial.
   - For a normal (same-month) week: single folder = that month.
   - Look up folder ID(s) from `folders.yaml` `months` map
   - If a needed month folder doesn't exist yet, create it via Apps Script inside `year_folder_id` (see step 8)

   **Why this design:** the monthly-report skill aggregates by the DATES inside the
   tables (not by which folder holds a file), so a cross-month week ending up in the
   new month's folder does not lose the previous month's days — the monthly report
   still finds them by date. Keeping one file avoids the divergence bug where a user
   edits one copy and the other goes stale.

2. **Generate spreadsheet title**:
   - **CRITICAL: The title is computed from the WEEK BOUNDS (ISO Monday..Friday of
     the report's week), NOT from the actual report days.** This keeps the title
     stable across the week so a mid-week report and its Friday completion resolve
     to the same file (enabling append mode). Do NOT build the title from the first
     and last day that happen to have rows.
   - Same month: `Report by {full_name} DD - DD Month YYYY`
     - Example: `Report by John Doe 8 - 12 June 2026`
   - Cross-month: `Report by {full_name} DD Month - DD Month YYYY`
     - Example: `Report by John Doe 27 April - 1 May 2026`
   - `full_name` is read from `~/.kiro/work-config.yaml`
   - Use the END date's year in the title (END = the week's Friday)
   - Month folder is chosen from the week bounds and the CREATE/APPEND phase, per the
     cross-month single-file rule in Step 6.1: a cross-month week goes in ONE folder
     at a time (ending month on CREATE, new month on APPEND), never both at once.

3. **Check if spreadsheet already exists (append mode)**:

   **First, pick which folder to search for the existing file:**
   - **Same-month week:** search the single month folder (that month).
   - **Cross-month week:** search the **ending month** folder (the month of the week's
     Monday). That is where the mid-week CREATE placed the file. Do NOT search the new
     month folder for the source — it was intentionally left empty on CREATE.

   - List spreadsheets in that folder using `list_spreadsheets`
   - Search for a spreadsheet with the EXACT title generated in step 2
   - **If found** → this is an APPEND operation:
     a. Read existing data with `get_sheet_data` (sheet: "Sheet1")
     b. Parse existing rows — extract dates already present (skip header + Total row)
     c. **Detect template placeholder rows**: rows where Date column is empty but other columns have template values (e.g., Deliverables pre-filled) are placeholders — treat them as empty, not as data to preserve
     d. **NEVER modify existing DATA rows** (rows with a filled Date) — keep them exactly as-is, byte-for-byte
     e. From the new report data, keep ONLY rows for dates NOT already in the spreadsheet
     f. If no new dates to add → inform user "Цей тиждень вже повністю в звіті, нових днів нема" and stop
     g. Merge: existing data rows (with dates) + new data rows, sort all by date
     h. Recalculate Total (sum of ALL hours — old + new)
     i. **Where to WRITE the merged result depends on the week type:**
        - **Same-month week:** write back into the SAME file that was found (true
          in-place append). Use `update_cells` range `A1:H{new_last_row}`.
        - **Cross-month week:** do NOT overwrite the file in the ending month. Instead
          CREATE a new spreadsheet in the **new month** folder (same title) via Apps
          Script, trim rows to the merged day count, and write the full merged result
          there. Leave the ending-month file untouched (it stays partial — that is
          expected and fine; the monthly report aggregates by date, not by folder).
          If a file with that title already exists in the new month folder (e.g. this
          is the 2nd append), treat that as the in-place target instead of creating a
          duplicate.
     j. Write: header + data rows + Total row. **No empty rows between data and Total.** Total row count = actual working days only.
     j2. **Recompute and rewrite the percentage summary block** (Step 6.5) for the FULL
        merged set of days — the old block from the partial file is now at the wrong
        position and has stale hours. Clear the old block area and write the fresh
        block below the new Total row. Re-run Step 3.5 categorization over all merged
        days (reuse the existing per-day category split where possible; ask the user
        only about the newly added days).
     k. **Clean up leftover rows** in whichever file you wrote: if it had more rows (template placeholders or an old summary block), clear any rows below the new last row (the new last row is the Check row of the summary block).
     l. Report which file was updated/created and its URL. For cross-month: state
        clearly that the completed report now lives in the {new month} folder and the
        partial copy remains in {ending month}.
   - **If not found** → this is a CREATE operation (proceed to step 4). For cross-month
     CREATE, the target folder is the **ending month** (see Step 6.1).

4. **Create spreadsheet via Apps Script Web App** (only if step 3 determined CREATE):
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
   - This creates the file owned by the user's account (no quota issues)

5. **Trim unused rows** (ALWAYS for CREATE — the template has 35 slots):
   - The template has 35 data row slots (rows 2-36) + Total (row 37).
   - **ALWAYS call trim_rows BEFORE writing data**, for ANY day count (even a full
     5-day week), because the template now leaves many empty slots. Pass the actual
     number of data rows (working days in this report):
     ```bash
     REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" -X POST "$APPS_SCRIPT_URL" \
       -H "Content-Type: application/json" \
       -d '{"action": "trim_rows", "spreadsheet_id": "...", "data_rows": 5}')
     curl -s "$REDIRECT_URL"
     ```
   - Response: `{"spreadsheet_id": "...", "rows_deleted": 30, "total_rows": 7}`
   - trim_rows deletes `35 - data_rows` empty slots so Total sits right after the last data row.
   - This removes empty placeholder rows so Total sits right after the last data row
   - **Why before writing**: template rows have dropdown validation (Deliverables column). If Total lands on a row with validation, update_cells fails silently. Trimming first removes those validated cells.
   - Never skip trimming — with a 35-slot template every report has empty slots to remove.

6. **Write data** using `update_cells` (MCP tool, works via service account with shared access):
   - Row 1: headers `["Worker ID", "Date", "Activity ", "Task Name", "Project", "Details", "Deliverables", "Time"]`
     - Note: "Activity " has a trailing space (matches existing format)
   - Rows 2-N: data rows
   - Last row: Total row — empty cells for columns A-F, "Total" in G, sum in H
   - Range: `A1:H{last_row}`
   - **CRITICAL: Date values must be prefixed with apostrophe** (`'07/01/2026`) to force Google Sheets to treat them as text. Without this, Sheets may auto-detect dates and reformat them according to the document's locale (e.g., DD/MM/YYYY instead of MM/DD/YYYY).
   - **CRITICAL: Total row position** — the Total row MUST be exactly N+1 where N = number of data rows (immediately after the last day). Never leave empty rows between data and Total. If a week has fewer than 5 working days (holidays, sick leave), the report has fewer rows — Total still goes right after the last day.

6.5. **Write percentage summary block** (MANDATORY — manager requirement, see Step 3.5):
   - After the Total row, append the category breakdown produced in Step 3.5 as a
     small table of plain values (no formulas).
   - Let **R** = the spreadsheet row of the Total row = N+2 (header + N day rows + Total).
   - **Column mapping** — place the block in columns **F, G, H** so the percentages
     sit under the Time column:
       - Col F = category label (and the word `Check` on the final row)
       - Col G = hours for that category
       - Col H = percent string (e.g. `91%`)
     - Header row of the block: F=`Category`, G=`Hours`, H=`% of total`
     - One row per category: F=label, G=hours, H=`{rounded}%`
     - Final row: F=`Check`, G=`{sum of category hours}`, H=`100%`
   - **Row positions** (R = Total row = N+2):
     - R+1: empty separator row
     - R+2: block header (`Category` / `Hours` / `% of total`)
     - R+3 .. R+2+K: K category rows
     - R+3+K: Check row
   - **Write with `update_cells`** over range `F{R+2}:H{R+3+K}` (block header through
     Check). Hours are plain numbers; percent is a text string with a trailing `%`.
     Do NOT prefix these with an apostrophe (they are not dates).
   - **No formatting is applied to this block in this version** (plain values only).
     The template's pre-formatting was trimmed away below the Total row, so the block
     will appear unstyled. This is the agreed first iteration; styling (bold header,
     borders) may be added later via an Apps Script action if the manager requires it.
   - **Reconciliation check before writing**: the sum of category hours (Check G value)
     MUST equal the report's Total hours. If not, stop and fix the split — never write
     a block whose Check ≠ Total.

7. **Cross-month reports — single-file rule (replaces the old "both folders" behavior)**:
   - A cross-month week is stored in ONE folder at a time. NEVER write the same report
     into both month folders — that caused divergent duplicates (one edited, one stale).
   - **CREATE (mid-week first run):** write ONLY into the ending-month folder (month of
     the week's Monday). Also create the new-month folder ahead of time, EMPTY.
   - **APPEND (Friday completion):** read the existing file from the ending-month folder,
     merge the new days, and write the completed full report into the NEW-month folder
     (month of the week's Friday). Leave the ending-month copy in place (partial is fine).
   - The completed week thus ends up in the new month's folder, containing both the
     previous month's days and the new month's days. This is intentional: the
     monthly-report skill selects rows by DATE, so both months' aggregates stay correct.

8. **Creating new month folders** (when needed):
   - A month folder ALWAYS goes inside the current `year_folder_id` — NEVER inside `root_folder_id`.
   - Use same two-step curl pattern with:
     `{"action": "create_folder", "name": "07-July", "parent_id": "{year_folder_id}"}`
     (read `year_folder_id` from `folders.yaml`)
   - Response: `{"folder_id": "...", "name": "..."}`
   - Update `folders.yaml` with the new month entry under `months`

9. **Report success** with the spreadsheet URL(s)

### Year Rollover (automatic, works for any future year)

Triggered from Step 6.1 whenever a report's year does not match `year` in `folders.yaml`
(e.g. first report of 2027, then 2028, and so on). Do NOT hardcode any specific year —
always derive it from the report date. Steps:

1. **Create the year folder** inside `root_folder_id` via Apps Script:
   ```bash
   REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" -X POST "$APPS_SCRIPT_URL" \
     -H "Content-Type: application/json" \
     -d '{"action": "create_folder", "name": "{YYYY}", "parent_id": "{root_folder_id}"}')
   curl -s "$REDIRECT_URL"
   ```
   - `name` is the 4-digit year (e.g. `2027`); `parent_id` is `root_folder_id` from `folders.yaml`.
   - Response: `{"folder_id": "...", "name": "..."}` — this new `folder_id` becomes the year folder.
2. **Safety check before creating**: a folder with the same name may already exist (e.g. the user
   created it manually). Prefer to reuse it rather than make a duplicate. If unsure whether one
   already exists, ask the user for the year folder ID instead of blindly creating a second one.
3. **Rewrite `folders.yaml`** for the new year:
   - Set `year:` to the new year.
   - Set `year_folder_id:` to the folder_id from step 1.
   - Reset `months:` to empty (`months: {}`) — month folders will be created on demand as reports come in.
   - Leave `root_folder_id`, `apps_script_url`, `template_id` unchanged.
4. **Then continue** the normal flow: create the needed month folder inside the new `year_folder_id`
   (Step 8), then create the spreadsheet.

**Note on folder IDs and moving:** Google Drive folder IDs are permanent. Moving a folder only
changes its parent, never its ID — so once `folders.yaml` records an ID, manual reorganizing in
Drive does not break anything. This is why month/year folders must be created with the correct
`parent_id` up front (year folder → inside root; month folder → inside year folder).

### Step 7: Save Local Copy
Save the final report to `{reports_dir}/YYYY-WNN-weekly.md` (e.g. `2026-W29-weekly.md`) for reference.
Read `reports_dir` from work-config.yaml (default: `~/.kiro/work-planning/reports`).

## Important
- All text in Details column must be in English
- Date format in cells: `MM/DD/YYYY` (US format). **Always prefix with apostrophe** when writing to Google Sheets (`'07/01/2026`) to prevent locale-based date reformatting.
- **Date validation**: Before writing ANY date, verify it's MM/DD/YYYY (month first, not day). If month position has value > 12 — it's clearly wrong. If ambiguous (e.g., `08/06/2026`) — cross-check against the week's expected dates. Alert user if a mismatch is detected in existing reports.
- If work-log data is sparse, supplement from Jira and git log
- Never fabricate work — if a day has no data, ask the user
- Only ONE sheet per spreadsheet (Sheet1) — no extra sheets
- The spreadsheet should contain ONLY the report data (no formulas, no extra formatting) so Excel export is clean
- **Business value justification**: If an activity is NOT a Jira ticket or planned company task (e.g., workspace setup, personal tooling, automation skills, productivity improvements), add a brief parenthetical explaining its value to the company. Example: "Created reporting automation skill for use with Kiro CLI. (Within the scope of automating routine operations and possible long-term analysis of work patterns)."
- **No raw technical metrics in Details**: Do not include raw numbers, file counts, byte sizes, or internal diagnostic data (e.g., "27 files, 120KB"). Report the action and outcome only (e.g., "audited S3 cache, no action needed"). The report audience is management, not engineers.
- **One ticket per line in Details cell**: Each new ticket mention (FOTL-XXXX, CRUE-XXXX, etc.) starts on a new line within the same cell. This improves readability in the spreadsheet. **CRITICAL**: Use actual newline characters in the JSON data array (multi-line string), NOT literal `\n` escape sequences. Google Sheets renders real newlines as line breaks inside cells, but literal `\n` text shows as visible characters.

## Active Project Override (set 2026-10-19 by Viktor, revised 2026-10-26)

**Supersedes the earlier "everything under one AFFIRM row" rule.**

Manager requirement (2026-10-26): the **Project column of the
main table** must break work down by activity type. Meetings, onboarding,
technical-design writing, tooling, etc. are NOT logged under `AFFIRM` — each gets
its own Project value and its own hours. The percentage summary is then derived
directly from the Project column (see Step 3.5), not from free-text labels.

**Project categories Viktor currently uses** (this is a starting set, not a closed
list — new activity types get new Project values as they appear):

| Project value        | Covers |
|----------------------|--------|
| `AFFIRM`             | Development / direct work on the AFFIRM product |
| `Onboarding`         | Onboarding, studying the project, reading docs |
| `Technical Design`   | Writing technical design documents (TD) |
| `Tooling/Automation` | Dev environment setup, Kiro skills, routine automation |
| `Meeting`            | Meetings, stand-ups |

Rules:
- Viktor's finished/handed-off projects (BCPD, CRUE, FOTL) MUST NOT appear.
- Task Name follows the Project: use the same category value (e.g. Project
  `Meeting` → Task Name `Meeting`). There is no Jira key for these internal
  activity types.
- **A day is split into multiple rows when it contained multiple activity types**
  (e.g. 6h AFFIRM development + 2h Meeting = two rows). Hours are split per the
  actual work; propose a split from the work-log/sessions and let Viktor adjust.
  A day that was clearly one activity type stays a single row.
- `Tooling/Automation` and similar non-Jira work still need the brief business-value
  parenthetical in Details (see "Business value justification" above).
- **ASK before placing tooling / Kiro-skill / environment-setup hours (do NOT decide
  silently).** When a week contains hours spent writing Kiro skills, setting up the
  dev environment, or similar internal automation, STOP and ask Viktor how to handle
  them for that specific report — whether to show them as their own
  `Tooling/Automation` line or fold them into another category (e.g. `Onboarding`),
  and how to word the Details. Do NOT hardcode a fixed rule: the right answer changes
  over time (e.g. folding into `Onboarding` only makes sense while onboarding is
  current). There is intentionally no default here — always ask.
- This category list and the split rule stay in effect until Viktor changes them.
