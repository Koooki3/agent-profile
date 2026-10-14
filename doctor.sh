#!/usr/bin/env bash
# 自检: 隔离性(行为级)、配置/skills 漂移、版本、登录状态、仓库密钥扫描。
# 退出码: 0 = 无 FAIL;1 = 有 FAIL。WARN 不影响退出码。
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/lib/common.sh"
fail=0; ok() { say "  ok    $*"; }; bad() { say "  FAIL  $*"; fail=1; }; wr() { say "  warn  $*"; }

enabled_modules >/dev/null || exit 1
say "[1] 启动器隔离(以 env 代替真实二进制,观察注入环境)"
stub="$(mktemp)"; printf '#!/bin/sh\nexec /usr/bin/env\n' >"$stub"; chmod +x "$stub"   # 忽略参数,只打印环境
probe() { # launcher bin-var
  env ANTHROPIC_API_KEY=leak ANTHROPIC_AUTH_TOKEN=leak OPENAI_API_KEY=keep GIT_ASKPASS=/x VSCODE_GIT_ASKPASS_MAIN=/x \
      PROFILE_HOME="$PROFILE_HOME" "$2=$stub" "$REPO/bin/$1" 2>&1
}
out="$(probe claude-kooki3 AGENT_CLAUDE_BIN)" || true
chk() { grep -qE "$2" <<<"$1" && ok "$3" || bad "$3"; }
chk_not() { grep -qE "$2" <<<"$1" && bad "$3" || ok "$3"; }
chk     "$out" "^CLAUDE_CONFIG_DIR=$PROFILE_HOME/claude\$" "claude: CLAUDE_CONFIG_DIR 指向个人目录"
chk     "$out" '^DISABLE_AUTOUPDATER=1$'                  "claude: 自动更新关闭"
chk_not "$out" '^ANTHROPIC_(API_KEY|AUTH_TOKEN)='         "claude: 不继承 Anthropic 凭据"
chk     "$out" '^GIT_AUTHOR_EMAIL=.+'                     "claude: 个人 Git 身份已注入"
chk     "$out" '^GIT_CONFIG_KEY_2=credential.helper$'     "claude: credential.helper 已清空"
chk_not "$out" '^(GIT_ASKPASS|VSCODE_GIT_ASKPASS_MAIN)='  "claude: 共享终端 askpass 已移除"
out="$(probe codex-kooki3 AGENT_CODEX_BIN)" || true
chk     "$out" "^CODEX_HOME=$PROFILE_HOME/codex\$"        "codex: CODEX_HOME 指向个人目录"
chk     "$out" '^GIT_AUTHOR_EMAIL=.+'                     "codex: 个人 Git 身份已注入"
chk_not "$out" '^(GIT_ASKPASS|VSCODE_GIT_ASKPASS_MAIN)='  "codex: 共享终端 askpass 已移除"

say "[2] 配置漂移(live 与重新渲染结果对比)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp" "$stub"' EXIT
# shellcheck disable=SC2046
{ compose "$REPO/claude/CLAUDE.base.md" $(module_files claude.md) | subst >"$tmp/claude.md"
  compose "$REPO/codex/AGENTS.base.md" $(module_files codex.md) | subst >"$tmp/agents.md"
  compose "$REPO/codex/config.base.toml" $(module_files codex-config.toml) "$PROFILE_HOME/config.local.toml" | subst >"$tmp/config.toml"; }
cmpf() { if [ ! -e "$2" ]; then bad "$3 缺失(运行 bootstrap.sh)"; elif cmp -s "$1" "$2"; then ok "$3"; else wr "$3 与仓库不一致(live 被在线修改?diff 查看;bootstrap.sh 会先备份再覆盖)"; fi; }
cmpf "$tmp/claude.md"  "$PROFILE_HOME/claude/CLAUDE.md"   "claude/CLAUDE.md"
cmpf "$tmp/agents.md"  "$PROFILE_HOME/codex/AGENTS.md"    "codex/AGENTS.md"
if [ -e "$PROFILE_HOME/codex/config.toml" ] && python3 - "$tmp/config.toml" "$PROFILE_HOME/codex/config.toml" <<'PY' 2>/dev/null
import sys,tomllib
a,b=(tomllib.load(open(f,'rb')) for f in sys.argv[1:3])
for d in (a,b): d.pop('tui',None)   # tui 表由 codex 自己维护(界面状态),不比较
sys.exit(0 if a==b else 1)
PY
then ok "codex/config.toml(语义一致)"; else cmpf "$tmp/config.toml" "$PROFILE_HOME/codex/config.toml" "codex/config.toml"; fi
cmpf "$REPO/claude/settings.json" "$PROFILE_HOME/claude/settings.json" "claude/settings.json"

say "[3] skills(按 skills.conf 逐 host 对比)"
miss=0; drift=0; total=0
for host in $HOSTS; do for n in $(skill_names); do
  [[ " $(skill_hosts "$n") " == *" $host "* ]] || continue
  total=$((total+1)); live="$PROFILE_HOME/$host/skills/$n"; src="$(skill_src "$n" "$host")"
  [ -f "$src/SKILL.md" ] || { bad "仓库源缺 SKILL.md: $src"; continue; }
  if [ ! -d "$live" ]; then miss=$((miss+1)); wr "$host/$n 未部署"
  elif ! diff -rq -x __pycache__ -x .DS_Store "$src" "$live" >/dev/null 2>&1; then drift=$((drift+1)); wr "$host/$n 与仓库不同(在线修改请 ./import-live.sh 收回,或 bootstrap.sh 覆盖)"; fi
done; done
[ $miss -eq 0 ] && [ $drift -eq 0 ] && ok "$total 个 host-skill 全部一致" || say "  summary: total=$total missing=$miss drifted=$drift"

say "[4] 二进制与版本"
cbin="$PROFILE_HOME/claude-home/.local/bin/claude"
if [ -x "$cbin" ]; then v="$("$cbin" --version 2>/dev/null | awk '{print $1}')"; [ "$v" = "$CLAUDE_VERSION" ] && ok "claude $v" || wr "claude $v != pin $CLAUDE_VERSION"; else bad "未安装 claude($cbin)"; fi
xbin="${CODEX_BIN:-}"; [ -z "$xbin" ] && [ -x "$PROFILE_HOME/codex-home/.local/bin/codex" ] && xbin="$PROFILE_HOME/codex-home/.local/bin/codex"
shared=0; [ -z "$xbin" ] && { xbin="$(command -v codex || true)"; shared=1; }
[ -n "${CODEX_BIN:-}" ] && [ "${CODEX_BIN:-}" = "$HOME/.local/bin/codex" ] && shared=1
if [ -n "$xbin" ] && [ -x "$xbin" ]; then v="$("$xbin" --version 2>/dev/null | awk '{print $NF}')"; [ "$v" = "$CODEX_VERSION" ] && ok "codex $v ($xbin)" || wr "codex $v != pin $CODEX_VERSION ($xbin)"
  [ $shared -eq 1 ] && wr "codex 来自共享安装($xbin),共享方升级会影响你;运行 bootstrap.sh(profile.env 不设 CODEX_BIN)可安装私有副本"
else bad "未找到 codex"; fi

say "[5] 登录状态(只检查文件是否存在,不读取内容)"
[ -s "$PROFILE_HOME/claude/.credentials.json" ] && ok "claude 已登录" || wr "claude 未登录: claude-kooki3 → /login"
[ -s "$PROFILE_HOME/codex/auth.json" ] && ok "codex 已登录" || wr "codex 未登录: codex-kooki3 login"

say "[6] 仓库内容安全扫描"
if git -C "$REPO" rev-parse >/dev/null 2>&1; then
  files="$(git -C "$REPO" ls-files -co --exclude-standard)"
  bad_names="$(grep -E '(^|/)(\.credentials\.json|auth\.json|\.claude\.json|profile\.env|history\.jsonl|.*\.sqlite)$' <<<"$files" || true)"
  [ -z "$bad_names" ] && ok "无凭据/状态类文件名" || bad "出现不该入库的文件: $bad_names"
  hits="$(cd "$REPO" && grep -rIlE '(^|[^A-Za-z0-9_-])(sk-(ant-)?[A-Za-z0-9_-]{24,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16})|BEGIN [A-Z ]*PRIVATE KEY|xox[bp]-[0-9A-Za-z-]{10,}' --exclude-dir=.git . || true)"
  [ -z "$hits" ] && ok "无疑似密钥内容" || bad "疑似密钥: $hits"
  # 通用性: 仓库本体(skills 之外)不得含具体机器的绝对路径;项目专属内容放 modules.local/(仓库之外)
  paths="$(cd "$REPO" && git ls-files -co --exclude-standard | grep -v '^skills/' | xargs grep -nIE '/hom[e]/[A-Za-z0-9_.-]+|/User[s]/[A-Za-z0-9_.-]+' 2>/dev/null || true)"
  [ -z "$paths" ] && ok "仓库本体无机器绝对路径" || bad "含机器绝对路径(应改为 \$HOME / @WORKSPACE_ROOT@ / 放进 modules.local): $paths"
fi
[ $fail -eq 0 ] && say "doctor: PASS" || say "doctor: FAIL"
exit $fail
