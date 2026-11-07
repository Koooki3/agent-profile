# agent-profile — isolated Claude Code / Codex profiles for shared machines

[中文](README.md)

When several people share one machine (or even one OS account), give **your own** Claude Code / Codex
a separate config dir, credentials, sessions/memory, binary version and Git identity, without touching
the shared `claude` / `codex`.

Pick a name (`AGENT_NAME`, e.g. `alice`) and you get launchers `claude-alice` / `codex-alice` and a home at
`~/.agent-profiles/alice/`. Any number of profiles can coexist.

The repo holds only **declarations** (config, skills, launchers, version pins). Credentials, sessions,
binaries and caches stay in `PROFILE_HOME` and are never committed. Personal preferences go in `profile.env`
and in `modules.local/` (outside git).

## Quick start
```bash
# Fork first if you want to push your own changes back.
git clone https://github.com/<owner>/agent-profile ~/.agent-profiles/alice/repo
cd ~/.agent-profiles/alice/repo
cp profile.env.example profile.env   # set AGENT_NAME, AGENT_GIT_NAME/EMAIL, SKILLS, MODULES
./bootstrap.sh                       # render config, sync skills, install binaries, link launchers, run doctor
claude-alice                         # then /login
codex-alice login                    # add --device-auth on headless machines
```
The repo can live elsewhere if `profile.env` sets `AGENT_NAME` (default home `~/.agent-profiles/<AGENT_NAME>`)
or `PROFILE_HOME`. `PROFILE_HOME` may not be `$HOME`.

## Settings (`profile.env` or env vars of the same name; env wins)
`AGENT_NAME`, `PROFILE_HOME`, `AGENT_GIT_NAME`, `AGENT_GIT_EMAIL`, `KEEP_ENV` (credential env vars the launchers
should keep instead of unsetting), `MODULES`, `WORKSPACE_ROOT`, `SKILLS` (names / `all` / empty = none; unset = everything
in `skills.conf`), `CODEX_BIN`, `BIN_DIR`. See `profile.env.example`.

## Everyday commands
`./bootstrap.sh --sync` (pull + apply) · `./doctor.sh` (isolation, drift, versions, login, secret/path scan) ·
`./import-live.sh` (pull live skill edits back into the repo) · `tests/smoke.sh` (offline smoke test).
`bootstrap.sh` backs up any live file it overwrites to `PROFILE_HOME/.profile-state/backups/<timestamp>/`.

## Codex feels too restricted?
A fresh `CODEX_HOME` has none of your shared codex config, trusted projects or approved-command rules, so it is more
conservative. Switches, in order: (1) `CODEX_TRUSTED_DIRS="$HOME/work ..."` writes `[projects."…"] trust_level` entries;
(2) `CODEX_ACCESS` = `safe` (workspace write, no network) / `dev` (default: workspace + `~/.cache ~/.npm ~/.cargo` + network) /
`full` (no sandbox; only with external isolation) / `none` (define everything yourself in a module or `config.local.toml`;
redefining a preset's table otherwise fails validation); (3) per-run flags `--add-dir`, `-s`, `-a never`;
(4) approved command prefixes accumulate in `PROFILE_HOME/codex/rules/default.rules`; (5) `./doctor.sh --deep` runs
`codex doctor --strict-config` to check unknown config keys and sandbox helpers (needs network).

## What is and is not isolated
Launchers set `CLAUDE_CONFIG_DIR` / `CODEX_HOME` to your own dirs, unset credential-bearing env vars
(`ANTHROPIC_*` keys/tokens/base URL, `CLAUDE_CODE_OAUTH_TOKEN`, Bedrock/Vertex switches, `OPENAI_API_KEY`,
`CODEX_API_KEY`, `OPENAI_BASE_URL`) unless listed in `KEEP_ENV`, disable Claude auto-update, install binaries under
`PROFILE_HOME` with `HOME` redirected, and inject your Git identity with askpass/credential helpers cleared.

**This is not a security sandbox.** If people share the *same OS account* they have identical filesystem access;
`chmod 700` only keeps out other OS users. Use separate OS accounts or containers for hard isolation.

## Notes
- Binaries are installed with the official `install.sh` scripts (downloaded and executed, not checksum-verified); versions come from `pins.env`.
  To avoid that, install them yourself and set `CODEX_BIN` / place claude at `PROFILE_HOME/claude-home/.local/bin/claude`.
- Bundled `skills/` are examples (some from upstream, with their own LICENSE files); enable via `SKILLS`, replace freely.
- Verified on Linux/WSL only. No top-level LICENSE is included; add one to your fork.
- Maintenance rules for agents editing this repo: `MAINTAINING.md`.
