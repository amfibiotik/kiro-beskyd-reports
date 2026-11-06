

---

<!-- BEGIN windows-kiro-ide addendum (appended by windows/setup.ps1; do not edit the installed copy, edit windows/addenda/ in the repo) -->

## Windows + Kiro IDE addendum

This installation runs on **Windows** inside **Kiro IDE** (shell = Windows PowerShell).
Everything above stays authoritative for **what** to do (business rules, formats,
columns, folders, append/cross-month logic, confirmations). This addendum only says
**how** to run the platform-specific commands. Where a command above is
macOS/Linux-only, use the Windows equivalent below instead.

### Paths
- `~` means the user profile folder (`$HOME`, e.g. `C:\Users\<name>`). Expand `~` in
  every path read from `work-config.yaml` (`work_log_dir`, `sessions_dir`, `reports_dir`)
  before using it.
- Holidays file: `$HOME\.kiro\holidays-{YYYY}.yaml`.
- The daily work log always lives in `{work_log_dir}` from `work-config.yaml`
  (default `~/.kiro/work-planning/work-log`). If any rule above mentions
  `~/.kiro/work-log/`, read it as `{work_log_dir}`.

### Current date (replaces `date '+%Y-%m-%d %A %u'`)
Run this exact PowerShell one-liner. It prints the same three values as the macOS/Linux
command: ISO date, English weekday name, ISO weekday number (1 = Monday ... 7 = Sunday):

```powershell
$n = Get-Date; $u = [int]$n.DayOfWeek; if ($u -eq 0) { $u = 7 }; '{0} {1} {2}' -f $n.ToString('yyyy-MM-dd'), $n.ToString('dddd', [Globalization.CultureInfo]::InvariantCulture), $u
```

Never use `(Get-Date).DayOfWeek` as a number directly: on Windows Sunday is `0`, not `7`.
Never rely on the localized weekday name (it may be Ukrainian, e.g. "понеділок"); use the
number.

### `sheets_mode` (from `work-config.yaml`)
- `monthly_folders` / `single_folder`: follow the Google Sheets flow above.
- `none`: do NOT call Google Sheets, Apps Script, or `folders.yaml` at all. Show the report
  in chat and save the local copy (the "Save Local Copy" step above). See the skill-specific
  notes below for what replaces the Sheets steps.
<!-- END windows-kiro-ide addendum (common) -->
