# Claude Profile Switcher

A utility to quickly switch Claude Code between native Anthropic and [z.ai](https://z.ai) (GLM-4.7) backends.

## Features

- Switch profiles via command line: `claude --profile zai`
- Switch from within Claude: `/profile zai`
- Profile indicator in terminal title and startup banner
- Preserves all other settings (MCP servers, permissions, etc.)
- **Survives Claude updates** - no repair needed!

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [jq](https://jqlang.github.io/jq/) for JSON manipulation
- A [z.ai API key](https://z.ai/manage-apikey/apikey-list) (for z.ai profile)

## Installation

### Fresh Install

```bash
git clone https://github.com/hmemcpy/claude-switch.git ~/git/switch
cd ~/git/switch
./install.sh
```

The script will:
1. Create profile configurations in `~/.claude/profiles/`
2. Add a source line to your `~/.zshrc` or `~/.bashrc`
3. Ask for your z.ai API key

Then open a new terminal or run `source ~/.zshrc` to activate.

## Usage

### Command Line

```bash
claude --profile zai       # Switch to z.ai GLM-4.7 (creates .claude/settings.local.json)
claude --profile claude    # Switch to native Claude (creates .claude/settings.local.json)
claude --list-profiles     # List available profiles
claude --current-profile   # Show active profile
claude --status            # Show global, local, and active profiles
```

Profile switching is always per-project - it creates `.claude/settings.local.json` in the current directory. This way your global settings stay clean and each project can have its own profile.

### Inside Claude

```
/profile zai      # Switch to z.ai (restart required)
/profile claude   # Switch to native (restart required)
```

After switching inside Claude, run `claude -c` to restart and continue the conversation.

## How It Works

The switcher uses a shell function that wraps the `claude` command:

1. Sources `claude.sh` from your shell rc file
2. The `claude` function intercepts profile-related flags
3. Modifies `~/.claude/settings.json` (or `.claude/settings.local.json` for local)
4. Passes remaining arguments to the real `claude` binary

Because it's a shell function (not a wrapper script), Claude updates don't affect it.

## Profile Storage

- **Profile definitions**: `~/.claude/profiles/*.json`
- **Local settings**: `.claude/settings.local.json` (per-project, created by `--profile`)
- **Profile marker**: `.claude/profile` (stores current profile name)

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

## Troubleshooting

### Shell function not working

Make sure your rc file sources claude.sh:

```bash
# Check if sourced
grep "claude.sh" ~/.zshrc

# If not, add it
echo 'source ~/git/switch/scripts/claude.sh' >> ~/.zshrc
source ~/.zshrc
```

### Profile not applying

Check that jq is installed:

```bash
command -v jq || brew install jq
```

### Claude binary not found

The function looks for claude in these locations:
1. `command -v claude` result
2. `~/.local/bin/claude`
3. `~/.local/bin/claude-bin` (legacy)
4. `/usr/local/bin/claude`

## License

MIT
