---
name: save-session
description: "Save session: summary + full dialogue. Use when: save session, зберегти розмову, save dialogue, save full session."
---

# Save Session

Extended save-session. Saves both a summary (for reports) and the full dialogue (for long-term analysis).

## When to Invoke
- User explicitly says "save session", "зберегти розмову", "save full"

## Config
Read `~/.kiro/work-config.yaml` for project context.

## Output Directory
`{project_root}/.planning/sessions/` (always root of the repo, NOT subdirectories)

## Process

### Step 1: Save Summary (same as v1)
Write `{YYYY-MM-DD}-{NN}-summary.md`

Format:
```markdown
# Session YYYY-MM-DD

## Done
- [TICKET-XXXX] Description

## Decisions
- Decision made

## Tickets
- TICKET-XXXX: status

## Next Session
- What to do next

## Blockers
- None
```

### Step 2: Save Full Dialogue
Write `{YYYY-MM-DD}-{NN}-dialogue.md`

Format:
```markdown
# Dialogue — YYYY-MM-DD Session NN
- Started: HH:MM (from first user message timestamp)
- Ended: HH:MM (from last message timestamp before save)
- Topics: comma-separated list of main topics discussed
- Key tickets: TICKET-XXXX, TICKET-YYYY

---

[Complete conversation text, verbatim, no edits, no summaries]
[Include both user messages and assistant responses]
[Preserve code blocks, links, everything as-is]
```

Rules for dialogue file:
- NO summarizing, truncating, or paraphrasing
- Include EVERY message from the session
- Preserve original language (Ukrainian, English, mixed)
- Preserve code blocks and formatting
- If session is very long, still save everything — file size is not a concern

### Step 3: Append to Work Log
Append to `~/.kiro/work-log/YYYY-MM-DD.md`.

### Step 4: Confirm
Show:
- Summary file path + brief content preview
- Dialogue file path + size (approx word/line count)
- Work log entry

## Sequence Numbering
If files already exist for today (e.g., `2026-06-12-01-summary.md`), increment NN.
Summary and dialogue always share the same NN for the same session.
