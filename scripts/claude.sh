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
  local use_local="$2"
  local profiles_dir settings_file profile_file
  
  if [[ "$use_local" == "true" ]]; then
    # Create the profile marker file
    mkdir -p ".claude"
    echo "$profile" > ".claude/profile"
    echo "Set local profile to: $profile"
    return 0
  else
    profiles_dir="$HOME/.claude/profiles"
    settings_file="$HOME/.claude/settings.json"
  fi
  
  profile_file="${profiles_dir}/${profile}.json"
  
  if [[ ! -f "$profile_file" ]]; then
    echo "Error: Profile '$profile' not found at $profile_file" >&2
    __claude_list_profiles >&2
    return 1
  fi
  
  # Ensure settings file exists
  if [[ ! -f "$settings_file" ]]; then
    mkdir -p "$(dirname "$settings_file")"
    echo '{}' > "$settings_file"
  fi
  
  # Step 1: Remove keys if specified
  if jq -e '.remove' "$profile_file" > /dev/null 2>&1; then
    local keys_to_remove
    keys_to_remove=$(jq -c '.remove' "$profile_file")
    
    # Remove the keys from env
    jq --argjson remove "$keys_to_remove" '.env = ((.env // {}) | with_entries(select(.key as $k | $remove | index($k) | not)))' "$settings_file" > "${settings_file}.tmp"
    mv "${settings_file}.tmp" "$settings_file"
  fi
  
  # Step 2: Add/merge env vars if specified
  if jq -e '.env' "$profile_file" > /dev/null 2>&1; then
    local profile_env
    profile_env=$(jq '.env // {}' "$profile_file")
    
    jq --argjson penv "$profile_env" '.env = ((.env // {}) * $penv)' "$settings_file" > "${settings_file}.tmp"
    mv "${settings_file}.tmp" "$settings_file"
    
    # For non-claude profiles, ensure onboarding is complete
    local claude_json="${HOME}/.claude.json"
    if [[ -f "$claude_json" ]]; then
      jq '. + {hasCompletedOnboarding: true}' "$claude_json" > "${claude_json}.tmp"
      mv "${claude_json}.tmp" "$claude_json"
    else
      echo '{"hasCompletedOnboarding": true}' > "$claude_json"
    fi
  fi
  
  echo "Switched to profile: $profile"
}

__claude_show_status() {
  local global_profile local_profile active
  global_profile=$(__claude_detect_profile "$HOME/.claude/settings.json")
  local_profile="(none)"
  local local_settings=".claude/settings.local.json"
  
  if [[ -f "$local_settings" ]]; then
    local_profile=$(__claude_detect_profile "$local_settings")
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
  local use_local=false
  local passthrough_args=()
  
  # First pass: check for --local
  for arg in "$@"; do
    if [[ "$arg" == "--local" ]]; then
      use_local=true
      break
    fi
  done
  
  # Second pass: parse all arguments
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
      --local)
        shift
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
  
  # Apply profile if specified
  if [[ -n "$profile" ]]; then
    __claude_apply_profile "$profile" "$use_local" || return 1
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
