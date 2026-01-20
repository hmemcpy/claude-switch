# Claude Profile Switcher

A utility to quickly switch Claude Code between native Anthropic and [z.ai](https://z.ai) (GLM-4.7) backends.

## Features

- Switch profiles via command line: `claude --profile zai`
- Switch from within Claude: `/profile zai`
- Profile indicator in terminal title and startup banner
- Preserves all other settings (MCP servers, permissions, etc.)

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [jq](https://jqlang.github.io/jq/) for JSON manipulation
- A [z.ai API key](https://z.ai/manage-apikey/apikey-list) (for z.ai profile)

## Installation

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/hmemcpy/claude-switch/main/setup-claude-profiles.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/hmemcpy/claude-switch.git
cd claude-switch
./setup-claude-profiles.sh
```

The script will:
1. Wrap the Claude binary to add profile switching
2. Ask for your z.ai API key
3. Create profile configurations

## Usage

### Command Line

```bash
claude --profile zai       # Switch to z.ai GLM-4.7
claude --profile claude    # Switch to native Claude
claude --list-profiles     # List available profiles
claude --current-profile   # Show active profile
claude --status            # Show global, local, and active profiles

# Local (project-specific) profiles
claude --profile zai --local  # Copy profile to ./.claude/profiles/ for this project
```

### Inside Claude

```
/profile zai      # Switch to z.ai (restart required)
/profile claude   # Switch to native (restart required)
```

After switching inside Claude, run `claude -c` to restart and continue the conversation.

## After Claude Updates

If Claude updates itself, the wrapper may be overwritten. Run:

```bash
./setup-claude-profiles.sh --repair
```

This re-wraps the binary without changing your profiles or API key.

## How It Works

The script creates a wrapper around the Claude binary that:
1. Intercepts `--profile` flag to modify `~/.claude/settings.json`
2. Displays the current profile on startup
3. Sets terminal title to show active profile

Profiles are stored in `~/.claude/profiles/` as JSON files with `env` (variables to set) and `remove` (variables to remove) sections.

## Adding Custom Profiles

Create a new JSON file in `~/.claude/profiles/`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint",
    "ANTHROPIC_AUTH_TOKEN": "your-api-key"
  },
  "remove": [
    "ANTHROPIC_API_KEY"
  ]
}
```

## License

MIT
