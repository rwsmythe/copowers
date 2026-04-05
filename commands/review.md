---
description: "Run standalone adversarial review on code changes"
argument-hint: "[target]"
allowed-tools: [Read, Bash, Grep, Glob, Skill, Agent]
---

# copowers:review

Run a standalone adversarial Codex review on code changes without wrapping a superpowers phase.

## Determine Review Target

### If argument provided
Use the argument as the diff target:
- If it's a file path: review that file's changes
- If it's a branch name: `git diff <branch>...HEAD`
- If it's a commit range: `git diff <range>`

### If no argument (smart default)

```bash
git status --porcelain
```

**If output is non-empty** (dirty tree):
- Tracked changes: `git diff HEAD`
- Untracked files: `git ls-files --others --exclude-standard`
- For each untracked text file under 50KB, read content and format as `+++ new file: <path>` sections
- Text file extensions: `.py`, `.md`, `.yaml`, `.json`, `.txt`, `.j2`, `.xml`, `.toml`, `.cfg`, `.sh`, `.js`, `.ts`, `.html`, `.css`, `.sql`, `.rs`, `.go`, `.java`, `.c`, `.h`, `.cpp`, `.hpp`
- Binary/oversized files: note as "new binary/large file: <path> (not included)"
- Concatenate: tracked diff first, then untracked content

**If output is empty** (clean tree):
Try in order:
1. `git merge-base HEAD main` — if found: `git diff main...HEAD`
2. `git merge-base HEAD master` — if found: `git diff master...HEAD`
3. Upstream tracking branch: `git diff @{upstream}...HEAD`
4. Error: "No changes to review. Specify a target: `/copowers:review <branch|path|range>`"

### Truncation
If total content exceeds 8000 words, truncate and append:
> Showing {included} of {total} words. {N} files omitted.

Prioritize tracked diff over untracked content when truncating.

## Run Review

Invoke the adversarial-critic skill with:
- `PHASE`: `review`
- `DIFF`: the captured diff content

The adversarial-critic handles the multi-round Codex review loop and produces the standard output (rounds, issues, verdict).

## Write Session State

After the review completes, write to the session state file:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_HASH=$(echo -n "$REPO_ROOT" | sha256sum | cut -c1-12)
STATE_FILE="${TMPDIR:-.}/.copowers-session-${REPO_HASH}.json"
```

Read existing state (or create new with `{"schema_version": 1, "reviews": [], "reviewed_files": []}`).

Append to the `reviews` array:
```json
{
  "phase": "review",
  "timestamp": "<current ISO 8601>",
  "rounds": "<rounds from adversarial-critic>",
  "unresolved_critical": "<count>",
  "unresolved_major": "<count>",
  "verdict": "<approved|max_rounds_reached>",
  "reviewed_at_commit": "<current HEAD SHA>"
}
```

Write atomically (temp file + rename).
