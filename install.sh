#!/bin/bash
# Claude Profile Switcher Setup
# Run this script to set up profile switching between native Claude and z.ai
#
# Usage:
#   ./install.sh              # Setup (skips existing profiles)
#   ./install.sh --reinstall  # Overwrite existing profiles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
REINSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reinstall)
      REINSTALL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--reinstall]"
      exit 1
      ;;
  esac
done

echo "╔═══════════════════════════════════════════╗"
echo "║   Claude Profile Switcher Setup           ║"
echo "╚═══════════════════════════════════════════╝"
$REINSTALL && echo "  (reinstall mode - will overwrite profiles)"
echo

# Check for jq
if ! command -v jq &> /dev/null; then
  echo "❌ jq is required but not installed."
  echo "   Install with: brew install jq"
  exit 1
fi

# Check for claude
if ! command -v claude &> /dev/null; then
  # Check common locations
  if [[ ! -x "$HOME/.local/bin/claude" ]] && [[ ! -x "$HOME/.local/bin/claude-bin" ]]; then
    echo "❌ Claude Code not found. Please install it first:"
    echo "   npm install -g @anthropic-ai/claude-code"
    exit 1
  fi
fi

echo "✓ Claude Code found"

# Create directories
mkdir -p ~/.claude/profiles
mkdir -p ~/.claude/commands
echo "✓ Created directories"

# Check which profiles need to be created
NEED_CLAUDE=false
NEED_ZAI=false
NEED_CEREBRAS=false

if $REINSTALL; then
  NEED_CLAUDE=true
  NEED_ZAI=true
  NEED_CEREBRAS=true
else
  [[ ! -f ~/.claude/profiles/claude.json ]] && NEED_CLAUDE=true
  [[ ! -f ~/.claude/profiles/zai.json ]] && NEED_ZAI=true
  [[ ! -f ~/.claude/profiles/cerebras.json ]] && NEED_CEREBRAS=true
fi

# Get API keys if needed
ZAI_API_KEY=""
CEREBRAS_API_KEY=""
if $NEED_ZAI; then
  echo
  read -p "Enter your z.ai API key (or press Enter to skip): " ZAI_API_KEY
fi
if $NEED_CEREBRAS; then
  echo
  read -p "Enter your Cerebras API key (or press Enter to skip): " CEREBRAS_API_KEY
fi

# Create native profile
if $NEED_CLAUDE; then
  cat > ~/.claude/profiles/claude.json << 'EOF'
{
  "remove": [
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "API_TIMEOUT_MS",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL"
  ]
}
EOF
  echo "✓ Created claude profile"
else
  echo "✓ claude profile exists (use --reinstall to overwrite)"
fi

# Create z.ai profile
if $NEED_ZAI; then
  if [[ -n "$ZAI_API_KEY" ]]; then
    cat > ~/.claude/profiles/zai.json << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "${ZAI_API_KEY}",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air"
  },
  "remove": [
    "ANTHROPIC_API_KEY"
  ]
}
EOF
    echo "✓ Created zai profile"
  else
    echo "⚠ Skipped zai profile (no API key provided)"
  fi
else
  echo "✓ zai profile exists (use --reinstall to overwrite)"
fi

# Create cerebras profile
if $NEED_CEREBRAS; then
  if [[ -n "$CEREBRAS_API_KEY" ]]; then
    cat > ~/.claude/profiles/cerebras.json << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8080",
    "ANTHROPIC_AUTH_TOKEN": "${CEREBRAS_API_KEY}",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "zai-glm-4.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "zai-glm-4.7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "zai-glm-4.7"
  },
  "remove": [
    "ANTHROPIC_API_KEY"
  ]
}
EOF
    echo "✓ Created cerebras profile"
  else
    echo "⚠ Skipped cerebras profile (no API key provided)"
  fi
else
  echo "✓ cerebras profile exists (use --reinstall to overwrite)"
fi

# Create slash command (always update this one as it's not user-customizable)
cat > ~/.claude/commands/profile.md << 'EOF'
Switch Claude profile between native and z.ai settings.

Usage: /profile <profile>

Available profiles: claude, zai, cerebras

1. Run this command to switch the profile:

```bash
~/.local/bin/claude --profile $ARGUMENTS --current-profile
```

2. After switching, tell the user: "Profile switched. Restart required. Run: `claude -c` to continue this conversation with the new profile."
EOF
echo "✓ Updated /profile command"

# Detect shell and rc file
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
  zsh)
    RC_FILE="$HOME/.zshrc"
    ;;
  bash)
    RC_FILE="$HOME/.bashrc"
    ;;
  *)
    RC_FILE=""
    ;;
esac

# Add source line to shell rc if not already present
SOURCE_LINE="source ${SCRIPT_DIR}/scripts/claude.sh"

if [[ -n "$RC_FILE" ]]; then
  if grep -qF "claude.sh" "$RC_FILE" 2>/dev/null; then
    echo "✓ Shell function already sourced in $RC_FILE"
  else
    echo "" >> "$RC_FILE"
    echo "# Claude profile switcher" >> "$RC_FILE"
    echo "$SOURCE_LINE" >> "$RC_FILE"
    echo "✓ Added source line to $RC_FILE"
  fi
fi

echo
echo "╔═══════════════════════════════════════════╗"
echo "║   Setup Complete!                         ║"
echo "╚═══════════════════════════════════════════╝"
echo
echo "To activate, either:"
echo "  1. Open a new terminal, or"
echo "  2. Run: source ${RC_FILE:-your shell rc file}"
echo
echo "Usage:"
echo "  claude --profile zai      # Switch to z.ai"
echo "  claude --profile cerebras # Switch to cerebras (local proxy)"
echo "  claude --profile claude   # Switch to native"
echo "  claude --list-profiles    # List profiles"
echo "  claude --status           # Show profile status"
echo "  /profile zai              # Switch from within Claude"
echo
echo "To reinstall/update profiles: ./install.sh --reinstall"
echo
echo "Shell function approach - survives Claude updates!"
