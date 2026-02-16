#!/bin/bash
# Install Prisma AIRS prompt scan hook for Claude Code IDE (global scope)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.claude/hooks"
cp "$SCRIPT_DIR/prisma-airs-prompt-scan.sh" "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/prisma-airs-prompt-scan.sh"

# Merge or create settings.json
SETTINGS="$HOME/.claude/settings.json"
HOOKS_JSON="$SCRIPT_DIR/claude-settings-prisma-airs.json"

mkdir -p "$HOME/.claude"

if [ -f "$SETTINGS" ]; then
  if command -v jq &>/dev/null; then
    cp "$SETTINGS" "${SETTINGS}.bak"
    EXISTING=$(jq '.hooks.UserPromptSubmit // []' "$SETTINGS")
    NEW=$(jq '.hooks.UserPromptSubmit' "$HOOKS_JSON")
    MERGED=$(jq -n --argjson e "$EXISTING" --argjson n "$NEW" '$e + $n')
    jq --argjson ups "$MERGED" '.hooks.UserPromptSubmit = $ups' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
    echo "Merged Prisma AIRS hook into existing ~/.claude/settings.json"
  else
    echo "Existing ~/.claude/settings.json found. Install jq to auto-merge, or merge hooks manually from claude-settings-prisma-airs.json"
  fi
else
  cp "$HOOKS_JSON" "$SETTINGS"
  echo "Created ~/.claude/settings.json with Prisma AIRS hook."
fi

echo ""
echo "Hook script installed to ~/.claude/hooks/prisma-airs-prompt-scan.sh"
echo ""
echo "Set these in ~/.zshrc (or ~/.bash_profile):"
echo "  export PRISMA_AIRS_API_KEY=\"your-api-key\""
echo "  export PRISMA_AIRS_PROFILE=\"your-profile-name\""
echo ""
echo "Then: source ~/.zshrc"
