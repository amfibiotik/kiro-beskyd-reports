
<!-- BEGIN windows-kiro-ide addendum (save-session) -->
### Kiro IDE differences
- **Step 4 (knowledge base):** Kiro IDE has no `knowledge add` / `knowledge search`
  command. If no knowledge-base tool is available, skip Step 4 and report
  `Knowledge base: skipped (not available in Kiro IDE)` in Step 5. Do not fake it.
- **Timestamps:** Kiro IDE may not expose per-message timestamps. Take `Ended` from the
  current time (`Get-Date -Format 'HH:mm'`). If the start time is not known, write
  `Started: unknown` rather than guessing.
- **Writing files:** use the IDE file-writing tools; resolve `~` to `$HOME` first.
  Write the dialogue verbatim as the rules above require.
<!-- END windows-kiro-ide addendum (save-session) -->
