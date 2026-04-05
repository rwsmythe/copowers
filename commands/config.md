---
description: "View or modify copowers settings"
argument-hint: "[key] [value]"
allowed-tools: [Read, Write, Bash]
---

# copowers:config

View or modify copowers settings. Settings are loaded from two layers:
1. Plugin defaults: `${CLAUDE_PLUGIN_ROOT}/settings.yaml`
2. Project overrides: `.copowers.yaml` in project root (if exists)

Deep merge: project values override at the leaf level.

## No Arguments — Display Config

Read both config files and display the effective merged configuration.

```bash
cat "${CLAUDE_PLUGIN_ROOT}/settings.yaml"
```

```bash
cat .copowers.yaml 2>/dev/null || echo "(no project overrides)"
```

Display each setting with its source (default or project override):
```
copowers settings (effective):
  review.min_rounds:         2  (default)
  review.max_rounds:         3  (project: .copowers.yaml)
  review.stop_hook_severity: critical  (default)
  watchdog.file_threshold:   10  (default)
  watchdog.line_threshold:   300  (project: .copowers.yaml)
  watchdog.monitor_specs:    true  (default)
  watchdog.monitor_plans:    true  (default)
  watchdog.monitor_code:     true  (default)
  phases.brainstorming:      true  (default)
  phases.writing_plans:      true  (default)
  phases.executing_plans:    true  (default)
```

## With Arguments — Set Value

Format: `/copowers:config <dotted.key> <value>`

Examples:
- `/copowers:config review.max_rounds 3`
- `/copowers:config watchdog.line_threshold 300`
- `/copowers:config phases.brainstorming false`

### Behavior

1. Read existing `.copowers.yaml` from project root (or start with empty dict)
2. Parse the dotted key path (e.g., `review.max_rounds` -> `review` section, `max_rounds` key)
3. Coerce the value to match the type in plugin defaults (int for thresholds, bool for toggles, string for severity)
4. Write `.copowers.yaml` to project root using the Write tool

Confirm the change:
```
Set review.max_rounds = 3 in .copowers.yaml
```

### Validation

- If the key doesn't exist in plugin defaults, warn: "Unknown key: {key}. Setting anyway."
- Values are coerced: numbers to int, "true"/"false" to bool, everything else to string
