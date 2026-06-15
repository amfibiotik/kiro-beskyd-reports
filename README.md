# Kiro Weekly Setup

Automated setup for two Kiro CLI skills:
- `/save-session-v2` — saves session summary + full dialogue to project files and work log
- `/weekly-report-v2` — generates weekly work reports and saves them to Google Sheets

## Prerequisites

- [Kiro CLI](https://kiro.dev) installed and working
- Google Workspace account (for Sheets integration)
- Jira access (for supplementing report data)

## Quick Start

```bash
git clone <this-repo>
cd kiro-weekly-setup
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
│   ├── save-session-v2/SKILL.md
│   └── weekly-report-v2/
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

Edit `shared/holidays-2026.yaml` and re-run:
```bash
cp shared/holidays-2026.yaml ~/.kiro/holidays-2026.yaml
```

## Files Overview

| File | Purpose |
|------|---------|
| `setup.sh` | Interactive setup script |
| `skills/` | SKILL.md files (copied as-is) |
| `templates/` | Config templates with placeholders |
| `shared/` | Team-shared files (holidays) |
| `google/` | Apps Script code + setup guide |
