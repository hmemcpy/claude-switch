# Claude Profile Switcher

A utility to quickly switch Claude Code between different API backends (native Anthropic, z.ai, OpenAI-compatible endpoints, etc.).

## Features

- Switch profiles via command line: `claude --profile myprofile`
- Switch from within Claude: `/profile myprofile`
- Create custom profiles interactively: `./install.sh --new`
- Profile indicator in terminal title and startup banner
- Preserves all other settings (MCP servers, permissions, etc.)
- **Survives Claude updates** - no repair needed!

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [jq](https://jqlang.github.io/jq/) for JSON manipulation

## Installation

```bash
git clone https://github.com/hmemcpy/claude-switch.git ~/git/switch
cd ~/git/switch
./install.sh
```

The script will:
1. Create the native `claude` profile in `~/.claude/profiles/`
2. Add a source line to your `~/.zshrc` or `~/.bashrc`

Then open a new terminal or run `source ~/.zshrc` to activate.

## Usage

### Command Line

```bash
claude --new-profile       # Create a new custom profile interactively
claude --profile zai       # Switch to zai profile (creates .claude/settings.local.json)
claude --profile claude    # Switch to native Claude
claude --list-profiles     # List available profiles
claude --current-profile   # Show active profile
claude --status            # Show global, local, and active profiles
```

### Creating Custom Profiles

Run `claude --new-profile` to create a new profile interactively. It will prompt for:
- **Profile name** (e.g., `zai`, `openai`, `local`)
- **API Base URL** (e.g., `https://api.z.ai/api/anthropic`)
- **API Key**
- **Model name** (used for opus/sonnet/haiku defaults)

Profile switching is always per-project - it creates `.claude/settings.local.json` in the current directory. This way your global settings stay clean and each project can have its own profile.

### Inside Claude

```
/profile zai      # Switch to zai (restart required)
/profile claude   # Switch to native (restart required)
```

After switching inside Claude, run `claude -c` to restart and continue the conversation.

## How It Works

The switcher uses a shell function that wraps the `claude` command:

1. Sources `claude.sh` from your shell rc file
2. The `claude` function intercepts profile-related flags
3. Creates `.claude/settings.local.json` with profile settings
4. Passes remaining arguments to the real `claude` binary

Because it's a shell function (not a wrapper script), Claude updates don't affect it.

## Profile Storage

- **Profile definitions**: `~/.claude/profiles/*.json`
- **Local settings**: `.claude/settings.local.json` (per-project, created by `--profile`)
- **Profile marker**: `.claude/profile` (stores current profile name)

## Manual Profile Creation

You can also create profiles manually in `~/.claude/profiles/`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint",
    "ANTHROPIC_AUTH_TOKEN": "your-api-key",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "your-model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "your-model",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "your-model"
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
1. `~/.local/bin/claude`
2. `~/.local/bin/claude-bin` (legacy)
3. `/usr/local/bin/claude`

## License

MIT
