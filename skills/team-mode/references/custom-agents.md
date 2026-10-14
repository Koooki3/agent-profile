# Custom Agent Profiles

Read this reference when installing, changing, or diagnosing Team Mode profiles. Normal dispatch does not need profile inspection.

## Profiles

For this personal profile, use the launcher-provided `CODEX_HOME`. Check that it is set before modifying profiles; do not substitute the shared home.

Copy the templates from the repository's `agents/` directory into `$CODEX_HOME/agents/` for personal use or `<project>/.codex/agents/` for one project. Keep unrelated local profiles and compare same-named files before replacing them.

| Role | Model | Effort | Tier | Purpose |
| --- | --- | --- | --- | --- |
| `Explorer` | inherited | inherited | inherited | Locate primary files in a large codebase when the parent requests it. |
| `Executor` | inherited | inherited | inherited | Complete a bounded implementation. |
| `Reviewer` | inherited | inherited | inherited | Review a stable result and save a Markdown report when useful. |
| `ExpertAdvisor` | inherited | inherited | inherited | Investigate a complex decision or carry out assigned modeling or automation. |

All installed roles omit `model`, `model_reasoning_effort`, and `service_tier`, and the personal `[agents]` block omits model/effort defaults. They inherit the parent settings. Use explicit spawn overrides only when the user requests them for the task. Current Codex applies a custom profile's fixed model and effort *after* resolving explicit spawn values, so a fixed profile wins over a conflicting spawn request. Other models and roles may be configured; Team Mode does not impose a global model allowlist. See the [Codex subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents).

## Optional Default Sentinel

Codex includes a built-in general-purpose `default` agent. The repository also provides an optional `default.toml` sentinel, using `gpt-6-luna` at `low` effort. Installing it under `$CODEX_HOME/agents/` overrides the built-in default for **all** local tasks and makes an omitted or `default` dispatch return `DISPATCH BLOCKED`. This catches routing mistakes but still creates a child and consumes usage; it is not a security boundary. Team Mode works without it and still asks the parent to name the intended role explicitly.

To disable an installed personal sentinel without deleting it:

```bash
mkdir -p $CODEX_HOME/agents-disabled
mv $CODEX_HOME/agents/default.toml $CODEX_HOME/agents-disabled/default.toml
```

Move it back to `$CODEX_HOME/agents/default.toml` to restore it. Open a new task or restart Codex after either change. A project-scoped sentinel can be moved into a corresponding project `agents-disabled/` directory.

## Load And Verify

1. Parse the installed TOML files and check `name`, `description`, `developer_instructions`, model, and effort where configured.
2. Open a new Codex task or restart if role changes do not appear in the current task. The current task's role schema may have been loaded before the edit.
3. Check that `spawn_agent` exposes the intended `agent_type` and, for `ExpertAdvisor`, explicit `model` and `reasoning_effort`. Do not route to a generic child when the intended custom role is absent.
4. For a real delegated task, compare the child trace's role, model, and effort with the request. A file's existence and the child self-report are not runtime proof.

## Service Tier Inheritance

All installed roles omit `service_tier`, so they do not force Fast mode. Inherit the parent tier by default. Change the tier only for an explicitly requested task override, after checking host support.
