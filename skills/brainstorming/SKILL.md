---
name: brainstorming
description: Use when starting any creative work, designing features, or building new functionality — wraps superpowers:brainstorming with adversarial Codex review after the spec is written
---

# copowers: Brainstorming

Wraps `superpowers:brainstorming` with an adversarial Codex red-team review after the spec
document is written and internally approved.

## Announce

Say exactly:
> "I'm using copowers:brainstorming (wraps superpowers:brainstorming with adversarial Codex review)"

## Step 1: Prerequisite check

```bash
command -v codex || echo "ERROR: Codex CLI not found. Install: npm install -g @openai/codex"
```

If Codex is not found, inform the user and stop.

## Step 2: Capture original request

Note the user's request verbatim as `ORIGINAL_REQUEST` before invoking superpowers.
This will be passed to the adversarial critic to verify the spec addresses what was actually asked.

## Step 3: Invoke superpowers:brainstorming

Use the Skill tool to invoke `superpowers:brainstorming`.

Follow it completely through ALL steps:
- Clarifying questions
- Approach proposals
- Design sections and user approval
- Spec document written to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- Spec-document-reviewer loop (internal completeness check)
- User review gate

Do NOT proceed until superpowers:brainstorming has fully completed and the spec is written,
reviewed, and user-approved.

## Step 4: Note spec path

Record as `SPEC_PATH` the full absolute path to the spec document written in Step 3.

## Step 5: Invoke adversarial-critic

Use the Skill tool to invoke `copowers:adversarial-critic`.

Provide the following context explicitly:
- `PHASE`: `brainstorming`
- `SPEC_PATH`: [the path recorded in Step 4]
- `ORIGINAL_REQUEST`: [the verbatim request captured in Step 2]
