
<!-- BEGIN windows-kiro-ide addendum (weekly-report) -->
### Apps Script calls (replaces every two-step `curl` above)
Do not use `curl` with `/dev/null` (it does not exist on Windows). Call the installed
helper; it does the same POST -> redirect -> GET and prints the JSON response. It reads
`apps_script_url` from `folders.yaml` automatically.

```powershell
# create_spreadsheet (Step 6.4)
& "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action create_spreadsheet -Title "<title>" -FolderId "<month folder id>"
# trim_rows (Step 6.5) - always before writing data
& "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action trim_rows -SpreadsheetId "<id>" -DataRows <N>
# create_folder (Step 6.8 month folder, and Year Rollover year folder)
& "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action create_folder -Name "07-July" -ParentId "<year folder id>"
& "$HOME\.kiro\scripts\Invoke-AppsScript.ps1" -Action create_folder -Name "2027" -ParentId "<root folder id>"
```

The helper always prints JSON. On failure it prints `{"error": "..."}` and exits non-zero:
stop and show the error to the user (do not retry blindly). The responses have the same
shape as documented above (`spreadsheet_id`/`url`, `folder_id`/`name`, `rows_deleted`/`total_rows`).

Reading/writing cells still uses the google-sheets MCP server tools named above
(`list_spreadsheets`, `get_sheet_data`, `update_cells`); pass `folder_id` to
`list_spreadsheets` to search a specific month folder.

### `sheets_mode: none`
Skip Step 6 entirely (no Drive, Apps Script, trim_rows, update_cells, cross-month folder
logic). Still do: date determination, data gathering, the main table (one row per
activity type), the percentage summary, present & confirm, and Step 7 (local copy in
`{reports_dir}`).
<!-- END windows-kiro-ide addendum (weekly-report) -->
