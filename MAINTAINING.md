# 维护约定(agent 读这个)

本文件写给在某个 profile 的仓库副本里工作的 agent(Claude / Codex)。

## 权限边界
- **默认只做本地修改与本地提交。** 没有用户在当次会话(或该仓库的 CLAUDE.md/AGENTS.md)里明确授权,不要 push、
  不要开 PR、不要改远端仓库设置。授权只对被授权的仓库有效,不外推到其他仓库。
- 不改 `~/.claude`、`~/.codex`(那是共享安装);只改本 profile 的 `PROFILE_HOME` 与本仓库。
- 在用户已有的工作环境里首次运行 `bootstrap.sh` 前先征得同意: 同名启动器(不是指向本仓库的软链)会被备份后替换,
  `claude/settings.json` 与 `codex/config.toml` 会被重写(旧版先备份)。

## 例行检查(会话开始处理本仓库,或用户问配置/skills 状态时)
1. `./doctor.sh`。FAIL 必须处理;WARN 逐条判断。
2. 对照 live 目录的运行记录判断要不要更新仓库:

| 信号 | 含义 | 处理 |
|---|---|---|
| doctor `[3]` skill 与仓库不同 | skill 被在线修改 | `./import-live.sh` → `git diff --stat` 审阅(无密钥、无机器路径)→ 提交 |
| doctor `[2]` 配置不一致 | 工具自己改了 live 文件(如 codex `/model`、claude 设置) | `diff` 判断是有意修改还是工具噪声;有意的移植进 module 或 `*.local.*`(不要写进 base),噪声忽略 |
| doctor `[4]` 版本与 pin 不符 | 用户手动升级了二进制 | 确认是有意的,再改 `pins.env`;不替用户升级 |
| 新增/删除了 skill | `skills.conf` 需要同步 | `import-live.sh` 只新增条目,删除要手动改 `skills.conf` 并删对应目录 |
| 重复出现的手工步骤 | 该进脚本 | 改 `bootstrap.sh` / `doctor.sh`,并加一条 doctor 或 `tests/smoke.sh` 检查 |

## 不变量(改动不得破坏)
- 启动器隔离项: `CLAUDE_CONFIG_DIR`/`CODEX_HOME`、凭据类环境变量清除(`KEEP_ENV` 例外)、`DISABLE_AUTOUPDATER=1`、
  独立 Git 身份、空 `credential.helper`。`doctor [1]` 做行为级断言。
- 凭据与账号状态永不入库(`.credentials.json`、`auth.json`、`.claude.json`、`skills/synced`、`profile.env`);`doctor [6]` 扫描。
- `bootstrap.sh` 覆盖 live 前必须先备份到 `.profile-state/backups/`;同一 profile 持锁串行;末尾 doctor 失败必须使 bootstrap 非零退出(`tests/smoke.sh` 有负向测试)。
- 外部输入(`AGENT_NAME`、`MODULES`、`SKILLS`、`PROFILE_HOME`、skills.conf 名字)一律校验为单段名称/受限路径,不得拼接后直接用于文件操作。
- `import-live.sh` 只导入普通文件构成的 skill;软链/特殊文件拒绝。导入后必须 `git diff` 审阅再提交。
- **仓库保持项目无关、人无关**: 具体项目/机器/个人的指令、路径、身份、偏好放 `profile.env`、
  `$PROFILE_HOME/modules.local/<name>/` 或 `*.local.*`(都在仓库之外),不要写进 `modules/`、base 文件或脚本。
  `doctor [6]` 会拦截机器绝对路径;`tests/smoke.sh` 会拦截个人标识残留。
- 脚本里不得假设用户名、`$HOME` 之外的固定路径或特定启动器名,一律用 `AGENT_NAME` / `PROFILE_HOME` 推导。
- 已推送的历史不为"整洁"而改写。

## 提交
- 提交信息说明依据(例如"doctor [3]: 某 skill 在线修改回收")。
- 提交身份用 profile 的 Git 身份: `. env/git-agent-env.sh` 之前先 `. lib/common.sh`,或直接通过启动器运行的会话提交。
- 验证顺序: `bash -n *.sh lib/*.sh bin/* tests/*.sh` → `tests/smoke.sh` → 临时 `PROFILE_HOME` 部署 → `doctor.sh`;
  改了 skills/配置渲染还要和 live 对比。
- 若用户授权 push 且要做 force-push/改写历史/删分支,先打 `backup/<日期>-<原因>` tag 并告知用户。
