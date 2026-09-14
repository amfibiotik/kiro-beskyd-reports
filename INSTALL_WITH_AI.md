# Install these skills with an AI agent

This file is written for an **AI coding agent** (e.g. Kiro CLI) running in the
user's terminal. If you are a human: open your agent in this repo folder and say
*"Read INSTALL_WITH_AI.md and install these skills for me."*

---

## Role

You are installing the `weekly-report`, `monthly-report` and `save-session`
Kiro skills into the
**current user's** `~/.kiro` directory. You act as a guide: you cannot click
inside the user's browser or Google account, so for every step that requires
Google (Cloud Console, Drive, Apps Script) you explain what to do, wait for the
user to paste back the resulting value, then continue.

## Hard rules (do not violate)

1. **Never commit or push anything to this repo.** You are consuming it, not
   changing it. If you notice repo bugs, tell the user — do not fix them here.
2. **Personal values live only in local files** the user generates
   (`~/.kiro/skills/weekly-report/folders.yaml`, `~/.kiro/work-config.yaml`).
   These are gitignored. Never write real IDs, names, or URLs into any file
   that is tracked by this repo.
3. **Never print secrets into the chat.** The service-account JSON is a
   credential — refer to it by its file path only, never echo its contents.
4. **Do not touch the user's other files or teammates' work.** Only create the
   `~/.kiro/...` files this install needs.
5. **Do not move, rename, or delete anything in the user's Google Drive.**
6. Confirm with the user before running any command that writes files.

## Source of truth

Do not re-explain Google setup from memory. Read and follow, in order:

- `google/GOOGLE_SETUP.md` — the authoritative step-by-step for Google Cloud,
  the service account, Drive folders, the template, and the Apps Script Web App.
- `setup.sh` — the interactive installer that writes `~/.kiro/work-config.yaml`
  and `~/.kiro/skills/weekly-report/folders.yaml` and copies the skills.
- `templates/*.template.yaml` — the exact shape of the generated config files
  (use these if you generate config directly instead of via `setup.sh`).

If any instruction here disagrees with `GOOGLE_SETUP.md`, trust `GOOGLE_SETUP.md`
and tell the user about the mismatch.

## Procedure

1. **Prerequisites check.** Confirm the user has: Kiro CLI working, a Google
   account, and (for report data) Jira access. Ask whether they even want the
   Google Sheets integration — if not, `setup.sh` supports `sheets_mode: none`
   (terminal + local file only) and you can skip all Google steps.

2. **Walk the Google setup** by reading `google/GOOGLE_SETUP.md` and guiding the
   user through it one step at a time. After each step, ask them to paste back
   the value it produces. You will collect:
   - Apps Script Web App URL
   - Template spreadsheet ID (the Beskyd team shares one — see GOOGLE_SETUP Step 4)
   - Root Drive folder ID (holds the per-year folders)
   - Current year folder ID (the `{YYYY}` subfolder inside root)
   - Service-account JSON file path (for the google-sheets MCP server)
   Explain the two-level folder layout (root → year → month) and that month
   folders — and future year folders — are created automatically by the skill.

3. **Run the installer.** Once values are collected, run `bash setup.sh` from
   this repo and feed the answers, OR generate the two config files directly
   from `templates/*.template.yaml`, filling the collected values. Either way,
   the personal files end up under `~/.kiro/` and never in this repo.

4. **Wire up the google-sheets MCP** so the `update_cells` tool works, using the
   service-account JSON path (path only — never its contents). Point the user to
   Kiro's MCP configuration docs; do not hardcode credentials anywhere tracked.

5. **Holidays file.** Copy `shared/holidays-{YYYY}.yaml` to
   `~/.kiro/holidays-{YYYY}.yaml` for the current year (create next year's when
   the company approves the list).

6. **Verify.** Ask the user to run: `weekly report current week`. Confirm the
   skill computes the week from the real system `date`, gathers work-log data,
   prints a report table, and (after their confirmation) creates a spreadsheet
   in the correct month folder. If `update_cells` returns 403, the Drive folder
   or template is not shared with the service-account email — see the
   Troubleshooting table in `GOOGLE_SETUP.md`.

## For maintainers only (not for a fresh install)

If the user is a **maintainer** of this repo (not just installing), `link.sh`
symlinks `~/.kiro/skills/*` back to this repo so their edits sync to git. A
plain installing user does **not** run `link.sh` — `setup.sh` copies the skills
in, which is what they want.
