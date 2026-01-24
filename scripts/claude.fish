#!/usr/bin/env fish
# Claude Code profile switcher - Fish shell wrapper
# Delegates to the bash implementation
# Source this file from ~/.config/fish/config.fish:
#   source ~/git/switch/scripts/claude.fish

set -g __CLAUDE_SCRIPT_DIR (dirname (status filename))

function claude
    bash -c "source '$__CLAUDE_SCRIPT_DIR/claude.sh' && claude $argv"
end
