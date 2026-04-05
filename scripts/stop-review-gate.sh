#!/usr/bin/env bash
# copowers Stop hook — advisory warning on unresolved adversarial review issues
# Reads session state, warns if unresolved critical issues found.
# Exit 0 always (never blocks).

set -euo pipefail

# Determine session state file path
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$REPO_ROOT" ]; then
  exit 0  # Not in a git repo — nothing to check
fi

REPO_HASH=$(echo -n "$REPO_ROOT" | sha256sum | cut -c1-12)
STATE_FILE="${TMPDIR:-.}/.copowers-session-${REPO_HASH}.json"

if [ ! -f "$STATE_FILE" ]; then
  exit 0  # No session state — nothing to check
fi

# Parse the most recent review entry using python3 for reliable JSON parsing
python3 -c "
import json, sys
try:
    with open('${STATE_FILE}') as f:
        data = json.load(f)
    if data.get('schema_version') != 1:
        print('copowers: Review status unknown — unrecognized state format. Run /copowers:review to re-establish.', file=sys.stderr)
        sys.exit(0)
    reviews = data.get('reviews', [])
    if not reviews:
        sys.exit(0)
    latest = reviews[-1]
    critical = latest.get('unresolved_critical', 0)
    if critical > 0:
        print(f'copowers: Warning — {critical} unresolved critical issue(s) from adversarial review. Consider addressing before proceeding.', file=sys.stderr)
except (json.JSONDecodeError, KeyError, IOError):
    print('copowers: Review status unknown — session state unreadable. Run /copowers:review to re-establish.', file=sys.stderr)
" 2>&1

exit 0
