#!/bin/bash
# Claude Profile Switcher Setup
# Run this script to set up profile switching between native Claude and z.ai
#
# Usage:
#   ./setup-claude-profiles.sh           # Full setup (asks for API key)
#   ./setup-claude-profiles.sh --repair  # Re-wrap after Claude update

set -e

REPAIR_ONLY=false
if [[ "$1" == "--repair" ]] || [[ "$1" == "-r" ]]; then
  REPAIR_ONLY=true
fi

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

# Find claude binary
CLAUDE_PATH=$(which claude 2>/dev/null || which claude-bin 2>/dev/null || true)
if [[ -z "$CLAUDE_PATH" ]]; then
  echo "❌ Claude Code not found. Please install it first:"
  echo "   npm install -g @anthropic-ai/claude-code"
  exit 1
fi

CLAUDE_DIR=$(dirname "$CLAUDE_PATH")
CLAUDE_BIN="${CLAUDE_DIR}/claude-bin"

echo "Found Claude at: $CLAUDE_PATH"

# Check if wrapper needs to be (re)installed
NEEDS_WRAP=false
if [[ -f "$CLAUDE_BIN" ]]; then
  # claude-bin exists, check if claude is our wrapper
  if ! grep -q "Claude Code profile switcher wrapper" "${CLAUDE_DIR}/claude" 2>/dev/null; then
    # Claude was updated and overwrote our wrapper
    echo "⚠ Claude was updated, re-wrapping..."
    rm -f "${CLAUDE_DIR}/claude"
    NEEDS_WRAP=true
  else
    echo "✓ Wrapper already installed"
  fi
else
  # First time setup
  if [[ -f "${CLAUDE_DIR}/claude" ]] || [[ -L "${CLAUDE_DIR}/claude" ]]; then
    mv "${CLAUDE_DIR}/claude" "$CLAUDE_BIN"
    echo "✓ Moved original claude to claude-bin"
  fi
  NEEDS_WRAP=true
fi

# Create directories
mkdir -p ~/.claude/profiles
mkdir -p ~/.claude/commands
echo "✓ Created directories"

# Profile setup (skip in repair mode)
if [[ "$REPAIR_ONLY" == "false" ]]; then
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
else
  echo "Repair mode: keeping existing profiles"
fi

# Create wrapper script (always)
if [[ "$NEEDS_WRAP" == "true" ]] || [[ ! -f "${CLAUDE_DIR}/claude" ]]; then
  cat > "${CLAUDE_DIR}/claude" << 'WRAPPER'
#!/bin/bash
# Claude Code profile switcher wrapper
# Profiles stored in ~/.claude/profiles/*.json

set -e

GLOBAL_SETTINGS_FILE="${HOME}/.claude/settings.json"
GLOBAL_PROFILES_DIR="${HOME}/.claude/profiles"
LOCAL_PROFILES_DIR=".claude/profiles"

SETTINGS_FILE="$GLOBAL_SETTINGS_FILE"
PROFILES_DIR="$GLOBAL_PROFILES_DIR"
USE_LOCAL=false

# Find the real claude binary
SCRIPT_DIR="$(dirname "$0")"
CLAUDE_BIN="${SCRIPT_DIR}/claude-bin"

list_profiles() {
  echo "Available profiles:"
  for f in "${PROFILES_DIR}"/*.json; do
    [[ -f "$f" ]] && echo "  - $(basename "$f" .json)"
  done
}

apply_profile() {
  local profile="$1"
  local profile_file="${PROFILES_DIR}/${profile}.json"

  if [[ ! -f "$profile_file" ]]; then
    echo "Error: Profile '$profile' not found at $profile_file" >&2
    list_profiles >&2
    exit 1
  fi

  # Ensure settings.json exists
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' > "$SETTINGS_FILE"
  fi

  # Step 1: Remove keys if specified
  if jq -e '.remove' "$profile_file" > /dev/null 2>&1; then
    local keys_to_remove
    keys_to_remove=$(jq -r '.remove[]' "$profile_file")
    
    local jq_filter='.env // {} | del('
    local first=true
    for key in $keys_to_remove; do
      if $first; then
        jq_filter+=".\"${key}\""
        first=false
      else
        jq_filter+=", .\"${key}\""
      fi
    done
    jq_filter+=')'
    
    local new_env
    new_env=$(jq "$jq_filter" "$SETTINGS_FILE")
    jq --argjson newenv "$new_env" '.env = $newenv' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  fi
  
  # Step 2: Add/merge env vars if specified
  if jq -e '.env' "$profile_file" > /dev/null 2>&1; then
    local profile_env
    profile_env=$(jq '.env // {}' "$profile_file")
    
    jq --argjson penv "$profile_env" '.env = ((.env // {}) * $penv)' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    
    # For non-claude profiles, ensure onboarding is complete
    CLAUDE_JSON="${HOME}/.claude.json"
    if [[ -f "$CLAUDE_JSON" ]]; then
      jq '. + {hasCompletedOnboarding: true}' "$CLAUDE_JSON" > "${CLAUDE_JSON}.tmp"
      mv "${CLAUDE_JSON}.tmp" "$CLAUDE_JSON"
    else
      echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON"
    fi
  fi
  
  echo "Switched to profile: $profile"
}

detect_profile() {
  local settings_file="$1"
  if [[ ! -f "$settings_file" ]]; then
    echo "claude"
    return
  fi
  
  if jq -e '.env.ANTHROPIC_BASE_URL' "$settings_file" > /dev/null 2>&1; then
    local url
    url=$(jq -r '.env.ANTHROPIC_BASE_URL' "$settings_file")
    if [[ "$url" == *"z.ai"* ]]; then
      echo "zai"
    else
      echo "custom"
    fi
  else
    echo "claude"
  fi
}

show_current() {
  echo "Current: $(detect_profile "$SETTINGS_FILE")"
}

show_status() {
  local global_profile=$(detect_profile "$GLOBAL_SETTINGS_FILE")
  local local_profile="(none)"
  local local_settings=".claude/settings.local.json"
  
  if [[ -f "$local_settings" ]]; then
    local_profile=$(detect_profile "$local_settings")
  fi
  
  # Active is local if set, otherwise global
  local active="$global_profile"
  if [[ "$local_profile" != "(none)" ]]; then
    active="$local_profile (local)"
  fi
  
  echo "Global profile: $global_profile"
  echo "Local profile:  $local_profile"
  echo "Active:         $active"
}

# Parse arguments - first pass: check for --local
for arg in "$@"; do
  if [[ "$arg" == "--local" ]]; then
    USE_LOCAL=true
    PROFILES_DIR="$LOCAL_PROFILES_DIR"
    SETTINGS_FILE=".claude/settings.local.json"
    break
  fi
done

# Parse arguments - second pass: process all args
PROFILE=""
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --list-profiles)
      list_profiles
      exit 0
      ;;
    --current-profile)
      show_current
      exit 0
      ;;
    --status)
      show_status
      exit 0
      ;;
    --local)
      shift
      ;;
    *)
      PASSTHROUGH_ARGS+=("$1")
      shift
      ;;
  esac
done

# Apply profile if specified
if [[ -n "$PROFILE" ]]; then
  if [[ "$USE_LOCAL" == "true" ]]; then
    # Copy profile from global to local if it doesn't exist locally
    mkdir -p "$LOCAL_PROFILES_DIR"
    if [[ ! -f "${LOCAL_PROFILES_DIR}/${PROFILE}.json" ]] && [[ -f "${GLOBAL_PROFILES_DIR}/${PROFILE}.json" ]]; then
      cp "${GLOBAL_PROFILES_DIR}/${PROFILE}.json" "${LOCAL_PROFILES_DIR}/${PROFILE}.json"
      echo "Copied profile '$PROFILE' to local .claude/profiles/"
    fi
  fi
  apply_profile "$PROFILE"
fi

# If there are passthrough args or no profile was specified, run claude
if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]] || [[ -z "$PROFILE" ]]; then
  # Detect active profile (local takes precedence)
  local_settings=".claude/settings.local.json"
  if [[ -f "$local_settings" ]]; then
    current=$(detect_profile "$local_settings")
    current="$current (local)"
  else
    current=$(detect_profile "$GLOBAL_SETTINGS_FILE")
  fi
  echo -e "\033[90m⚡ Profile: ${current}\033[0m"
  printf '\033]0;claude [%s]\007' "$current"
  
  # If using non-native profile, set env vars directly
  current_base="${current% (local)}"
  if [[ "$current_base" != "claude" ]]; then
    unset ANTHROPIC_AUTH_TOKEN
    
    # Determine which profile file to use
    if [[ -f "$local_settings" ]]; then
      # Export env vars from local settings file directly
      if jq -e '.env' "$local_settings" > /dev/null 2>&1; then
        while IFS='=' read -r key value; do
          export "$key"="$value"
        done < <(jq -r '.env | to_entries | .[] | "\(.key)=\(.value)"' "$local_settings")
      fi
    else
      # Fall back to profile file
      profile_file="${PROFILES_DIR}/${current_base}.json"
      if [[ -f "$profile_file" ]] && jq -e '.env' "$profile_file" > /dev/null 2>&1; then
        while IFS='=' read -r key value; do
          export "$key"="$value"
        done < <(jq -r '.env | to_entries | .[] | "\(.key)=\(.value)"' "$profile_file")
      fi
    fi
  fi
  
  exec "$CLAUDE_BIN" "${PASSTHROUGH_ARGS[@]}"
fi
WRAPPER

  chmod +x "${CLAUDE_DIR}/claude"
  echo "✓ Created wrapper script"
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

echo
echo "╔═══════════════════════════════════════════╗"
echo "║   Setup Complete!                         ║"
echo "╚═══════════════════════════════════════════╝"
echo
echo "Usage:"
echo "  claude --profile zai      # Switch to z.ai"
echo "  claude --profile claude   # Switch to native"
echo "  claude --list-profiles    # List profiles"
echo "  /profile zai              # Switch from within Claude"
echo
echo "After Claude updates, run:"
echo "  $0 --repair"
echo
