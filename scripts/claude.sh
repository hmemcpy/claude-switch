#!/bin/bash
# Claude Code profile switcher - Shell function version
# Source this file from ~/.zshrc or ~/.bashrc:
#   source ~/git/switch/scripts/claude.sh

# Prevent double-loading
[[ -n "$__CLAUDE_PROFILE_LOADED" ]] && return
__CLAUDE_PROFILE_LOADED=1

__claude_profiles_dir() {
  echo "${HOME}/.claude/profiles"
}

__claude_list_profiles() {
  local profiles_dir
  profiles_dir="$(__claude_profiles_dir)"
  echo "Available profiles:"
  for f in "${profiles_dir}"/*.json; do
    [[ -f "$f" ]] && echo "  - $(basename "$f" .json)"
  done
}

__claude_detect_profile() {
  local settings_file="${1:-$HOME/.claude/settings.json}"
  if [[ ! -f "$settings_file" ]]; then
    echo "claude"
    return
  fi
  
  if jq -e '.env.ANTHROPIC_BASE_URL' "$settings_file" > /dev/null 2>&1; then
    local url
    url=$(jq -r '.env.ANTHROPIC_BASE_URL' "$settings_file")
    if [[ "$url" == *"z.ai"* ]]; then
      echo "zai"
    elif [[ "$url" == *"127.0.0.1:8080"* ]]; then
      echo "cerebras"
    else
      echo "custom"
    fi
  else
    echo "claude"
  fi
}

__claude_get_local_profile() {
  local profile_file=".claude/profile"
  if [[ -f "$profile_file" ]]; then
    cat "$profile_file" | tr -d '[:space:]'
  fi
}

__claude_apply_profile() {
  local profile="$1"
  local profile_file="$HOME/.claude/profiles/${profile}.json"
  
  if [[ ! -f "$profile_file" ]]; then
    echo "Error: Profile '$profile' not found at $profile_file" >&2
    __claude_list_profiles >&2
    return 1
  fi
  
  # Always work locally - create .claude/settings.local.json
  mkdir -p ".claude"
  echo "$profile" > ".claude/profile"
  
  local local_settings=".claude/settings.local.json"
  if [[ ! -f "$local_settings" ]]; then
    echo '{}' > "$local_settings"
  fi
  
  # For native claude profile (only has "remove", no "env"), override with empty strings
  if jq -e '.remove' "$profile_file" > /dev/null 2>&1 && ! jq -e '.env' "$profile_file" > /dev/null 2>&1; then
    # Native profile: set all keys to empty string to override any global settings
    local empty_env='{}'
    for key in $(jq -r '.remove[]' "$profile_file"); do
      empty_env=$(echo "$empty_env" | jq --arg k "$key" '. + {($k): ""}')
    done
    jq --argjson eenv "$empty_env" '.env = $eenv' "$local_settings" > "${local_settings}.tmp"
    mv "${local_settings}.tmp" "$local_settings"
  elif jq -e '.env' "$profile_file" > /dev/null 2>&1; then
    # Non-native profile: apply env vars from profile
    local profile_env
    profile_env=$(jq '.env // {}' "$profile_file")
    jq --argjson penv "$profile_env" '.env = $penv' "$local_settings" > "${local_settings}.tmp"
    mv "${local_settings}.tmp" "$local_settings"
    
    # Ensure onboarding is complete for non-native profiles
    local claude_json="${HOME}/.claude.json"
    if [[ -f "$claude_json" ]]; then
      jq '. + {hasCompletedOnboarding: true}' "$claude_json" > "${claude_json}.tmp"
      mv "${claude_json}.tmp" "$claude_json"
    else
      echo '{"hasCompletedOnboarding": true}' > "$claude_json"
    fi
  fi
  
  echo "Set profile: $profile (in .claude/settings.local.json)"
}

__claude_show_status() {
  local global_profile local_profile active
  global_profile=$(__claude_detect_profile "$HOME/.claude/settings.json")
  local_profile="(none)"

  # Check .claude/profile file first (matches how claude() detects profile)
  local profile_from_file
  profile_from_file=$(__claude_get_local_profile)
  if [[ -n "$profile_from_file" ]]; then
    local_profile="$profile_from_file"
  elif [[ -f ".claude/settings.local.json" ]]; then
    local_profile=$(__claude_detect_profile ".claude/settings.local.json")
  fi

  active="$global_profile"
  if [[ "$local_profile" != "(none)" ]]; then
    active="$local_profile (local)"
  fi

  echo "Global profile: $global_profile"
  echo "Local profile:  $local_profile"
  echo "Active:         $active"
}

__claude_get_bin() {
  # Check common locations directly (command -v returns the function, not binary)
  if [[ -x "$HOME/.local/bin/claude" ]]; then
    echo "$HOME/.local/bin/claude"
  elif [[ -x "$HOME/.local/bin/claude-bin" ]]; then
    # Old wrapper approach - use the real binary
    echo "$HOME/.local/bin/claude-bin"
  elif [[ -x "/usr/local/bin/claude" ]]; then
    echo "/usr/local/bin/claude"
  fi
}

claude() {
  local CLAUDE_BIN
  CLAUDE_BIN=$(__claude_get_bin)
  
  if [[ -z "$CLAUDE_BIN" ]] || [[ ! -x "$CLAUDE_BIN" ]]; then
    echo "Error: Claude binary not found" >&2
    return 1
  fi
  
  local profile=""
  local passthrough_args=()
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile="$2"
        shift 2
        ;;
      --list-profiles)
        __claude_list_profiles
        return 0
        ;;
      --current-profile)
        echo "Current: $(__claude_detect_profile)"
        return 0
        ;;
      --status)
        __claude_show_status
        return 0
        ;;
      --update)
        echo "Updating Claude..."
        command "$CLAUDE_BIN" update
        return $?
        ;;
      *)
        passthrough_args+=("$1")
        shift
        ;;
    esac
  done
  
  # Apply profile if specified (always local)
  if [[ -n "$profile" ]]; then
    __claude_apply_profile "$profile" || return 1
  fi
  
  # If only switching profile (no other args), we're done
  if [[ ${#passthrough_args[@]} -eq 0 ]] && [[ -n "$profile" ]]; then
    return 0
  fi
  
  # Detect active profile: .claude/profile file takes precedence, then global
  local current current_base local_profile is_local=false
  local_profile=$(__claude_get_local_profile)
  if [[ -n "$local_profile" ]]; then
    current_base="$local_profile"
    current="$local_profile (local)"
    is_local=true
  else
    current_base=$(__claude_detect_profile "$HOME/.claude/settings.json")
    current="$current_base"
  fi
  
  # Show profile indicator
  echo -e "\033[90m⚡ Profile: ${current}\033[0m"
  printf '\033]0;claude [%s]\007' "$current"
  
  # Z.ai-specific env vars that we manage
  local zai_vars=(
    ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY API_TIMEOUT_MS
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC ANTHROPIC_DEFAULT_OPUS_MODEL
    ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
  )
  
  # Always unset z.ai vars first to start clean
  for var in "${zai_vars[@]}"; do
    unset "$var"
  done
  
  # Set env vars based on profile
  if [[ "$current_base" != "claude" ]]; then
    # Non-native profile: load env vars from the profile file
    local profile_file="$HOME/.claude/profiles/${current_base}.json"
    if [[ -f "$profile_file" ]] && jq -e '.env' "$profile_file" > /dev/null 2>&1; then
      while IFS='=' read -r key value; do
        export "$key"="$value"
      done < <(jq -r '.env | to_entries | .[] | "\(.key)=\(.value)"' "$profile_file")
    else
      echo "Warning: Profile file not found or has no env: $profile_file" >&2
    fi
  fi
  
  # Always load user's custom env vars from local settings (non-z.ai vars only)
  local local_settings=".claude/settings.local.json"
  if [[ -f "$local_settings" ]] && jq -e '.env' "$local_settings" > /dev/null 2>&1; then
    while IFS='=' read -r key value; do
      # Skip z.ai-managed vars
      local is_zai=false
      for zai_var in "${zai_vars[@]}"; do
        [[ "$key" == "$zai_var" ]] && is_zai=true && break
      done
      $is_zai || export "$key"="$value"
    done < <(jq -r '.env | to_entries | .[] | "\(.key)=\(.value)"' "$local_settings")
  fi
  
  # Call the real claude
  command "$CLAUDE_BIN" "${passthrough_args[@]}"
}
