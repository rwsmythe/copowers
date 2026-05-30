---
name: writing-plans
description: Use when you have a spec and need an implementation plan — wraps superpowers:writing-plans with adversarial Codex review after the plan is written
---

# copowers: Writing Plans

Wraps `superpowers:writing-plans` with an adversarial Codex red-team review after the plan
document is written and internally chunk-reviewed.

## Announce

Say exactly:
> "I'm using copowers:writing-plans (wraps superpowers:writing-plans with adversarial Codex review)"

## Step 1: Prerequisite check

```bash
command -v codex || echo "ERROR: Codex CLI not found. Install: npm install -g @openai/codex"
```

If Codex is not found, inform the user and stop.

## Step 2: Identify spec path

Note the full absolute path of the existing spec document as `SPEC_PATH`.
This is typically `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` in the current project.

## Step 3: Invoke superpowers:writing-plans

Use the Skill tool to invoke `superpowers:writing-plans`.

Follow it completely through ALL steps:
- File map definition
- Task decomposition with bite-sized steps
- Plan document written to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`
- Plan-document-reviewer loop (chunk-by-chunk review)

Do NOT proceed until superpowers:writing-plans has fully completed and the plan is written
and all chunks are approved.

## Step 4: Note plan path

Record as `PLAN_PATH` the full absolute path to the plan document written in Step 3.

## Step 5: Invoke adversarial-critic

Use the Skill tool to invoke `copowers:adversarial-critic`.

Provide the following context explicitly:
- `PHASE`: `writing-plans`
- `SPEC_PATH`: [the path recorded in Step 2]
- `PLAN_PATH`: [the path recorded in Step 4]
