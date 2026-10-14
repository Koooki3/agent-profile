# 维护约定(agent 读这个)

仓库由 agent 依据本机运行记录维护(用户 2026-10-14 授权);用户负责 `git push` 和在新机器上部署。

## 例行检查(会话开始处理本仓库,或用户问配置/skills 状态时)
1. `./doctor.sh`。FAIL 必须处理;WARN 逐条判断。
2. 对照 live 目录的运行记录判断要不要更新仓库:

| 信号 | 含义 | 处理 |
|---|---|---|
| doctor `[3]` skill 与仓库不同 | skill-lifecycle / skill-loom / 手改了 live skill | `./import-live.sh` → `git diff --stat` 审阅(无密钥、无机器路径)→ 提交 |
| doctor `[2]` 配置不一致 | 工具自己改了 live 文件(如 codex `/model`、claude 设置) | `diff` 判断是有意修改还是工具噪声;有意的移植进 `claude/settings.json`、`codex/config.base.toml` 或 `modules/*`(机器相关的路径用 `@WORKSPACE_ROOT@`),噪声忽略 |
| doctor `[4]` 版本与 pin 不符 | 用户手动升级了二进制 | 确认升级是有意的,再改 `pins.env`;不替用户升级 |
| 新增/删除了 skill | `skills.conf` 需要同步 | `import-live.sh` 只新增条目,删除要手动改 `skills.conf` 并删对应目录 |
| 重复出现的手工步骤 | 该进脚本 | 改 `bootstrap.sh` / `doctor.sh`,并加一条 doctor 检查 |

## 不变量(改动不得破坏)
- 启动器隔离项: `CLAUDE_CONFIG_DIR`/`CODEX_HOME`、`unset ANTHROPIC_*`、`DISABLE_AUTOUPDATER=1`、个人 Git 身份、空 `credential.helper`。`doctor [1]` 行为级断言它们。
- 凭据与账号状态永不入库(`.credentials.json`、`auth.json`、`.claude.json`、`skills/synced`);`doctor [6]` 扫描。
- 不改 `~/.claude`、`~/.codex`;不用 `~/.ssh` 里除 `.agent-profiles-zihao/ssh/id_ed25519_koooki3` 以外的密钥。
- `bootstrap.sh` 覆盖 live 前必须先备份到 `.profile-state/backups/`。
- 本机现有 `~/.local/bin/{claude,codex}-kooki3` 是旧启动器,未经用户同意不替换。

## 提交
- 用个人身份: `bash -c '. env/git-agent-env.sh; git commit ...'`(Bash 工具的 shell 是 zsh,不能直接 source)。
- 提交信息说明依据哪条运行记录(例如"doctor [3]: shuorenhua 在线修改回收")。
- 只本地提交,不 push;完成后告诉用户有几个待推送提交。
- 验证顺序: `bash -n` → 临时 `PROFILE_HOME` 部署 → `doctor.sh`;改了 skills/配置渲染还要和 live 对比。
