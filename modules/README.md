# modules — 按项目/机器启用的配置片段

核心配置(`claude/CLAUDE.base.md`、`codex/AGENTS.base.md`、`codex/config.base.toml`)与具体项目无关。
只在某个项目或某台机器上才需要的内容,做成一个 module,在 `profile.env` 的 `MODULES` 里按名字启用。

一个 module 是一个目录,里面的文件都可选:

| 文件 | 拼接到 |
|---|---|
| `claude.md` | `PROFILE_HOME/claude/CLAUDE.md`(在 base 之后) |
| `codex.md` | `PROFILE_HOME/codex/AGENTS.md`(在 base 之后) |
| `codex-config.toml` | `PROFILE_HOME/codex/config.toml`(在 base 之后) |

文本里的 `@WORKSPACE_ROOT@` 会替换为 `profile.env` 的 `WORKSPACE_ROOT`。

## 放在哪里
- `modules/<name>/`(本仓库): 通用、可公开给所有机器的片段。
- `$PROFILE_HOME/modules.local/<name>/`(仓库之外): 项目专属或机器专属的片段。**同名时优先于仓库里的**,
  不进 git,不会出现在 GitHub 上。具体项目的说明请放这里。

从 `_template/` 复制一份开始(例如 `cp -r modules/_template "$PROFILE_HOME/modules.local/<name>"`),改名后再填内容。
以 `_` 开头的目录是模板,不能直接写进 `MODULES`(会被拒绝)。
