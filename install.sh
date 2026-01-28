#!/bin/bash
# Claude Profile Switcher Setup
# Run this script to set up profile switching for Claude Code
#
# Usage:
#   ./install.sh        # Initial setup (creates native claude profile)
#   ./install.sh --new  # Create a new custom profile interactively

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
NEW_PROFILE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --new)
      NEW_PROFILE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--new]"
      exit 1
      ;;
  esac
done

# Check for jq
if ! command -v jq &> /dev/null; then
  echo "❌ jq is required but not installed."
  echo "   Install with: brew install jq"
  exit 1
fi

# Handle --new: create a custom profile interactively
if $NEW_PROFILE; then
  echo "╔═══════════════════════════════════════════╗"
  echo "║   Create New Claude Profile               ║"
  echo "╚═══════════════════════════════════════════╝"
  echo
  
  # Get profile details
  read -p "Profile name (e.g., zai, openai, local): " PROFILE_NAME
  if [[ -z "$PROFILE_NAME" ]]; then
    echo "❌ Profile name is required"
    exit 1
  fi
  
  # Sanitize profile name
  PROFILE_NAME=$(echo "$PROFILE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
  
  if [[ "$PROFILE_NAME" == "claude" ]]; then
    echo "❌ 'claude' is reserved for native Claude profile"
    exit 1
  fi
  
  PROFILE_FILE="$HOME/.claude/profiles/${PROFILE_NAME}.json"
  if [[ -f "$PROFILE_FILE" ]]; then
    read -p "Profile '$PROFILE_NAME' exists. Overwrite? [y/N]: " OVERWRITE
    if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
      echo "Cancelled."
      exit 0
    fi
  fi
  
  read -p "API Base URL (e.g., https://api.z.ai/api/anthropic): " API_URL
  if [[ -z "$API_URL" ]]; then
    echo "❌ API URL is required"
    exit 1
  fi
  
  read -p "API Key: " API_KEY
  if [[ -z "$API_KEY" ]]; then
    echo "❌ API Key is required"
    exit 1
  fi
  
  read -p "Model name (used for opus/sonnet/haiku, e.g., glm-4.7): " MODEL_NAME
  if [[ -z "$MODEL_NAME" ]]; then
    echo "❌ Model name is required"
    exit 1
  fi
  
  # Create the profile
  mkdir -p ~/.claude/profiles
  cat > "$PROFILE_FILE" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "${API_URL}",
    "ANTHROPIC_AUTH_TOKEN": "${API_KEY}",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${MODEL_NAME}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${MODEL_NAME}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${MODEL_NAME}"
  },
  "remove": [
    "ANTHROPIC_API_KEY"
  ]
}
EOF
  
  echo
  echo "✓ Created profile: $PROFILE_NAME"
  echo "  Use with: claude --profile $PROFILE_NAME"
  exit 0
fi

# Regular install
echo "╔═══════════════════════════════════════════╗"
echo "║   Claude Profile Switcher Setup           ║"
echo "╚═══════════════════════════════════════════╝"
echo

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

# Create native claude profile (always, as it's the base)
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
echo "  claude --profile <name>   # Switch to a profile"
echo "  claude --profile claude   # Switch to native Claude"
echo "  claude --list-profiles    # List available profiles"
echo "  claude --status           # Show profile status"
echo
echo "To create a new profile: ./install.sh --new"
echo
echo "Shell function approach - survives Claude updates!"
