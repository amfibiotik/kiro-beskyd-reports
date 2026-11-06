<!-- BEGIN team rule: work-days-days-off (weekly-report) -->
## Work Days / Days Off rows (team requirement, from November 2026)

Every weekly report MUST end with two extra lines placed UNDER the percentage summary
block (Step 6.5), as plain values: the label in column G, the number in column H.

| Label (column G) | Value (column H) |
|------------------|------------------|
| `Work days`      | number           |
| `Days off`       | number           |

This applies to reports created from now on. Do not add these rows to reports that were
already submitted unless the user explicitly asks.

**Work days** = number of distinct calendar dates in the report with more than 0 hours.
Any amount of hours above zero counts as exactly 1 day. A weekend day or an official holiday
that was worked counts as a Work day too.

**Days off** = number of weekdays (Mon-Fri) of the report's week bounds, up to and including
today, on which there was NO work because of: an official non-working day for the Ukraine team
(holidays-{YYYY}.yaml), the user's own day off, vacation, or sick leave. A weekday that was
worked is never a Day off. Weekends are never Days off. Days after today (incomplete current
week) are not counted at all.

How to compute:
1. List the Mon-Fri dates of the week bounds that are <= today.
2. Work days = distinct dates in the main table (weekend dates included).
3. Days off = the Mon-Fri dates from step 1 that have no row in the main table.
4. Sanity check: (Work days counted on weekdays only) + Days off = number of Mon-Fri dates
   from step 1. If a weekday has no row and the reason is unknown, ask the user (sick leave /
   own day off / vacation / holiday) before saving. Never guess.

Placement (Step 6.5): let R = the Total row and K = the number of category rows. The Check row
is R+3+K. Leave row R+4+K empty, then write `Work days` / its number in G{R+5+K}:H{R+5+K} and
`Days off` / its number in G{R+6+K}:H{R+6+K}. Use `update_cells` with plain numbers (no
apostrophe, no text). In APPEND mode rewrite these two rows together with the percentage block
(Step 6.2 j2) and clear any leftover rows below them. Show both numbers in the confirmation
(Step 5) next to the percentage table.

With `sheets_mode: none`, print them after the percentage table and also write them into the
local copy ({reports_dir}/YYYY-WNN-weekly.md) as `Work days: N` and `Days off: M`.
<!-- END team rule: work-days-days-off (weekly-report) -->
