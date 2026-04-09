# minimal-claude-status-line

A minimal, information-dense status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that keeps you aware of context usage, rate limits, git state, and session cost — all at a glance to improve productivity.

```
myproject/feat-auth ⑂wt │ Opus 4.6 │ 26% 51.7K/200.0K ctx │ ↓40.4K ↑7.5K ♻51.1K │ rate 29% 5h ~2h0m 24% 7d ~3d0h Apr12 │ session 5m47s │ $0.8
```

## What it shows

| Segment | Example | Description |
|---|---|---|
| **Repo/Branch** | `myproject/main` | Current directory + git branch. Branch is **cyan** when clean, **yellow** when dirty (uncommitted changes). Hidden when not in a git repo. |
| **Worktree** | `⑂wt` | Purple indicator when working in a git worktree (common with `claude --worktree`). Hidden when not in a worktree. |
| **Model** | `Opus 4.6` | Current Claude model. Color-coded by effort level: **purple** = high, **green** = medium, **blue** = low. |
| **Context** | `26% 51.7K/200.0K ctx` | Context window usage — percentage + tokens used / total capacity. |
| **Tokens** | `↓40.4K ↑7.5K ♻51.1K` | Session totals — ↓ input, ↑ output, ♻ cache read tokens. |
| **5h Rate** | `29% 5h ~2h0m` | 5-hour rate limit usage with countdown to reset. |
| **7d Rate** | `24% 7d ~3d0h Apr12` | 7-day rate limit usage with countdown and reset date. |
| **Session** | `session 5m47s` | How long the current session has been running. |
| **Cost** | `$0.8` | Running session cost in USD. |

## Color coding

All percentages (context, 5h rate, 7d rate) use a consistent color scale:

| Range | Color | Meaning |
|---|---|---|
| < 50% | Green | Comfortable |
| 50–80% | Yellow | Watch it |
| > 80% | Orange | Take action — compact context or pace your rate usage |

## Quick install

```bash
curl -o ~/.claude/status-line.sh https://raw.githubusercontent.com/millenniumbismay/minimal-claude-status-line/main/status-line.sh && chmod +x ~/.claude/status-line.sh && python3 -c "
import json, os
p = os.path.expanduser('~/.claude/settings.json')
d = json.load(open(p)) if os.path.exists(p) else {}
d['statusLine'] = {'type': 'command', 'command': os.path.expanduser('~/.claude/status-line.sh')}
json.dump(d, open(p, 'w'), indent=2)
print('Done! Restart Claude Code to see the status line.')
"
```

Restart Claude Code after running the command.

## Requirements

- **Claude Code** (CLI) — the status line feature requires a recent version
- **jq** — for parsing the JSON data Claude Code passes to the script
- **git** — for branch and dirty-state detection
- **bc** — for token number formatting (pre-installed on macOS and most Linux)

## Manual installation

<details>
<summary>Step-by-step instructions</summary>

### 1. Download the script

```bash
# Clone the repo
git clone https://github.com/millenniumbismay/minimal-claude-status-line.git

# Or just download the script directly
curl -o ~/.claude/status-line.sh https://raw.githubusercontent.com/millenniumbismay/minimal-claude-status-line/main/status-line.sh
```

### 2. Place it in your Claude config directory

```bash
cp minimal-claude-status-line/status-line.sh ~/.claude/status-line.sh
chmod +x ~/.claude/status-line.sh
```

### 3. Configure Claude Code

Add the `statusLine` block to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/status-line.sh"
  }
}
```

If you already have a `settings.json`, just add the `statusLine` key at the top level.

### 4. Restart Claude Code

Start a new session or restart Claude Code. The status line appears at the bottom of the terminal.

</details>

## How it works

Claude Code's status line feature runs a shell command and displays its stdout at the bottom of the terminal. On each update, Claude Code pipes a JSON object to the script's stdin containing session metadata:

- Model info, context window usage, and token counts
- Rate limit percentages and reset timestamps
- Cost and duration
- Working directory and worktree state

This script parses that JSON with `jq`, formats the values with ANSI color codes, and outputs a single line.

## Effort level detection

The model name color reflects your current effort level setting from `~/.claude/settings.json`:

| Effort | Color | Setting |
|---|---|---|
| High | Purple | `"effortLevel": "high"` |
| Medium | Green | `"effortLevel": "medium"` (default) |
| Low | Blue | `"effortLevel": "low"` |

You can change effort level in Claude Code with the `/effort` command.

## Git branch colors

| State | Color | Meaning |
|---|---|---|
| Clean | Cyan | No uncommitted changes |
| Dirty | Yellow | Uncommitted changes exist |

This helps you notice when you have unsaved work before switching branches or ending a session.

## Worktree indicator

When you're working inside a git worktree (e.g., via `claude --worktree`), a purple `⑂wt` badge appears next to the branch name. This is detected via:

1. The `worktree` field in Claude Code's JSON data
2. Fallback: checking if `.git` points to a worktree path

## Token formatting

Large numbers are automatically shortened:

| Value | Display |
|---|---|
| 500 | `500` |
| 12,300 | `12.3K` |
| 1,500,000 | `1.5M` |

## Customization

The script is a single bash file — edit it to fit your preferences:

- **Remove segments** you don't need by deleting the corresponding `seg` variable and removing it from the final `printf`
- **Change colors** by modifying the ANSI codes (e.g., `\033[32m` for green, `\033[33m` for yellow)
- **Adjust thresholds** in the `pcc()` function to change when colors shift
- **Add segments** by parsing additional fields from the JSON — run `echo '{}' | jq .` on the debug output to see all available fields

### Seeing the raw JSON data

To inspect what Claude Code sends to the script, temporarily add this line after `data=$(cat)`:

```bash
echo "$data" > /tmp/claude-statusline-debug.json
```

Then check `/tmp/claude-statusline-debug.json` after a session update.

## Troubleshooting

**Status line not appearing?**
- Ensure the script is executable: `chmod +x ~/.claude/status-line.sh`
- Verify `settings.json` has the correct `statusLine` config with `"type": "command"`
- Restart Claude Code

**Numbers showing as 0?**
- Check that `jq` is installed: `which jq`
- Inspect the raw JSON (see above) to verify field names match your Claude Code version

**Git branch not showing?**
- You're not inside a git repository. The branch segment is hidden for non-git directories.

**Rate limits not showing?**
- Rate limit data is only available with Claude Pro/Max subscriptions. API/Console users may not see this field.

## License

MIT
