# Prisma AIRS Prompt Scan Hook for Claude Code IDE

A **global-scope** `UserPromptSubmit` hook for [Claude Code IDE](https://code.claude.com) on macOS that scans every submitted prompt via the **Prisma AIRS Runtime Scan API** and **blocks execution** if any threat is detected (prompt injection, insecure outputs, sensitive data loss, etc.).

## How It Works

1. **User submits a prompt** → `UserPromptSubmit` hook fires
2. **Hook sends the prompt** to Prisma AIRS `/v1/scan/sync/request`
3. **If threat detected** → prompt is blocked and erased; user sees the reason
4. **If benign** → prompt proceeds to Claude as normal

## Prerequisites

- **Claude Code IDE** (CLI or VS Code integration)
- **Prisma AIRS** subscription with API Intercept enabled
- **API key** and **security profile** from [Strata Cloud Manager](https://docs.paloaltonetworks.com/ai-runtime-security/activation-and-onboarding/ai-runtime-security-api-intercept-overview)
- `jq` and `curl` (standard on macOS)

## Setup

### 1. Install the hook (global scope)

Run from this project directory:

```bash
./install-global.sh
```

Or manually:

```bash
mkdir -p ~/.claude/hooks
cp prisma-airs-prompt-scan.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/prisma-airs-prompt-scan.sh
```

### 2. Merge hook config into Claude settings

If you already have `~/.claude/settings.json`, merge the `hooks` section from `claude-settings-prisma-airs.json` into it. If not:

```bash
mkdir -p ~/.claude
cp claude-settings-prisma-airs.json ~/.claude/settings.json
```

### 3. Set environment variables

**Option A: Use `~/.cursor/.env`** (recommended if you use Cursor)

Create `~/.cursor/.env` with:

```bash
PRISMA_AIRS_API_KEY=your-api-key-from-strata-cloud-manager
PRISMA_AIRS_PROFILE=your-security-profile-name
```

The hook automatically loads this file. Also supports `PRISMA_AIRS_AI_PROFILE` as an alternate name.

**Option B: Shell profile**

Add to `~/.zshrc` (or `~/.bash_profile`):

```bash
export PRISMA_AIRS_API_KEY="your-api-key-from-strata-cloud-manager"
export PRISMA_AIRS_PROFILE="your-security-profile-name"
```

Optional:

```bash
# Region: US (default), EU, or IN
export PRISMA_AIRS_BASE_URL="https://service.api.aisecurity.paloaltonetworks.com"   # US
# export PRISMA_AIRS_BASE_URL="https://service-de.api.aisecurity.paloaltonetworks.com"  # EU
# export PRISMA_AIRS_BASE_URL="https://service-in.api.aisecurity.paloaltonetworks.com"  # IN

# Debug mode (logs to stderr, visible with Ctrl+O in Claude Code)
# export PRISMA_AIRS_DEBUG=1
```

Reload your shell:

```bash
source ~/.zshrc
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRISMA_AIRS_API_KEY` | Yes | API key (x-pan-token) from Strata Cloud Manager |
| `PRISMA_AIRS_PROFILE` or `PRISMA_AIRS_AI_PROFILE` | Yes | Security profile name or UUID |
| `PRISMA_AIRS_BASE_URL` | No | API base URL (default: US region) |
| `PRISMA_AIRS_DEBUG` | No | Set to `1` for verbose stderr output |

The hook loads `~/.cursor/.env` automatically if present.

## Scope

- **Global**: Hook is defined in `~/.claude/settings.json`, so it applies to **all projects** on your machine.
- **UserPromptSubmit** has no matcher—it runs on every prompt submission.

## Disabling

- Remove the `UserPromptSubmit` hook from `~/.claude/settings.json`, or
- Set `"disableAllHooks": true` in your settings, or
- Unset `PRISMA_AIRS_API_KEY` (hook will block with a config error until fixed)

## Troubleshooting

- **"Prisma AIRS hook misconfigured"** → Ensure `PRISMA_AIRS_API_KEY` and `PRISMA_AIRS_PROFILE` (or `PRISMA_AIRS_AI_PROFILE`) are set. Use `~/.cursor/.env` or your shell profile.
- **"Prisma AIRS scan failed"** → Check API key, profile name, and base URL. Use `PRISMA_AIRS_DEBUG=1` and press `Ctrl+O` in Claude Code to see request/response details.
- **False positives** → Adjust your Prisma AIRS security profile in Strata Cloud Manager.
# PRISMA_AIRS_CLAUDE_HOOK
# PRISMA_AIRS_CLAUDE_HOOK
