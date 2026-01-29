# Claude Profile Switcher

A utility to switch Claude Code between different API backends (native Anthropic, z.ai, OpenAI-compatible endpoints, etc.).

## Features

- Create custom profiles: `claude --new-profile`
- Switch profiles per-project: `claude --profile myprofile`
- Profile indicator in terminal title and startup banner
- **Survives Claude updates** - no wrapper to repair!

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [jq](https://jqlang.github.io/jq/) for JSON manipulation

## Installation

```bash
git clone https://github.com/hmemcpy/claude-switch.git ~/git/switch
cd ~/git/switch
./install.sh
```

Then open a new terminal or run `source ~/.zshrc` to activate.

## Usage

```bash
claude --new-profile       # Create a new custom profile interactively
claude --profile zai       # Switch to a profile (per-project)
claude --profile claude    # Switch to native Claude
claude --list-profiles     # List available profiles
claude --status            # Show current profile status
```

### Creating Profiles

Run `claude --new-profile` and enter:
- **Profile name** (e.g., `zai`, `openai`, `local`)
- **API Base URL** (e.g., `https://api.z.ai/api/anthropic`)
- **API Key**
- **Model name** (used for opus/sonnet/haiku)

### Switching Profiles

Profiles are per-project. Running `claude --profile <name>` creates `.claude/settings.local.json` in the current directory.

### Inside Claude

Use `/profile <name>` to switch, then restart with `claude -c`.

## How It Works

A shell function wraps `claude`, intercepts profile flags, creates local settings, and passes remaining args to the real binary. Because it's a shell function (not a wrapper script), Claude updates don't break it.

## Profile Storage

- `~/.claude/profiles/*.json` - Profile definitions
- `.claude/settings.local.json` - Per-project settings
- `.claude/profile` - Current profile marker

## License

MIT
