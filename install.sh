#!/bin/bash
# Claude Profile Switcher Setup
# Run this script to set up profile switching between native Claude and z.ai
#
# Usage:
#   ./setup-claude-profiles.sh           # Full setup (asks for API key)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔═══════════════════════════════════════════╗"
echo "║   Claude Profile Switcher Setup           ║"
echo "╚═══════════════════════════════════════════╝"
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
  if [[ ! -x "$HOME/.local/bin/claude" ]] && [[ ! -x "$HOME/.local/bin/claude-bin" ]] && [[ ! -x "/opt/homebrew/bin/claude" ]]; then
    echo "❌ Claude Code not found. Please install it first:"
    echo "   npm install -g @anthropic-ai/claude-code"
    echo "   or: brew install claude-code"
    exit 1
  fi
fi

echo "✓ Claude Code found"

# Create directories
mkdir -p ~/.claude/profiles
mkdir -p ~/.claude/commands
echo "✓ Created directories"

# Ask for z.ai API key
echo
read -p "Enter your z.ai API key (or press Enter to skip): " ZAI_API_KEY

# Create native profile
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

# Create z.ai profile
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

# Create slash command
cat > ~/.claude/commands/profile.md << 'EOF'
Switch Claude profile between native and z.ai settings.

Usage: /profile <profile>

Available profiles: claude, zai

1. Run this command to switch the profile:

```bash
~/.local/bin/claude --profile $ARGUMENTS --current-profile
```

2. After switching, tell the user: "Profile switched. Restart required. Run: `claude -c` to continue this conversation with the new profile."
EOF
echo "✓ Created /profile command"

# Detect shell and rc file
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
  zsh)
    RC_FILE="$HOME/.zshrc"
    SOURCE_LINE="source ${SCRIPT_DIR}/scripts/claude.sh"
    GREP_PATTERN="claude.sh"
    ;;
  bash)
    RC_FILE="$HOME/.bashrc"
    SOURCE_LINE="source ${SCRIPT_DIR}/scripts/claude.sh"
    GREP_PATTERN="claude.sh"
    ;;
  fish)
    RC_FILE="$HOME/.config/fish/config.fish"
    SOURCE_LINE="source ${SCRIPT_DIR}/scripts/claude.fish"
    GREP_PATTERN="claude.fish"
    ;;
  *)
    RC_FILE=""
    ;;
esac

# Add source line to shell rc if not already present
if [[ -n "$RC_FILE" ]]; then
  # Ensure directory exists for fish
  mkdir -p "$(dirname "$RC_FILE")"
  if grep -qF "$GREP_PATTERN" "$RC_FILE" 2>/dev/null; then
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
echo "  claude --profile claude   # Switch to native"
echo "  claude --list-profiles    # List profiles"
echo "  claude --status           # Show profile status"
echo "  /profile zai              # Switch from within Claude"
echo
echo "Shell function approach - survives Claude updates!"
