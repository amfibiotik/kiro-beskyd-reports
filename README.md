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

## What Gets Installed

```
~/.kiro/
├── skills/
│   ├── save-session/SKILL.md
│   └── weekly-report/
│       ├── SKILL.md
│       └── folders.yaml          ← generated
├── work-config.yaml              ← generated
└── holidays-2026.yaml            ← copied from shared/
```

## Google Setup (manual part)

See [google/GOOGLE_SETUP.md](google/GOOGLE_SETUP.md) for detailed instructions on:
- Creating a Google Cloud project and service account
- Enabling Google Sheets API
- Deploying the Apps Script Web App
- Creating Drive folder structure

## Updating Holidays

Holidays file is year-specific: `~/.kiro/holidays-{YYYY}.yaml`. Once your company approves the next year's holiday list, create a new file:
```bash
cp shared/holidays-2026.yaml ~/.kiro/holidays-2026.yaml
```

If the file for the current year is missing after January 2, the skill will remind you to add it.

## Files Overview

| File | Purpose |
|------|---------|
| `setup.sh` | Interactive setup script |
| `skills/` | SKILL.md files (copied as-is) |
| `templates/` | Config templates with placeholders |
| `shared/` | Team-shared files (holidays) |
| `google/` | Apps Script code + setup guide |
