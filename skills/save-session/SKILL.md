---
name: save-session
description: "Save session: summary + full dialogue. Use when: save session, зберегти сесію, зберегти розмову, save dialogue."
---

# Save Session

Saves both a summary (for reports) and the full dialogue (for long-term analysis).

## When to Invoke
- User says "save session", "зберегти сесію", "зберегти розмову", "save full"

## Config
Read `~/.kiro/work-config.yaml` for:
- `sessions_dir` — where to save summaries and dialogues (default: `~/.kiro/work-planning/sessions`)
- `work_log_dir` — where to append daily work log (default: `~/.kiro/work-planning/work-log`)
- `projects` — map of project prefixes to names (for tagging)
- `full_name` — used when naming the knowledge-base context entry

## Output Directory
Use `sessions_dir` from config. This is a GLOBAL directory — all sessions from all projects go here.
Do NOT use project-local `.planning/sessions/` anymore.

## Process

### Step 1: Save Summary
Write `{sessions_dir}/{YYYY-MM-DD}-{NN}-summary.md`

Format:
```markdown
# Session YYYY-MM-DD

## Projects
CRUE, FOTL (list all projects touched in this session)

## Done
- [CRUE-XXXX] Description
- [FOTL-YYYY] Description

## Decisions
- Decision made (with project context if relevant)

## Tickets
- CRUE-XXXX: status
- FOTL-YYYY: status

## Next Session
- What to do next

## Blockers
- None
```

Note: The `## Projects` section is new — it enables filtering/searching sessions by project.

### Step 2: Save Full Dialogue
Write `{sessions_dir}/{YYYY-MM-DD}-{NN}-dialogue.md`

Format:
```markdown
# Dialogue — YYYY-MM-DD Session NN
- Started: HH:MM (from first user message timestamp)
- Ended: HH:MM (from last message timestamp before save)
- Projects: CRUE, FOTL
- Topics: comma-separated list of main topics discussed
- Key tickets: CRUE-XXXX, FOTL-YYYY

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
Append to `{work_log_dir}/{YYYY-MM-DD}.md`.

Format per entry:
```markdown
## Session NN (HH:MM - HH:MM)
Projects: CRUE, FOTL
- What was done (brief bullets)
```

### Step 4: Index in Knowledge Base
After saving files, index the summary in the knowledge base:

```
knowledge add
  name: "Session Context {YYYY-MM-DD} - {full_name}"
  value: {path to summary file}
```

This ensures the next session can discover what was done via `knowledge search`.

If a previous session-context for the same date+NN already exists in the KB, update it instead of adding a duplicate.

### Step 5: Confirm
Show:
- Summary file path + brief content preview
- Dialogue file path + size (approx word/line count)
- Work log entry
- Knowledge base: indexed ✓

## Sequence Numbering
If files already exist for today (e.g., `2026-07-21-01-summary.md`), increment NN.
Summary and dialogue always share the same NN for the same session.

## CRITICAL: Dialogue Per Save
Every time save-session is invoked, BOTH summary AND dialogue files MUST be created with matching NN.
- If this is the 2nd save today → create `*-02-summary.md` AND `*-02-dialogue.md`
- NEVER skip the dialogue file — it captures the conversation that led to the summary
- Each dialogue covers ONLY the current session (from last save or session start), not the whole day

## CRITICAL: Works From Any Directory
This skill MUST work regardless of which directory (project) the CLI was launched from.
All paths are absolute (resolved from work-config.yaml), never relative to CWD.

## Future Extensions (not implemented yet)
- Google Sheets API integration for structured data export
- Automatic monthly meta-analysis prompts
- Cross-session pattern detection triggers
