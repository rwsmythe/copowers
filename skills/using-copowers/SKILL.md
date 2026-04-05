---
name: using-copowers
description: Use at session start - establishes copowers as the adversarial review wrapper for superpowers phases
---

# Using copowers

copowers wraps three superpowers phases with an independent Codex-powered adversarial review loop.
After each phase completes, Codex red-teams the output before it is presented to you.

## Skill Override Rules

**IMPORTANT:** When you would invoke any of the following superpowers skills, invoke the
copowers equivalent instead:

| Instead of | Invoke |
|---|---|
| `superpowers:brainstorming` | `copowers:brainstorming` |
| `superpowers:writing-plans` | `copowers:writing-plans` |
| `superpowers:subagent-driven-development` | `copowers:executing-plans` |
| `superpowers:executing-plans` | `copowers:executing-plans` |

All other superpowers skills (`superpowers:systematic-debugging`, `superpowers:test-driven-development`,
`superpowers:verification-before-completion`, `superpowers:requesting-code-review`, etc.)
are **unaffected** — invoke them directly as normal.

## Interception Rule

If the user explicitly requests a superpowers phase by name (e.g., "use superpowers:brainstorming"
or "/superpowers:brainstorming"), intercept and redirect:

> "copowers is active. I'll use `copowers:brainstorming` instead, which wraps superpowers:brainstorming
> with adversarial Codex review."

Then invoke the copowers equivalent. Never invoke the bare superpowers phase skill directly
when copowers is loaded.

## Why

The superpowers internal reviewer loops check for completeness (gaps, missing sections, TODOs).
The copowers adversarial layer is different: it uses Codex as an independent AI to red-team the
output for failure modes, edge cases, and risks that a completeness check cannot catch.

## Prerequisite Check

Before any copowers phase begins, verify Codex CLI is available:

```bash
command -v codex
```

If not found, inform the user:
> "copowers requires Codex CLI. Install with: `npm install -g @openai/codex`
> Then restart Claude Code to pick up the MCP server registration in copowers' `.mcp.json`."
