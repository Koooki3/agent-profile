# agent-profile — 多人共用机器上的独立 agent 配置(Claude Code / Codex)

[English](README.en.md)

多人共用同一台机器(甚至同一个系统账号)时,让**你自己的** Claude Code / Codex 拥有独立的:
配置目录、登录凭据、会话与记忆、二进制版本、Git 身份,并且不影响机器上共享的 `claude` / `codex`。

每个使用者选一个名字(`AGENT_NAME`,如 `alice`),得到自己的启动器 `claude-alice` / `codex-alice`
和自己的目录 `~/.agent-profiles/alice/`。同一台机器上可以有任意多个 profile 并存。

仓库只存**声明**(配置、skills、启动器、版本 pin);凭据、会话、二进制、缓存留在各机器的
`PROFILE_HOME`,永不入库。个人偏好放 `profile.env` 和仓库之外的 `modules.local/`,不进 git。

## 快速开始
```bash
# 建议先 fork 本仓库,克隆你自己的 fork,这样你的改动可以推回自己的仓库
git clone https://github.com/<owner>/agent-profile ~/.agent-profiles/alice/repo
cd ~/.agent-profiles/alice/repo
cp profile.env.example profile.env   # 改 AGENT_NAME、AGENT_GIT_NAME/EMAIL、SKILLS、MODULES
./bootstrap.sh                       # 渲染配置 + 同步 skills + 装二进制 + 链接启动器 + doctor
claude-alice                         # 进入后 /login
codex-alice login                    # 无头机器加 --device-auth
```
仓库放在别处也行,只要在 `profile.env` 里设 `AGENT_NAME`(默认目录 `~/.agent-profiles/<AGENT_NAME>`)
或显式设 `PROFILE_HOME`。仓库位于 `~/.agent-profiles/<名称>/repo` 时,名称与目录可自动推导。
`PROFILE_HOME` 不能是 `$HOME`。

## 配置项(`profile.env` 或同名环境变量,环境变量优先)
| 变量 | 含义 |
|---|---|
| `AGENT_NAME` | profile 名称;决定默认目录与启动器名 `claude-<名>` / `codex-<名>`。小写字母/数字/`_`/`-` |
| `PROFILE_HOME` | 活动目录(凭据/会话/二进制),默认 `~/.agent-profiles/$AGENT_NAME` |
| `AGENT_GIT_NAME` / `AGENT_GIT_EMAIL` | agent 提交使用的 Git 身份。未设置时用占位身份,doctor 警告 |
| `KEEP_ENV` | 启动器默认清除的凭据类环境变量中,需要保留的(空格分隔) |
| `MODULES` / `WORKSPACE_ROOT` | 启用的配置片段与 `@WORKSPACE_ROOT@` 的值,见 `modules/README.md` |
| `SKILLS` | 启用哪些 skills(空格分隔 / `all` / 留空=不装);不设 = `skills.conf` 全部 |
| `CODEX_ACCESS` | codex 沙盒预设 `safe` / `dev`(默认) / `full` / `none`,见下文「codex 功能受限怎么办」 |
| `CODEX_TRUSTED_DIRS` | 标记为信任的目录(空格分隔) |
| `CODEX_BIN` | 指向已有 codex 二进制,跳过私有安装 |
| `BIN_DIR` | 启动器软链目录,默认 `~/.local/bin` |

## 日常
| 想做的事 | 命令 |
|---|---|
| 同步最新仓库配置 | `./bootstrap.sh --sync` |
| 自检(隔离性/漂移/版本/登录/密钥与路径扫描) | `./doctor.sh`(加 `--deep` 额外检查 codex 沙盒与配置键) |
| 把在线改动(如 skill 被修改)收回仓库 | `./import-live.sh`,然后 `git diff` → 提交 |
| 启用/停用 skill | 改 `profile.env` 的 `SKILLS` → `./bootstrap.sh`(停用的移到 `skills-disabled/`,不删除) |
| 升级 claude/codex | 改 `pins.env`(或在 `profile.env` 覆盖 `CLAUDE_VERSION`/`CODEX_VERSION`)→ `./bootstrap.sh` |
| 只刷新配置、不联网 | `./bootstrap.sh --skip-install --no-link` |
| 让该 SSH 会话里的 `claude`/`codex` 命令仍走共享版本 | `./bootstrap.sh --zsh`,并在该会话 `export ZDOTDIR=$PROFILE_HOME/zsh` |
| 跑仓库自带的冒烟测试 | `tests/smoke.sh`(临时 HOME + 桩二进制,不联网) |

`bootstrap.sh` 覆盖任何与仓库不一致的 live 文件之前,先把旧版本备份到
`PROFILE_HOME/.profile-state/backups/<时间戳>/`。

## 隔离了什么、没隔离什么
启动器做的事(`doctor [1]` 行为级验证):
- `CLAUDE_CONFIG_DIR` / `CODEX_HOME` 指向你自己的目录,凭据、会话、设置互不可见;
- 清除可能属于共享账号的凭据环境变量(`ANTHROPIC_API_KEY` `ANTHROPIC_AUTH_TOKEN` `ANTHROPIC_BASE_URL`
  `CLAUDE_CODE_OAUTH_TOKEN` `CLAUDE_CODE_USE_BEDROCK/VERTEX`、`OPENAI_API_KEY` `CODEX_API_KEY` `OPENAI_BASE_URL`),
  是你自己的凭据就用 `KEEP_ENV` 保留;
- 关闭 claude 自动更新,二进制装在你的 `PROFILE_HOME` 内(安装时 `HOME` 重定向,不写共享安装与 shell rc);
- 注入你的 Git 身份,移除共享终端的 askpass,清空 `credential.helper`。

**这不是安全沙箱。** 如果多人共用的是**同一个系统账号**,所有人对文件系统的权限相同;
`chmod 700` 只能挡住其他系统用户,挡不住同账号的其他人。需要强隔离请用各自独立的系统账号或容器。

## codex 功能受限怎么办
独立 profile 用的是全新的 `CODEX_HOME`,不继承共享 codex 的 `config.toml`、信任目录和已批准的命令规则,
所以比你平时用的更保守。按下面顺序排查,每一步都是独立的开关:

1. **信任目录**: 独立 `CODEX_HOME` 里没有任何 `[projects."…"] trust_level`,每个新目录都按"未信任"处理。
   在 `profile.env` 设 `CODEX_TRUSTED_DIRS="$HOME/work ..."`,`bootstrap.sh` 会写进 `config.toml`。
2. **沙盒预设** `CODEX_ACCESS`: 默认 `dev` = 写工作目录 + `~/.cache ~/.npm ~/.cargo` + 联网。
   不够就加可写目录/改预设:在 module 的 `codex-config.toml` 或 `config.local.toml` 里写
   `[sandbox_workspace_write]` 会与预设重复(bootstrap 会报错),这时用 `CODEX_ACCESS=none` 自己完整定义,例如
   ```toml
   sandbox_mode = "workspace-write"
   [sandbox_workspace_write]
   network_access = true
   writable_roots = ["@HOME@/.cache", "@HOME@/data"]
   ```
   `full` 完全不沙盒,仅限容器/独立账号等外部隔离环境。
3. **只在这一次放开**: 不改配置,启动时加参数 `codex-<名> --add-dir <目录>`(额外可写)、
   `-s danger-full-access`、`-a never`(不再询问,命令失败直接返回给模型)。
4. **审批提示太多**: 已批准的命令前缀存在 `PROFILE_HOME/codex/rules/default.rules`,随使用累积、不入库、也不随机器同步;
   新机器/新 profile 从零开始。
5. **沙盒本身起不来**(Linux/WSL 缺 `bwrap` 或禁了 user namespace): `./doctor.sh --deep` 会调用
   `codex doctor --strict-config`,报告配置键是否被识别、沙盒组件是否可用。
6. 模型、推理强度、网络搜索等偏好不在基线里,放进 module 的 `codex-config.toml` 或 `config.local.toml`
   (顶层键与表可混写,拼接时顶层键会被提到所有表之前)。

## 目录
```
bin/        agent-claude, agent-codex(启动器源;bootstrap 链接成 claude-<名>/codex-<名>)
lib/        common.sh(解析配置、渲染、备份)
env/        git-agent-env.sh, shared-cli-shell.zsh(共享 claude/codex 的 shell 函数,按需 source), zshrc.tmpl
skills/     <name>/ 公共实体;<name>@codex/ 仅 codex 有差异的变体;skills.conf 是目录(各 skill 适用的 host)
claude/     settings.json(通用基线), CLAUDE.base.md(空,放通用指令)
codex/      config.base.toml(通用基线), presets/*.toml(沙盒访问预设), AGENTS.base.md(空), agents/*.toml
modules/    可选配置片段机制与 _template(见 modules/README.md);个人/项目内容放 PROFILE_HOME/modules.local/
tests/      smoke.sh
pins.env    claude / codex / skill-loom 版本(只提供默认值)
```
`skills/` 里随仓库带的是一组示例 skills(有些来自上游,保留各自 LICENSE),默认只在 `SKILLS` 列出时才安装。
你可以随意增删,换成自己的。

## 刻意不同步的内容
- 登录凭据与账号状态: `.credentials.json`、`auth.json`、`.claude.json`、`claude/skills/synced`
- `codex/rules/default.rules`(逐次审批累积)、`codex/skills/.system`(Codex 自带)
- 会话、历史、memory
- `PROFILE_HOME/config.local.toml`(本机/本人专用 codex 配置,拼到 config.toml 末尾)与
  `PROFILE_HOME/claude-settings.local.json`(最后合并进 claude 设置)

## 已知限制
- 二进制安装通过官方 `claude.ai/install.sh` 与 `chatgpt.com/codex/install.sh` 下载并执行;脚本本身未做校验和核对,
  版本由 `pins.env` 指定。要避免联网执行,请自行安装后设 `CODEX_BIN` / 把 claude 放到 `PROFILE_HOME/claude-home/.local/bin/`。
- skills 采用复制而非软链;未验证 Claude Code / Codex 是否都识别目录软链。
- codex 的 `config.toml` 由 bootstrap 整体重写(旧版本先备份);codex 自己写入的 `[tui]` 状态会在下次 bootstrap 时被覆盖(doctor 比较时已忽略)。
- 仅在 Linux(含 WSL)上验证。未覆盖: 无网络机器的离线安装、macOS/Windows。
- 许可证: 仓库自有部分为 MIT(见 `LICENSE`);`skills/` 内各 skill 保留自己的 LICENSE,以其为准。
