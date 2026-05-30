---
name: adversarial-critic
description: Internal skill - adversarial Codex review loop via MCP. Called by copowers wrapper skills after phase completion.
---

# Adversarial Critic

Run an adversarial Codex-powered review loop after a superpowers phase completes.
This skill is called internally by copowers wrapper skills — do not invoke directly.

Codex is invoked via its MCP server tools (`codex` and `codex-reply`), not as a bash
subprocess. Thread continuity via `threadId` means Codex retains full context across
rounds — only deltas need to be passed in subsequent rounds.

**Transport fallback:** where the MCP tools are unavailable or unusable (e.g. the Claude Code
VS Code extension imposes a ~1s fire-and-forget MCP tool deadline that the long-running `codex`
tool can never meet), drive Codex through the Linux Codex CLI inside WSL instead — see
**CLI Fallback (Codex via WSL)** below. Same review loop and prompts; only the invocation differs.

When combined artifact content is large (spec + plan + diff can easily exceed inline prompt
limits), artifacts are written to temp files and Codex reads them from disk. See the
**Extended Context Passing** section below.

## Context Required from Caller

The wrapper skill must provide the following before invoking this skill:

| Variable | Provided by |
|---|---|
| `PHASE` | `brainstorming`, `writing-plans`, `executing-plans`, or `review` |
| `SPEC_PATH` | Absolute path to spec doc (all phases) |
| `PLAN_PATH` | Absolute path to plan doc (writing-plans and executing-plans only) |
| `ORIGINAL_REQUEST` | The user's verbatim original request (brainstorming only) |
| `BASELINE_SHA` | Git commit SHA before execution began (executing-plans only) |
| `DIFF` | Code changes to review (review only) |

## Prerequisites

Verify the Codex MCP tools are available. These are registered via `.mcp.json` in the
copowers plugin root. If the tools `codex` and `codex-reply` are not visible in the MCP
tool list, instruct the user:
> "copowers requires Codex CLI with its MCP server. Install: `npm install -g @openai/codex`
> Then restart Claude Code to pick up the MCP server registration."

## Setup

Initialize state:

```
ROUND = 0
THREAD_ID = null          # set after round 1 from Codex MCP response
issues_log = []           # accumulates: {round, issue, severity, resolution, status}
minor_log = []            # accumulates: {round, issue, resolution, status}
                          # status: "resolved" or "accepted", resolution: text
```

**Read configuration** (deep merge):
1. Read `${CLAUDE_PLUGIN_ROOT}/settings.yaml` for plugin defaults
2. Read `.copowers.yaml` from project root for overrides (if exists)
3. Set: `MIN_ROUNDS = config.review.min_rounds` (default: 2)
4. Set: `MAX_ROUNDS = config.review.max_rounds` (default: 5)

If neither file is readable, use hardcoded defaults (MIN_ROUNDS=2, MAX_ROUNDS=5).

Read artifact content based on phase:

- **brainstorming**: Read full content of `SPEC_PATH`
- **writing-plans**: Read full content of `PLAN_PATH` and `SPEC_PATH`
- **executing-plans**:
  - Run `git diff BASELINE_SHA..HEAD` via Bash — store as `GIT_DIFF`
  - If `GIT_DIFF` exceeds ~8000 words, truncate to first 8000 words and append `[truncated — diff too large]`
  - Read full content of `PLAN_PATH` and `SPEC_PATH`
- **review**: The caller provides `DIFF` containing the code changes to review.
  No SPEC_PATH or PLAN_PATH required.

## Extended Context Passing

Codex MCP tool prompts have practical size limits. When combined artifact content (spec +
plan + diff) is large, inline prompts become unreliable — content may be truncated or the
tool call may fail.

**Threshold:** If the total artifact content exceeds ~4000 words, use file-based passing.

**Mechanism:**

1. Write each artifact to a temp file in the project root:
   - `SPEC_PATH` content → `.copowers-review-spec.md`
   - `PLAN_PATH` content → `.copowers-review-plan.md`
   - `GIT_DIFF` content → `.copowers-review-diff.txt`
   - `ORIGINAL_REQUEST` → `.copowers-review-request.txt`

2. In the Codex prompt, reference the files instead of inlining content:
   ```
   === ARTIFACTS ===

   Read the following files for the artifacts to review:
   - Spec: .copowers-review-spec.md
   - Plan: .copowers-review-plan.md

   Review these artifacts adversarially.
   ```

3. Pass `cwd` to the Codex MCP tool pointing to the project root, and use `sandbox: "read-only"`
   so Codex can read the temp files.

4. **Cleanup:** After the review loop completes (all rounds done), delete the temp files:
   ```bash
   rm -f .copowers-review-spec.md .copowers-review-plan.md .copowers-review-diff.txt .copowers-review-request.txt
   ```

**When content fits inline (~4000 words or less):** Skip the file mechanism and include
artifact content directly in the prompt as before. This avoids unnecessary file I/O for
small artifacts.

**Round 2+ prompts** are always inline (delta-only) since they contain only resolutions and
changed sections, which are small. The temp files are only needed for round 1.

## CLI Fallback (Codex via WSL)

Use this when the Codex **MCP** tools are unavailable or unusable. (On the Claude Code VS Code
extension for Windows the MCP tools always time out: the extension hardcodes a ~1s
fire-and-forget tool deadline that a full Codex agent turn cannot meet. The Windows-native
Codex CLI is not a substitute — its sandbox is broken, so it cannot read files. The **Linux**
Codex CLI inside WSL is the working path, and it reads artifact files directly from disk.)

**One-time prerequisite (per machine):** Linux Codex installed in WSL with auth. Check with
`wsl -e bash -c 'export PATH="$HOME/.local/node22/bin:$PATH"; codex --version'`. If missing:
install Node in WSL, `npm install -g @openai/codex`, then reuse the Windows auth via
`cp /mnt/c/Users/<winuser>/.codex/auth.json ~/.codex/auth.json` (account-scoped tokens, no re-login).

**Path translation:** a Windows project path `C:\Users\me\repo` is `WSL_ROOT=/mnt/c/Users/me/repo`
in WSL (lowercase drive letter, forward slashes). Compute `WSL_ROOT` from the project root.

**Round 1:**
1. Write the artifact temp files to the project root exactly as in *Extended Context Passing*.
   Codex reads them itself from disk — no inlining, no prompt-size limit.
2. Write the Round-1 prompt (the **file-based variant** from Step B, which references those files
   by name) to `.copowers-review-prompt.txt` in the project root.
3. Invoke (prompt piped via stdin to avoid arg-length limits):
   ```bash
   wsl -e bash -c 'export PATH="$HOME/.local/node22/bin:$PATH"; codex exec -s read-only --skip-git-repo-check -C "WSL_ROOT" - < "WSL_ROOT/.copowers-review-prompt.txt"'
   ```
   Codex runs read-only (no writes, no network) and reads the artifacts from disk. The review text
   is on stdout — parse it exactly as a Step D response. (Read-only grants broad filesystem read,
   so Codex can also follow references outside the repo.)

**Round 2+:** thread continuity is via `resume --last` (there is no `threadId` on the CLI). Write
the delta prompt (Step B round-2 format) to `.copowers-review-prompt.txt`, then:
   ```bash
   wsl -e bash -c 'export PATH="$HOME/.local/node22/bin:$PATH"; codex exec resume --last -c sandbox_mode="read-only" --skip-git-repo-check - < "WSL_ROOT/.copowers-review-prompt.txt"'
   ```
   `resume` does NOT accept the `-s` flag — set the sandbox via `-c sandbox_mode="read-only"`.

**Failure handling:** if a WSL `codex` call errors (non-zero exit, or no parseable verdict), log a
warning and surface it — do NOT silently treat the round as clean.

**Cleanup:** remove `.copowers-review-prompt.txt` along with the artifact temp files.

## Loop

Repeat the following steps until the termination condition is met:

### Step A: Increment round

```
ROUND = ROUND + 1
```

### Step B: Build prompt

**IMPORTANT:** Evaluate all `[If PHASE == X:]` conditionals using the actual value of `PHASE`
and include ONLY the matching block. Substitute all bracketed placeholders with actual values.

**Round 1 prompt** (full context):

If artifacts are small enough for inline passing (see Extended Context Passing above),
include them directly. If using file-based passing, replace the `=== ARTIFACTS ===` section
with file references as shown below.

**Inline variant** (artifacts fit in prompt):

```
You are an adversarial reviewer. Your job is to find problems with the following [PHASE] output.

Play all three roles simultaneously, as relevant to what you find:
- DEVIL'S ADVOCATE: Challenge design decisions. What alternatives were dismissed or not considered?
  What assumptions are baked in that could be wrong?
- RED TEAM: Find failure modes, edge cases, and ways this could go wrong in practice.
  What could break? What has been overlooked?
- STEELMAN OPPONENT: Construct the strongest possible argument AGAINST this output.
  What would a skeptical domain expert object to most strongly?

PHASE: [PHASE]

=== ARTIFACTS ===

[If PHASE == brainstorming: include this block only]
ORIGINAL USER REQUEST:
[ORIGINAL_REQUEST]

SPEC DOCUMENT ([SPEC_PATH]):
[full content of spec file]

[If PHASE == writing-plans: include this block only]
SPEC DOCUMENT ([SPEC_PATH]):
[full content of spec file]

PLAN DOCUMENT ([PLAN_PATH]):
[full content of plan file]

[If PHASE == executing-plans: include this block only]
SPEC DOCUMENT ([SPEC_PATH]):
[full content of spec file]

PLAN DOCUMENT ([PLAN_PATH]):
[full content of plan file]

GIT DIFF (baseline [BASELINE_SHA] to HEAD):
[GIT_DIFF content]

[If PHASE == review: include this block only]
CODE CHANGES FOR REVIEW:
[DIFF content]

=== INSTRUCTIONS ===

[... same instructions and response format as below ...]
```

**File-based variant** (artifacts too large for inline):

```
You are an adversarial reviewer. Your job is to find problems with the following [PHASE] output.

Play all three roles simultaneously, as relevant to what you find:
- DEVIL'S ADVOCATE: Challenge design decisions. What alternatives were dismissed or not considered?
  What assumptions are baked in that could be wrong?
- RED TEAM: Find failure modes, edge cases, and ways this could go wrong in practice.
  What could break? What has been overlooked?
- STEELMAN OPPONENT: Construct the strongest possible argument AGAINST this output.
  What would a skeptical domain expert object to most strongly?

PHASE: [PHASE]

=== ARTIFACTS ===

Read the following files in the working directory for the full artifacts to review:

[If PHASE == brainstorming:]
- Original request: .copowers-review-request.txt
- Spec document: .copowers-review-spec.md

[If PHASE == writing-plans:]
- Spec document: .copowers-review-spec.md
- Plan document: .copowers-review-plan.md

[If PHASE == executing-plans:]
- Spec document: .copowers-review-spec.md
- Plan document: .copowers-review-plan.md
- Git diff: .copowers-review-diff.txt

[If PHASE == review:]
- Code changes: .copowers-review-diff.txt

Read each file completely before beginning your review.

=== INSTRUCTIONS ===
```

**Both variants share these instructions and response format:**

```
=== INSTRUCTIONS ===

Classify each issue as exactly one of:
- critical: A fundamental flaw that invalidates the output or makes it dangerous to proceed
- major: A significant gap, risk, or error that should be addressed or explicitly accepted
- minor: An advisory observation that does not block approval

Be specific and actionable — vague concerns are not useful.

=== RESPONSE FORMAT (use exactly) ===

## Adversarial Review — Round 1

### Critical Issues
[numbered list, or "None"]

### Major Issues
[numbered list, or "None"]

### Minor Issues
[numbered list, or "None"]

### Verdict
[Exactly one of: NO_NEW_CRITICAL_MAJOR | ISSUES_FOUND]
```

**Round 2+ prompt** (delta only — Codex remembers prior rounds via thread continuity):

```
Round [ROUND] update:

The following critical/major issues from prior rounds have been addressed:
[For each resolved issue: "- [issue text] → RESOLVED: [what changed]"]
[For each accepted issue: "- [issue text] → ACCEPTED: [rationale]"]

The following minor issues from prior rounds have been adjudicated:
[For each resolved minor: "- Minor: [issue text] → RESOLVED: [what changed]"]
[For each accepted minor: "- Minor: [issue text] → ACCEPTED: [rationale]"]

[If any artifact was updated:]
Updated artifact sections:
[paste only the changed sections, not the full artifact]

Continue in your adversarial roles (devil's advocate, red team, steelman opponent).
Review the resolutions and provide any new issues you find.
Do NOT re-raise issues already marked as resolved or accepted above.

=== RESPONSE FORMAT (use exactly) ===

## Adversarial Review — Round [ROUND]

### Critical Issues
[numbered list of NEW issues only, or "None"]

### Major Issues
[numbered list of NEW issues only, or "None"]

### Minor Issues
[numbered list of NEW issues only, or "None"]

### Verdict
[Exactly one of: NO_NEW_CRITICAL_MAJOR | ISSUES_FOUND]
```

### Step C: Invoke Codex via MCP

**Round 1:** If using file-based context passing, first write the temp files (see Extended
Context Passing), then call the `codex` MCP tool with the prompt constructed in Step B.
Pass `cwd` pointing to the project root and `sandbox: "read-only"` so Codex can read the
artifact files.

```
Tool: mcp__codex__codex
Parameters: {
  "prompt": "<the round 1 prompt>",
  "cwd": "<project root>",
  "sandbox": "read-only"
}
```

Store `structuredContent.threadId` from the response as `THREAD_ID`.

If `THREAD_ID` is null after round 1 (threadId absent from a successful response), treat the same as a tool call failure — log a warning, note it in the summary, and terminate with whatever content Codex returned.

**Round 2+:** Call the `codex-reply` MCP tool with the delta prompt and stored thread ID.

```
Tool: mcp__codex__codex-reply
Parameters: {
  "prompt": "<the round N delta prompt>",
  "threadId": "<THREAD_ID>"
}
```

If the MCP tool call fails or returns no content (e.g. the host's MCP transport times out),
switch to the **CLI Fallback (Codex via WSL)** for this and all subsequent rounds. Only if the
CLI fallback is ALSO unavailable, log a warning and treat this round as `NO_NEW_CRITICAL_MAJOR`
to avoid trapping the user, and note the failure in the summary. (Do not treat a mere MCP
timeout as a clean round — that would silently no-op the review.)

### Step D: Parse response

Extract from the MCP tool response text:
- `new_critical`: all items under "### Critical Issues" (empty list if "None")
- `new_major`: all items under "### Major Issues" (empty list if "None")
- `new_minor`: all items under "### Minor Issues" (empty list if "None")
- `verdict`: the token after "### Verdict" — either `NO_NEW_CRITICAL_MAJOR` or `ISSUES_FOUND`

Append all new critical and major issues to `issues_log`:
- `round`, `issue`, `severity`: `critical`|`major`, `status`: `open`

Append minor issues to `minor_log`:
- `round`, `issue`, `status`: `open` (will be adjudicated in Step E)

### Step E: Respond to issues

For each critical or major issue in `new_critical` and `new_major`, decide:

- **Resolve**: Update the artifact file on disk. Set `status = resolved`, record resolution text.
- **Accept with rationale**: Leave artifact unchanged. Set `status = accepted`, record rationale.

For each minor issue in `new_minor`, decide:

- **Resolve**: Update the artifact. Set `status = resolved`, record resolution text.
- **Accept with rationale**: Leave unchanged. Set `status = accepted`, record rationale.

All issues — critical, major, and minor — must be adjudicated with an explicit resolution
or acceptance rationale. No issue should remain without a decision.

### Step F: Check termination

The termination condition is that **Codex returned a clean round** — no new critical or
major issues. Resolving or accepting issues locally does NOT satisfy termination; Codex
must see the resolutions and return clean. This ensures the adversarial reviewer has the
final word, not the author.

```
# Verdict/content disagreement handling:
# If verdict == ISSUES_FOUND but new_critical and new_major are both empty,
# treat as NO_NEW_CRITICAL_MAJOR and log:
#   "Warning: Codex returned ISSUES_FOUND but no critical/major items parsed.
#    Treating as NO_NEW_CRITICAL_MAJOR."

if ROUND >= MIN_ROUNDS
   AND (verdict == NO_NEW_CRITICAL_MAJOR
        OR (new_critical is empty AND new_major is empty)):
     → TERMINATE: go to Output
elif ROUND >= MAX_ROUNDS:
     → TERMINATE (max rounds reached): go to Output
else:
     → continue loop (go to Step A)
```

**IMPORTANT:** Even if all issues from this round are immediately resolved or accepted in
Step E, you MUST continue to Step A (next round) if this round had new critical or major
issues. The next round gives Codex the opportunity to verify resolutions and either raise
new concerns or return clean. Only a clean round from Codex terminates the loop.

## Output

### 1. Final Approved Artifact

Display the final content of the primary artifact:
- **brainstorming**: Read and display the current content of `SPEC_PATH`
- **writing-plans**: Read and display the current content of `PLAN_PATH`
- **executing-plans**: Display a prose summary of the changes implemented, derived from `PLAN_PATH` and the issues resolved during the loop. Do not display the raw git diff.

### 2. Adversarial Review Summary

```
## Adversarial Review Summary
```

| Round | Issue | Severity | Resolution |
|-------|-------|----------|------------|
| 1 | [issue text] | Critical | Fixed — [what changed] |
| 2 | [issue text] | Major | Accepted — [rationale] |

If `issues_log` is empty: "No critical or major issues were raised."

If MAX_ROUNDS was reached before termination, prepend:
> ⚠️ **Max rounds reached.** The following issues remain unresolved — review and decide how to proceed:
> [list unresolved issues]

### 3. Minor Issues — Adjudicated

```
<details>
<summary>Minor issues (N issues, all adjudicated)</summary>
```

| Round | Issue | Adjudication |
|-------|-------|--------------|
| 1 | [issue text] | Resolved — [what changed] |
| 2 | [issue text] | Accepted — [rationale] |

```
</details>
```

If `minor_log` is empty, omit this section entirely.

Every minor issue must show either "Resolved" or "Accepted" with a reason. No minor issue
should appear without adjudication.

### 4. Write Session State

After producing the review output, write/update the session state file:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$REPO_ROOT" ]; then
  REPO_HASH=$(echo -n "$REPO_ROOT" | sha256sum | cut -c1-12)
  STATE_FILE="${TMPDIR:-.}/.copowers-session-${REPO_HASH}.json"
fi
```

Read existing state file (or create new with `{"schema_version": 1, "reviews": [], "reviewed_files": []}`).

Append to `reviews`:
```json
{
  "phase": "<PHASE>",
  "timestamp": "<current ISO 8601>",
  "spec_path": "<SPEC_PATH or null>",
  "plan_path": "<PLAN_PATH or null>",
  "rounds": "<ROUND>",
  "unresolved_critical": "<count of critical issues with status != resolved>",
  "unresolved_major": "<count of major issues with status != resolved>",
  "minor_resolved": "<count of minor issues resolved>",
  "minor_accepted": "<count of minor issues accepted>",
  "verdict": "<approved if terminated normally, max_rounds_reached otherwise>",
  "reviewed_at_commit": "<current git HEAD SHA>"
}
```

If SPEC_PATH or PLAN_PATH were provided, append them to `reviewed_files`:
```json
{
  "path": "<relative path from repo root>",
  "reviewed_at_commit": "<current git HEAD SHA>",
  "timestamp": "<current ISO 8601>"
}
```

Write the updated state file atomically (write to temp file, then rename).

### 5. Cleanup Temp Files

If file-based context passing was used, delete the temp files:

```bash
rm -f .copowers-review-spec.md .copowers-review-plan.md .copowers-review-diff.txt .copowers-review-request.txt
```
