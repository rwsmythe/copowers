# copowers

Adversarial Codex review wrapper for [Claude Code](https://claude.ai/code) superpowers workflows.

copowers adds an independent AI reviewer (OpenAI Codex) to your design and implementation cycle. After each superpowers phase completes, Codex red-teams the output across multiple rounds until it returns a clean round — catching bugs, design gaps, and contract violations that the author missed.

**Degraded mode:** If the Codex MCP connection fails or returns no content during a round, that round is treated as clean to avoid blocking the user. A warning is logged and noted in the review summary. This means approval under MCP failure is best-effort, not guaranteed.

## Features

- **Multi-round adversarial review** — Codex plays devil's advocate, red team, and steelman opponent simultaneously. Reviews continue until Codex returns a clean round (no new critical/major issues), with a configurable minimum of 2 and maximum of 5 rounds.
- **Three review phases** — wraps brainstorming (specs), writing-plans (implementation plans), and executing-plans (code implementation) with independent review.
- **Standalone code review** — review any diff, branch, or file without a superpowers phase.
- **Full issue tracking** — every issue (critical, major, and minor) is logged and must be explicitly resolved or accepted with rationale. No issue is left unadjudicated.
- **Honest termination** — resolving issues locally does not satisfy termination. Codex must see the resolutions and return clean. Under normal operation, the adversarial reviewer has the final word, not the author (see degraded mode above for MCP failure behavior).
- **Watchdog agent** — proactively suggests review when it detects unreviewed specs, plans, or large code changes (configurable thresholds).
- **Session state** — tracks review history per repository in a temp file for cross-session continuity.

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI or IDE extension
- [Codex CLI](https://github.com/openai/codex) with MCP server support:
  ```bash
  npm install -g @openai/codex
  ```
- An OpenAI API key set via `OPENAI_API_KEY` environment variable (see [Codex setup](https://github.com/openai/codex#readme))

## Installation

Clone this repository into your Claude Code local marketplace plugins directory. The exact path depends on your platform:

| Platform | Path |
|----------|------|
| macOS/Linux | `~/.claude/plugins/marketplaces/local/plugins/` |
| Windows | `%USERPROFILE%\.claude\plugins\marketplaces\local\plugins\` |

```bash
# Example (macOS/Linux)
cd ~/.claude/plugins/marketplaces/local/plugins
git clone https://github.com/rwsmythe/copowers.git
```

Claude Code discovers plugins by scanning the `plugins/` directory for `plugin.json` files. The `.mcp.json` at the plugin root registers the Codex MCP server automatically.

Restart Claude Code to pick up the plugin and its MCP server registration.

Verify the installation:
```
/copowers:setup
```

## Usage

### Wrapping superpowers phases

Use copowers skills instead of bare superpowers skills:

| Instead of | Use | What it does |
|---|---|---|
| `superpowers:brainstorming` | `/copowers:brainstorming` | Write spec, then Codex reviews it |
| `superpowers:writing-plans` | `/copowers:writing-plans` | Write plan, then Codex reviews it |
| `superpowers:subagent-driven-development` | `/copowers:executing-plans` | Implement code, then Codex reviews the diff |
| `superpowers:executing-plans` | `/copowers:executing-plans` | Same as above (alias) |

Each wrapper runs the superpowers phase to completion, then invokes the adversarial critic for multi-round review. Issues are resolved or accepted before the output is presented.

### Standalone review

Review code changes without a superpowers phase:

```
/copowers:review              # Reviews uncommitted changes (smart default)
/copowers:review main         # Reviews changes since main branch
/copowers:review src/foo.py   # Reviews a specific file's changes
```

### Session initialization

At the start of a session, invoke:
```
/copowers:using-copowers
```

This establishes copowers as the default wrapper — Claude Code will use copowers equivalents whenever superpowers skills are invoked.

## How the Review Loop Works

```
┌─────────────────────────────────────────┐
│  Phase completes (spec/plan/code)       │
└────────────────┬────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────┐
│  Round N: Codex reviews artifacts       │
│  → Returns critical/major/minor issues  │
└────────────────┬────────────────────────┘
                 │
         ┌───────┴────────┐
         │ Issues found?  │
         └───┬────────┬───┘
          Yes│        │No (and round >= 2)
             v        v
┌────────────────┐  ┌──────────────┐
│ Resolve/Accept │  │  APPROVED    │
│ each issue     │  │  Output      │
└───────┬────────┘  └──────────────┘
        │
        v
   Go to Round N+1
   (Codex verifies resolutions)
```

- **Minimum 2 rounds** — even if round 1 is clean, round 2 confirms
- **Maximum 5 rounds** — prevents infinite loops; unresolved issues are flagged
- **All severities adjudicated** — critical, major, and minor issues all require an explicit "Resolved" or "Accepted with rationale" decision

## Configuration

Settings are loaded from two layers (deep merge):

1. **Plugin defaults:** `settings.yaml` in the plugin root
2. **Project overrides:** `.copowers.yaml` in your project root

```yaml
# .copowers.yaml — full configuration reference
review:
  min_rounds: 2                   # Minimum review rounds before termination
  max_rounds: 5                   # Maximum review rounds (hard cap)
  stop_hook_severity: "critical"  # Reserved — not yet implemented in stop hook

watchdog:
  file_threshold: 10              # Files changed to trigger review suggestion
  line_threshold: 500             # Lines changed to trigger review suggestion
  monitor_specs: true             # Watch docs/superpowers/specs/ for new specs
  monitor_plans: true             # Watch docs/superpowers/plans/ for new plans
  monitor_code: true              # Watch source code for large changes

phases:
  brainstorming: true             # Enable copowers wrapper for brainstorming
  writing_plans: true             # Enable copowers wrapper for writing-plans
  executing_plans: true           # Enable copowers wrapper for executing-plans
```

### Commands

```
/copowers:config                           # View current settings
/copowers:config review.max_rounds 3       # Change a setting
/copowers:setup                            # Verify prerequisites
```

## Watchdog Agent

The copowers watchdog runs in the background and suggests adversarial review when it detects:

- New files in `docs/superpowers/specs/` or `docs/superpowers/plans/`
- Uncommitted changes exceeding the configured thresholds (default: 10+ files or 500+ lines)

The watchdog is advisory — it suggests review but does not block work. Configure thresholds via `watchdog.*` settings.

## Session State

copowers tracks review history in a per-repository temp file:

```
${TMPDIR:-.}/.copowers-session-<repo-hash>.json
```

This file records which phases were reviewed, how many rounds each took, and the verdict. It is used by the watchdog to detect unreviewed changes.

- **Location:** `$TMPDIR` if set, otherwise the current working directory (`.`). On most systems `TMPDIR` points outside the repo, but when unset the file is created in whatever directory the command runs from — which may be the repo root or a subdirectory. Add `.copowers-session-*.json` to `.gitignore` if needed.
- **Privacy:** contains file paths and commit SHAs, no code content
- **Reset:** delete the file to clear review history
- **Durability:** persists across sessions. May be cleared by the OS on reboot (depends on temp directory retention policy)

## Plugin Structure

```
copowers/
├── .claude-plugin/plugin.json   # Marketplace manifest
├── .mcp.json                    # Codex MCP server registration
├── plugin.json                  # Plugin metadata and version
├── settings.yaml                # Default configuration
├── skills/
│   ├── adversarial-critic/      # Core review loop (internal)
│   ├── brainstorming/           # Wraps superpowers:brainstorming
│   ├── writing-plans/           # Wraps superpowers:writing-plans
│   ├── executing-plans/         # Wraps superpowers:executing-plans
│   └── using-copowers/          # Session initialization
├── commands/
│   ├── review.md                # /copowers:review — standalone review
│   ├── config.md                # /copowers:config — settings management
│   └── setup.md                 # /copowers:setup — prerequisite validation
├── agents/
│   └── copowers-watchdog.md     # Suggests review for unreviewed changes
├── hooks/
│   └── hooks.json               # Hook definitions
├── references/
│   └── adversarial-review-guide.md
└── scripts/
    └── stop-review-gate.sh
```

## Issue Severity Levels

| Severity | Meaning | Blocks approval? |
|----------|---------|-----------------|
| **Critical** | Fundamental flaw that invalidates the output | Yes |
| **Major** | Significant gap, risk, or error to address or explicitly accept | Yes |
| **Minor** | Advisory observation | No, but must be adjudicated |

## License

MIT

## Contributing

Issues and pull requests welcome at https://github.com/rwsmythe/copowers.
