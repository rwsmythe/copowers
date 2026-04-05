---
description: "Validate Codex CLI and MCP server prerequisites for copowers"
allowed-tools: [Read, Bash, ToolSearch]
---

# copowers:setup

Validate that all prerequisites for copowers are working.

## Steps

Run each check and report results:

### 1. Codex CLI

```bash
command -v codex && codex --version 2>/dev/null || echo "NOT FOUND"
```

If not found:
> Codex CLI not installed. Install: `npm install -g @openai/codex`

### 2. MCP Server

Check that the `codex` and `codex-reply` MCP tools are available in the current session. Use ToolSearch to look for them. If the tools are not visible:
> Codex MCP server not connected. Restart Claude Code to pick up the MCP server registration from copowers plugin.

### 3. Plugin Version

Read `${CLAUDE_PLUGIN_ROOT}/plugin.json` and report the version.

### 4. Settings

Read the effective configuration:
1. Read `${CLAUDE_PLUGIN_ROOT}/settings.yaml` (plugin defaults)
2. Read `.copowers.yaml` from project root (if exists)
3. Report which layer is active

## Output Format

Report each check as:
```
copowers:setup
  Codex CLI:    [PASS] codex at /path/to/codex
  MCP Server:   [PASS] codex + codex-reply tools available
  Plugin:       copowers v2.0.0
  Settings:     defaults loaded (no project overrides)
```

Or on failure:
```
copowers:setup
  Codex CLI:    [FAIL] Not found — install: npm install -g @openai/codex
  MCP Server:   [FAIL] Tools not available — restart Claude Code
  Plugin:       copowers v2.0.0
  Settings:     defaults loaded
```
