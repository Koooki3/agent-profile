---
name: team-mode
description: "Use when a task may benefit from a bounded subagent for implementation, large-codebase discovery at task start, independent review, requested or pre-commit code simplification, or expert work on complex decisions, modeling, automation, or repeated failures. The main agent chooses whether to delegate and accepts the result. Do not use for simple questions or short work with no meaningful review or delegation."
metadata:
  compatibility: "Codex with custom subagents; local model and usage diagnostics require Python 3.10+ and retained session logs."
---

# Team Mode

The main agent decomposes the user's task, decides what to delegate, and accepts the result. A task's size alone does not require subagents. On activation, send one brief commentary update in the user's language prefixed with `👾` (in Chinese: `👾 已开启小队模式。`).

## When to dispatch

Delegate a defined part of the task when a child can make useful progress through implementation, codebase discovery, review, or expert work. The main agent owns how the parts fit together, unresolved product decisions, and final acceptance. There is no target number of agents or required sequence.

Choose the smallest count that covers the independent work. One child is the default for one bounded question or review lens. Add children only when each can work and report independently, with a distinct question, scope, or lens. A large diff alone is not a reason to fan out.

Consider coordination and usage overhead. Respect the host's active-agent limit; if parallel dispatch is unavailable, continue sequentially or inline without silently dropping coverage.

- `Explorer` — use for substantial codebase discovery at the start of a task. Handle small lookups and general research directly. Read [Explore](references/explore.md) for this route.
- `Executor` — use when the intended result and file ownership are clear enough for independent implementation. Give each target one owner.
- `Reviewer` — use when the user asks for review or a completed result has a meaningful risk of unnoticed defects. Review the assigned result without steering toward a suspected answer; save a Markdown report when a lasting record helps.
- `ExpertAdvisor` — use for a complex architecture or high-impact decision, a problem unresolved after repeated attempts, or modeling or complex computer automation the main agent cannot handle well. Ask for an independent plan or assign the expert a concrete outcome to produce.

When the user asks to simplify code, or before committing a code change, follow [Simplify](references/simplify.md) for scoped cleanup and final review. The main agent decides which findings to apply and accepts the final result.

For each dispatch, name the intended `agent_type`, count, independent scope, expected return, and write ownership. Keep write scopes separate when agents share a workspace.

Other configured roles and models are allowed when appropriate. Model and effort defaults, plus the optional `default.toml` sentinel, are described in [profile setup](references/custom-agents.md); normal dispatch does not require reading it.

## Context and handoff

Start a new child with `fork_turns="none"` by default. Always use it for `Reviewer` and `ExpertAdvisor`, whose value depends on an independent view. Use it for `Explorer` too: a question and codebase path are usually enough.

For an `Executor`, prefer `fork_turns="none"` and put the relevant recent decisions in its brief. The current host accepts only `"none"` and `"all"`; do not pass a numeric value. Use `fork_turns="all"` only when the complete history is necessary. Use `fork_turns="none"` when explicitly choosing a model or reasoning effort. Check the current tool schema before relying on other inheritance modes. Reuse an existing child for a direct continuation of its own assignment.

Give the child its assigned question or deliverable, relevant context, and scope. Include the broader user goal when it helps explain the assignment. Pass files, symptoms, and prior attempts as leads, not a fixed diagnosis or checklist. The child chooses its method within the assigned part; the main agent handles changes to the task breakdown and checks the returned work.

## Expert help

By default, `ExpertAdvisor` inherits the parent model, reasoning effort, and tier. Do not select a different model merely because the role is an expert. If the user requests a model override for the task, check current availability and the host schema, use `fork_turns="none"`, and verify the effective configuration.

Give it the decision or outcome, relevant context, evidence, constraints, and scope without presenting a proposed cause as fact. Check its result before accepting it.

A model fixed in a custom profile takes precedence over a spawn-time choice. See [profile setup](references/custom-agents.md) for model changes; do not assume an explicit model overrides `Explorer`, `Executor`, or `Reviewer`.

## Diagnostics

For a requested usage report, run `python3 scripts/usage_by_model.py`; read [evaluation guidance](references/evaluation.md) when evaluating Team Mode itself. For an interactive-state task that code inspection cannot establish, read [interactive testing guidance](references/interactive-testing.md).
