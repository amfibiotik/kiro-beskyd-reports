
<!-- BEGIN windows-kiro-ide addendum (monthly-report) -->
### Apps Script calls (replaces every two-step `curl` above)
Do not use `curl` with `/dev/null` (it does not exist on Windows). Call the installed
helper; it does the same POST -> redirect -> GET and prints the JSON response. It reads
`apps_script_url` from `~/.kiro/skills/weekly-report/folders.yaml` automatically.

```powershell
# create the monthly spreadsheet (Step 6.3)
& "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action create_spreadsheet -Title "Report by <full_name> <Month> <YYYY>" -FolderId "<month folder id>"
# trim unused rows before writing (Step 6.4)
& "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action trim_rows -SpreadsheetId "<id>" -DataRows <N>
```

When Step 1 has to append missing cross-month days into a weekly spreadsheet, use the
same helper calls as the weekly-report skill (create_spreadsheet / trim_rows).

The helper always prints JSON. On failure it prints `{"error": "..."}` and exits non-zero:
stop and show the error to the user.

Reading/writing cells still uses the google-sheets MCP server tools named above
(`list_spreadsheets` with `folder_id` for each month folder, `get_sheet_data`,
`update_cells`).

### `sheets_mode: none`
There are no weekly spreadsheets to read, so the "Google Sheets ONLY" data-source rule
does not apply. Instead aggregate the target month from the local weekly copies in
`{reports_dir}` (`YYYY-WNN-weekly.md`, keep only rows whose Date is in the target month),
falling back to `{work_log_dir}` / `{sessions_dir}` for uncovered business days (ask the
user when there is no data, never invent it). Build the same table, Total and percentage
summary, present it for confirmation, and save the local copy (Step 7). Skip all Apps
Script / Drive / `update_cells` steps.
<!-- END windows-kiro-ide addendum (monthly-report) -->
