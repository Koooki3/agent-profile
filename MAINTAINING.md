# 维护约定(agent 读这个)

仓库由 agent 依据本机运行记录维护(用户 2026-10-14 授权)。2026-10-14 用户进一步授权 agent 对
`Koooki3/agent-profile` 使用最大权限,包括 push。这是对根 `AGENTS.md` / 全局 `CLAUDE.md`
"只本地提交、不 push"的**仅限本仓库**的例外;其他仓库规则不变。

远端权限上限 = deploy key 在 GitHub 上的权限(读写该仓库)。改仓库设置、删仓库、开 PR 需要用户另行提供
`gh`/PAT,在此之前不可用。

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

## 提交与推送
- 用个人身份: `bash -c '. env/git-agent-env.sh; git commit ...'`(Bash 工具的 shell 是 zsh,不能直接 source)。
- 提交信息说明依据哪条运行记录(例如"doctor [3]: shuorenhua 在线修改回收")。
- 验证通过后可直接 `git push origin main`(密钥已由仓库的 `core.sshCommand` 绑定)。每次 push 后向用户汇报提交 hash 与内容。
- 破坏性操作的自我约束: force-push、改写已推送历史、删除分支/tag 之前,先打备份 tag(`backup/<日期>-<原因>`)并推送,
  并在回复里写明原因;不为了"整洁"改写历史。
- 验证顺序: `bash -n` → 临时 `PROFILE_HOME` 部署 → `doctor.sh`;改了 skills/配置渲染还要和 live 对比。
- 推送前确认 `doctor [6]` 通过(无凭据/密钥),仓库保持私有。
