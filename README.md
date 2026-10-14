# agent-profile — 个人 agent(claude-kooki3 / codex-kooki3)可移植部署

仓库只存**声明**(配置、skills、启动器、版本 pin);凭据、会话、二进制、缓存留在各机器的
`PROFILE_HOME`,永不入库。个人 agent 与机器上的共享 `claude` / `codex` 互不影响。

## 新机器部署
```bash
# 先让 git 能访问私有仓库: 每台机器各生成一把专用密钥,不要用共享账号的 ~/.ssh 默认密钥
mkdir -p ~/.agent-profiles/kooki3/ssh && chmod 700 ~/.agent-profiles/kooki3/ssh
ssh-keygen -t ed25519 -N "" -C "koooki3-agent-profile@$(hostname)" -f ~/.agent-profiles/kooki3/ssh/id_ed25519_koooki3
cat ~/.agent-profiles/kooki3/ssh/id_ed25519_koooki3.pub   # 加到 GitHub: 仓库 Settings → Deploy keys(只读;需要在该机器 push 时勾 write)
export GIT_SSH_COMMAND="ssh -i ~/.agent-profiles/kooki3/ssh/id_ed25519_koooki3 -o IdentitiesOnly=yes"
git clone git@github.com:Koooki3/agent-profile.git ~/.agent-profiles/kooki3/repo
cd ~/.agent-profiles/kooki3/repo
git config core.sshCommand "$GIT_SSH_COMMAND"   # 之后 pull/push 自动使用该密钥
cp profile.env.example profile.env   # 按需改 WORKSPACE_ROOT / MODULES(LEVI 机器: MODULES="levi")
./bootstrap.sh                       # 渲染配置 + 同步 skills + 装二进制 + 链接启动器 + doctor
claude-kooki3                        # 进入后 /login
codex-kooki3 login                   # 无头机器加 --device-auth
```
目录约定: `PROFILE_HOME` 默认是本仓库的上一级目录(上例为 `~/.agent-profiles/kooki3`),
里面有 `claude/ codex/ claude-home/ tools/` 等运行时状态。可在 `profile.env` 里改。

## 日常
| 想做的事 | 命令 |
|---|---|
| 在另一台机器同步最新配置 | `./bootstrap.sh --sync` |
| 自检(隔离性/漂移/版本/登录/密钥扫描) | `./doctor.sh` |
| 把在线改动(如 skill-lifecycle 改了 skill)收回仓库 | `./import-live.sh`,然后 `git diff` → 提交 |
| 启用/停用某个 skill 的某个 host | 改 `skills/skills.conf` → `./bootstrap.sh` |
| 升级 claude/codex | 改 `pins.env` → `./bootstrap.sh` |
| 只刷新配置、不联网 | `./bootstrap.sh --skip-install --no-link` |
| 让个人 SSH 会话里的 `claude`/`codex` 命令仍走共享版本 | `./bootstrap.sh --zsh`,并在该会话 `export ZDOTDIR=$PROFILE_HOME/zsh` |

`bootstrap.sh` 覆盖任何与仓库不一致的 live 文件之前,先把旧版本备份到
`PROFILE_HOME/.profile-state/backups/<时间戳>/`。

## 目录
```
bin/        claude-kooki3, codex-kooki3(路径由自身位置推导;隔离项: CLAUDE_CONFIG_DIR/CODEX_HOME、
            unset ANTHROPIC_*、DISABLE_AUTOUPDATER、个人 Git 身份、清空 credential.helper)
env/        git-agent-env.sh, git-identity.gitconfig, shared-cli-shell.zsh(共享 claude/codex 的 shell 函数,按需 source)
skills/     <name>/ 公共实体;<name>@codex/ 仅 codex 有差异时的变体;skills.conf 记录各 skill 启用的 host
claude/     settings.json, CLAUDE.base.md        codex/  config.base.toml, AGENTS.base.md, agents/*.toml
modules/    按机器启用的片段(levi: LEVI 入口说明 + codex trusted 项目);模板变量 @WORKSPACE_ROOT@
pins.env    claude / codex / skill-loom 版本
```

## 刻意不同步的内容
- 登录凭据与账号状态: `.credentials.json`、`auth.json`、`.claude.json`、`claude/skills/synced`(claude.ai 账号同步桶)
- `codex/rules/default.rules`(逐次审批累积,与本机路径绑定)、`codex/skills/.system`(Codex 自带,自动重建)
- 会话、历史、memory(`claude/projects/*/memory` 目录名由路径决定,换机器对不上;需要时另做模块)
- `config.local.toml`(放在 PROFILE_HOME 下,本机专用的 codex 配置片段,会被拼到 config.toml 末尾)

## 已知限制
- 二进制安装已在全新临时目录实测(2026-10-14): claude 用官方 `install.sh` 加版本参数,codex 用官方
  `chatgpt.com/codex/install.sh --release`;两者都把 `HOME` 重定向到 PROFILE_HOME 内(`claude-home/`、
  `codex-home/`),不写共享安装与真实 shell rc。codex 不需要 node/npm。
- 在 `profile.env` 设置 `CODEX_BIN` 会跳过 codex 私有安装并改用该二进制(doctor 会提示它来自共享安装)。
- skills 采用复制而非软链;未验证 Claude Code / Codex 是否都识别目录软链(需要登录态才能测)。
- 仍未覆盖: 无网络机器的离线安装、macOS/Windows。
