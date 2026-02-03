#!/bin/bash
# Claude Profile Switcher Setup
# Run this script to install the Claude profile switcher shell function

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

# Create native claude profile
if [[ ! -f ~/.claude/profiles/claude.json ]]; then
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
  echo "✓ claude profile exists"
fi

# Create slash command
cat > ~/.claude/commands/profile.md << 'EOF'
Switch Claude profile.

Usage: /profile <profile>

Run `claude --list-profiles` to see available profiles.

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
echo "  claude --new-profile        # Create a new custom profile"
echo "  claude --profile <name>     # Switch to a profile"
echo "  claude --profile claude     # Switch to native Claude"
echo "  claude --list-profiles      # List available profiles"
echo "  claude --status             # Show profile status"
echo
echo "Shell function approach - survives Claude updates!"
