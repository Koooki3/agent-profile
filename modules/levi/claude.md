
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
