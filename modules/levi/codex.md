# Koooki3 Personal Agent

When working on LEVI:

- Participate in the existing LEVI agent development workflow as a normal collaborator.
- Read @WORKSPACE_ROOT@/AGENTS.md and LEVI/lab/AGENTS.md first.
- Run LEVI/lab/levi-hub/agent_start.sh at session start.
- Read relevant project memory, current plans, and the latest handoff.
- Accept development plans and requirements in natural language, as the shared agents do.
- Use the existing LEVI/lab/worktrees system and driver.py resource leases.
- Work in a task-specific worktree, independently of other active agents.
- Coordinate shared resources. Never take over another agent's active task.
- Use the personal Git identity supplied by this agent's launcher.
- Do not change shared Git identity, authentication, or user configuration.
- Commit locally following LEVI conventions; never push automatically.
- Respect paused workflows, real-robot safety rules, and approval boundaries.
- Run agent_finish.sh at task completion.

# kooki3 LEVI personal entry

When the user asks for LEVI development, planning, optimization,
experiments, testing, review, or progress updates:

- Treat @WORKSPACE_ROOT@ as the workspace root.
- Read the root AGENTS.md, LEVI/lab/AGENTS.md,
  LEVI/AGENTS.md and relevant nested instructions.
- Follow the existing LEVI session start protocol, project
  memory, current plans, latest handoff, and finish protocol.
- Accept natural-language tasks just like the shared agents.
  Handle investigation, planning, implementation, testing,
  review, backlog, progress, and handoff as appropriate.
- Use LEVI's existing worktrees and driver.py resource leases.
  Coordinate shared writes, GPU, tests, deployment and ledger.
- Work in a task-specific worktree, not another agent's tree.
- Respect paused workflows, robot safety and approval boundaries.
  A new authorized task does not resume paused automation.
- Use the personal Git Author/Committer environment without
  modifying shared Git configuration. Follow commit conventions.
- Commit locally; never push automatically.
- Do not access other users' files, processes or credentials.
- If a required capability is unavailable, report it rather
  than assuming shared tools are available.

# Personal subagent defaults

- Subagents inherit the parent model, reasoning effort, and service tier by default. Use explicit overrides only when the user requests them for the task. Keep shared-account settings unchanged.
