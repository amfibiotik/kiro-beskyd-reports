<!-- BEGIN team rule: work-days-days-off (monthly-report) -->
## Work Days / Days Off rows (team requirement, from November 2026)

Every monthly report MUST end with two extra lines placed UNDER the percentage summary
block (Step 5.5), as plain values: the label in column G, the number in column H.

| Label (column G) | Value (column H) |
|------------------|------------------|
| `Work days`      | number           |
| `Days off`       | number           |

This applies to reports created from now on. Do not add these rows to reports that were
already submitted unless the user explicitly asks.

**Work days** = number of distinct calendar dates of the target month that have more than 0
hours in the aggregated rows. Any amount of hours above zero counts as exactly 1 day. A weekend
day or an official holiday that was worked counts as a Work day too.

**Days off** = number of weekdays (Mon-Fri) of the target month, up to and including today if
the month is still running, on which there was NO work because of: an official non-working day
for the Ukraine team (holidays-{YYYY}.yaml), the user's own day off, vacation, or sick leave.
A weekday that was worked is never a Day off. Weekends are never Days off.

How to compute (from the calendar, NOT from which weekly spreadsheets exist):
1. List all Mon-Fri dates of the target month that are <= today.
2. Work days = distinct dates among the aggregated rows (weekend dates included).
3. Days off = the Mon-Fri dates from step 1 that have no row.
4. Sanity check: (Work days counted on weekdays only) + Days off = number of Mon-Fri dates
   from step 1. If a weekday has no row and the reason is unknown, ask the user (sick leave /
   own day off / vacation / holiday). Never guess.

Change to Step 1 (missing weekly reports): a week that has no weekly report because the user
did not work at all that week (vacation, sick leave, day off, official holidays) is NOT a
missing report. Do not stop and do not ask for /weekly-report. Ask once to confirm that the week
was off, and count its Mon-Fri days in Days off (a fully off week = 5 Days off). A week with
no weekly report where the user DID work keeps the original behavior of Step 1.

Placement (Step 5.5): let R = the Total row (data_rows + 2) and K = the number of category
rows. The Check row is R+3+K. Leave row R+4+K empty, then write `Work days` / its number in
G{R+5+K}:H{R+5+K} and `Days off` / its number in G{R+6+K}:H{R+6+K}. Use `update_cells` with
plain numbers. Show both numbers in the confirmation (Step 5) next to the percentage table.

With `sheets_mode: none`, print them after the percentage table and also write them into the
local copy ({reports_dir}/YYYY-MM-monthly.md) as `Work days: N` and `Days off: M`.
<!-- END team rule: work-days-days-off (monthly-report) -->
