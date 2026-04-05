---
name: executing-plans
description: Use when executing an implementation plan — wraps superpowers:subagent-driven-development with adversarial Codex review after all tasks complete
---

# copowers: Executing Plans

Wraps `superpowers:subagent-driven-development` with an adversarial Codex red-team review
after all implementation tasks complete and pass their two-stage reviews.

## Announce

Say exactly:
> "I'm using copowers:executing-plans (wraps superpowers:subagent-driven-development with adversarial Codex review)"

## Step 1: Prerequisite check

```bash
command -v codex || echo "ERROR: Codex CLI not found. Install: npm install -g @openai/codex"
```

If Codex is not found, inform the user and stop.

## Step 2: Record baseline commit SHA

Before invoking the superpowers skill, capture the current HEAD:

```bash
git rev-parse HEAD
```

Store as `BASELINE_SHA`. This marks the boundary for the git diff that will be passed to
the adversarial critic after execution completes.

## Step 3: Identify plan and spec paths

Note:
- `PLAN_PATH`: full absolute path to the plan document being executed
- `SPEC_PATH`: full absolute path to the spec document the plan is based on

These are typically in `docs/superpowers/plans/` and `docs/superpowers/specs/`.

## Step 4: Invoke superpowers:subagent-driven-development

Use the Skill tool to invoke `superpowers:subagent-driven-development`.

Follow it completely through ALL tasks:
- Each task dispatched as a fresh implementer subagent
- Spec compliance review after each task
- Code quality review after each task
- All tasks marked complete in TodoWrite
- Final code reviewer subagent for the full implementation

Do NOT proceed until all tasks are complete and the final reviewer has approved the
implementation.

## Step 5: Invoke adversarial-critic

Use the Skill tool to invoke `copowers:adversarial-critic`.

Provide the following context explicitly:
- `PHASE`: `executing-plans`
- `SPEC_PATH`: [the path recorded in Step 3]
- `PLAN_PATH`: [the path recorded in Step 3]
- `BASELINE_SHA`: [the SHA recorded in Step 2]
