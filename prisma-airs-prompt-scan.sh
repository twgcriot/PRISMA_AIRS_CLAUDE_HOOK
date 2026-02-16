#!/bin/bash
#
# Prisma AIRS Runtime Scan Hook for Claude Code IDE
# Fires on UserPromptSubmit - scans the prompt via Prisma AIRS API and blocks
# execution if any threat is detected.
#
# Required env vars:
#   PRISMA_AIRS_API_KEY   - API key (x-pan-token) from Strata Cloud Manager
#   PRISMA_AIRS_PROFILE   - Security profile name or UUID
#
# Optional env vars:
#   PRISMA_AIRS_BASE_URL  - API base URL (default: US region)
#   PRISMA_AIRS_DEBUG     - Set to "1" for verbose stderr output
#

set -e

# Load env from ~/.cursor/.env if present (Claude Code doesn't auto-load it)
# Supports both PRISMA_AIRS_PROFILE and PRISMA_AIRS_AI_PROFILE
if [ -f "$HOME/.cursor/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$HOME/.cursor/.env"
  set +a
fi
# Support alternate profile var name (PRISMA_AIRS_AI_PROFILE used in .cursor/.env)
PRISMA_AIRS_PROFILE="${PRISMA_AIRS_PROFILE:-$PRISMA_AIRS_AI_PROFILE}"

# Read UserPromptSubmit JSON from stdin
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

# Empty prompt - allow (edge case)
if [ -z "$PROMPT" ]; then
  exit 0
fi

# Check required env vars
if [ -z "$PRISMA_AIRS_API_KEY" ] || [ -z "$PRISMA_AIRS_PROFILE" ]; then
  echo '{"decision": "block", "reason": "Prisma AIRS hook misconfigured: PRISMA_AIRS_API_KEY and PRISMA_AIRS_PROFILE must be set"}' >&2
  exit 2
fi

# Base URL - US, EU, or IN region
BASE_URL="${PRISMA_AIRS_BASE_URL:-https://service.api.aisecurity.paloaltonetworks.com}"
SCAN_URL="${BASE_URL}/v1/scan/sync/request"

# Build request body - use profile_id if it looks like a UUID, else profile_name
case "$PRISMA_AIRS_PROFILE" in
  *-*-*-*-*) AI_PROFILE_JSON="{\"profile_id\": \"$PRISMA_AIRS_PROFILE\"}" ;;
  *)         AI_PROFILE_JSON="{\"profile_name\": \"$PRISMA_AIRS_PROFILE\"}" ;;
esac

TR_ID="claude-$(date +%s)-$$"
REQUEST_BODY=$(jq -n \
  --arg tr_id "$TR_ID" \
  --argjson ai_profile "$AI_PROFILE_JSON" \
  --arg prompt "$PROMPT" \
  '{
    tr_id: $tr_id,
    ai_profile: $ai_profile,
    metadata: { app_user: "claude-code", ai_model: "claude-code-ide" },
    contents: [{ prompt: $prompt }]
  }')

[ "${PRISMA_AIRS_DEBUG}" = "1" ] && echo "Request: $REQUEST_BODY" >&2

# Call Prisma AIRS scan API
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$SCAN_URL" \
  -H "Content-Type: application/json" \
  -H "x-pan-token: $PRISMA_AIRS_API_KEY" \
  -d "$REQUEST_BODY" 2>/dev/null) || true

HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

[ "${PRISMA_AIRS_DEBUG}" = "1" ] && echo "Response ($HTTP_CODE): $HTTP_BODY" >&2

# API error - block for safety (fail-closed)
if [ "$HTTP_CODE" -ge 400 ] 2>/dev/null; then
  ERROR_MSG=$(echo "$HTTP_BODY" | jq -r '.message // .error // "Unknown API error"' 2>/dev/null || echo "HTTP $HTTP_CODE")
  echo "{\"decision\": \"block\", \"reason\": \"Prisma AIRS scan failed: $ERROR_MSG\"}"
  exit 0
fi

# Parse verdict - block if threat detected
# Prisma AIRS returns category: "malicious" or "benign", and threat details
CATEGORY=$(echo "$HTTP_BODY" | jq -r '.category // .verdict // .threat_detected // empty' 2>/dev/null)
THREAT_DETECTED=$(echo "$HTTP_BODY" | jq -r '.threat_detected // .threats // .malicious // false' 2>/dev/null)
ACTION_TAKEN=$(echo "$HTTP_BODY" | jq -r '.action_taken // .action // empty' 2>/dev/null)
REASON=$(echo "$HTTP_BODY" | jq -r '.reason // .recommendation // .message // empty' 2>/dev/null)

# Block if malicious/threat detected (adapt to actual API response schema)
BLOCK=0
if [ "$CATEGORY" = "malicious" ] || [ "$THREAT_DETECTED" = "true" ]; then
  BLOCK=1
fi
# Some APIs use a top-level "threats" array
THREAT_COUNT=$(echo "$HTTP_BODY" | jq -r '.threats | length // 0' 2>/dev/null)
if [ -n "$THREAT_COUNT" ] && [ "$THREAT_COUNT" -gt 0 ] 2>/dev/null; then
  BLOCK=1
fi

if [ "$BLOCK" -eq 1 ]; then
  REASON_MSG="${REASON:-Threat detected by Prisma AIRS}"
  [ -n "$ACTION_TAKEN" ] && REASON_MSG="$REASON_MSG (action: $ACTION_TAKEN)"
  echo "{\"decision\": \"block\", \"reason\": \"$REASON_MSG\"}"
  exit 0
fi

# No threat - allow prompt to proceed (no JSON output needed)
exit 0
