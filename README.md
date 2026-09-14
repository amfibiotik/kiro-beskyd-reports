# Kiro Beskyd Reports

Automated setup for two Kiro CLI skills:
- `/save-session` — saves session summary + full dialogue to project files and work log
- `/weekly-report` — generates weekly work reports and saves them to Google Sheets

## Prerequisites

- [Kiro CLI](https://kiro.dev) installed and working
- Google Workspace account (for Sheets integration)
- Jira access (for supplementing report data)

## Quick Start

```bash
git clone git@github.com:amfibiotik/kiro-beskyd-reports.git
cd kiro-beskyd-reports
bash setup.sh
```

The script will guide you through:
1. Personal info (worker ID, name)
2. Project mapping (Jira keys → human names)
3. Google Cloud setup (service account, Sheets API)
4. Google Drive folder structure
5. Apps Script deployment
6. Skill installation

### Prefer to install with an AI agent?

Setup has several manual Google steps. Instead of doing them alone, you can let
your Kiro CLI agent guide you: open Kiro in this repo folder and say
*"Read INSTALL_WITH_AI.md and install these skills for me."* The agent walks you
through each step, collects the values, runs `setup.sh`, and verifies the result.
See [INSTALL_WITH_AI.md](INSTALL_WITH_AI.md).

## What Gets Installed

```
~/.kiro/
├── skills/
│   ├── save-session/SKILL.md
│   └── weekly-report/
│       ├── SKILL.md
│       └── folders.yaml          ← generated (personal Drive IDs, gitignored)
├── work-planning/
│   ├── work-log/                 ← daily logs
│   ├── sessions/                 ← session summaries + dialogues
│   └── reports/                  ← local copies of weekly reports
├── work-config.yaml              ← generated (personal, gitignored)
└── holidays-{YYYY}.yaml          ← copied from shared/
```

## Google Setup (manual part)

See [google/GOOGLE_SETUP.md](google/GOOGLE_SETUP.md) for detailed instructions on:
- Creating a Google Cloud project and service account
- Enabling Google Sheets API
- Deploying the Apps Script Web App
- Creating Drive folder structure

## Updating Holidays

Holidays file is year-specific: `~/.kiro/holidays-{YYYY}.yaml`. Once your company approves the next year's holiday list, create a new file for that year:
```bash
# copy last year's as a starting point, then edit the dates
cp shared/holidays-2026.yaml ~/.kiro/holidays-2027.yaml
```

If the file for the current year is missing after January 2, the skill will remind you to add it.

## Files Overview

| File | Purpose |
|------|---------|
| `setup.sh` | Interactive setup script |
| `INSTALL_WITH_AI.md` | AI-agent-guided install instructions (alternative to running setup.sh alone) |
| `link.sh` | (Maintainers) Symlink `~/.kiro/skills` → this repo so edits sync back. Re-run after cloning to restore links. |
| `skills/` | SKILL.md files (copied as-is) |
| `templates/` | Config templates with placeholders |
| `shared/` | Team-shared files (holidays) |
| `google/` | Apps Script code + setup guide |
