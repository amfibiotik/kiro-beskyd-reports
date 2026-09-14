#!/bin/bash
# link.sh — point ~/.kiro/skills/*/SKILL.md at the copies inside this repo.
#
# Why: you edit skills through Kiro (which reads ~/.kiro/skills/...), but the
# shared source of truth lives in this repo. Symlinking makes every edit land
# in the repo automatically, so `git commit && git push` shares it with the team.
#
# Safe to re-run. Run it after cloning the repo on a new machine to restore the
# links (symlinks live on your machine, not in git, so a fresh clone has none).
#
# Note: this links ONLY the shared SKILL.md logic. Personal config
# (~/.kiro/skills/weekly-report/folders.yaml, ~/.kiro/work-config.yaml) stays
# local and is never touched here.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
KIRO_SKILLS="$HOME/.kiro/skills"

SKILLS=("weekly-report" "save-session")

echo ""
echo "🔗 Linking ~/.kiro/skills → repo"
echo "   repo: $REPO_DIR"
echo ""

for skill in "${SKILLS[@]}"; do
  SRC="$REPO_DIR/skills/$skill/SKILL.md"
  DEST_DIR="$KIRO_SKILLS/$skill"
  DEST="$DEST_DIR/SKILL.md"

  if [[ ! -f "$SRC" ]]; then
    echo "  ⚠ skip $skill — no SKILL.md in repo ($SRC)"
    continue
  fi

  mkdir -p "$DEST_DIR"

  # Already the correct symlink? Nothing to do.
  if [[ -L "$DEST" && "$(readlink "$DEST")" == "$SRC" ]]; then
    echo "  ✓ $skill already linked"
    continue
  fi

  # Back up a real (non-symlink) file before replacing it.
  if [[ -f "$DEST" && ! -L "$DEST" ]]; then
    BACKUP="$DEST.backup.$(date +%Y%m%d-%H%M%S)"
    mv "$DEST" "$BACKUP"
    echo "  ↳ backed up existing $skill/SKILL.md → $(basename "$BACKUP")"
  else
    # Existing (wrong) symlink — just remove it.
    rm -f "$DEST"
  fi

  ln -s "$SRC" "$DEST"
  echo "  ✓ linked $skill → repo"
done

echo ""
echo "Done. Kiro now reads these skills straight from the repo."
echo "Edit as usual, then: cd $REPO_DIR && git add -A && git commit && git push"
echo ""
