#!/usr/bin/env bash
# 冒烟测试: 在临时 HOME 里用桩二进制跑 bootstrap + doctor,验证不同 AGENT_NAME、隔离、模块与设置合并。
# 不联网、不碰真实 HOME。用法: tests/smoke.sh
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fails=0
t() { # 描述 命令...
  local d="$1"; shift
  if "$@" >"$T/out" 2>&1; then pass=$((pass+1)); echo "  ok    $d"; else fails=$((fails+1)); echo "  FAIL  $d"; sed 's/^/        /' "$T/out" | tail -15; fi
}
tn() { local d="$1"; shift; if "$@" >"$T/out" 2>&1; then fails=$((fails+1)); echo "  FAIL  $d (应失败却成功)"; else pass=$((pass+1)); echo "  ok    $d"; fi; }

# 每个测试环境: 干净 HOME + 工作副本 + 桩 claude/codex
mkenv() { # name -> 设置 HOME_T, R (工作副本)
  HOME_T="$T/$1/home"; mkdir -p "$HOME_T"; R="$T/$1/repo"; cp -a "$REPO" "$R"; rm -rf "$R/.git" "$R/profile.env"
}
stub_bins() { # PROFILE_HOME
  mkdir -p "$1/claude-home/.local/bin" "$1/codex-home/.local/bin"
  printf '#!/bin/sh\n[ "$1" = --version ] && echo "%s (stub)" || exec /usr/bin/env\n' "$CLAUDE_VERSION" >"$1/claude-home/.local/bin/claude"
  printf '#!/bin/sh\n[ "$1" = --version ] && echo "codex-cli %s" || exec /usr/bin/env\n' "$CODEX_VERSION" >"$1/codex-home/.local/bin/codex"
  chmod +x "$1"/claude-home/.local/bin/claude "$1"/codex-home/.local/bin/codex
}
. "$REPO/pins.env"
run() { env -i HOME="$HOME_T" PATH="$PATH" "$@"; }   # 干净环境: 不继承当前用户的任何配置

echo "[A] AGENT_NAME 自定义 (alice) + 配置覆盖"
mkenv a; PH="$HOME_T/.agent-profiles/alice"; stub_bins "$PH"
cat >"$R/profile.env" <<EOP
AGENT_NAME=alice
AGENT_GIT_NAME="Alice Agent"
AGENT_GIT_EMAIL="alice@example.org"
SKILLS="gh-fix-ci mcp-builder"
MODULES="mod1"
EOP
mkdir -p "$PH/modules.local/mod1"
printf '# mod1\nuse tabs.\n' >"$PH/modules.local/mod1/claude.md"
printf 'model = "m-x"\n[projects."@WORKSPACE_ROOT@/p"]\ntrust_level = "trusted"\n' >"$PH/modules.local/mod1/codex-config.toml"
printf '{"model":"sonnet","env":{"A":"1"}}\n' >"$PH/modules.local/mod1/claude-settings.json"
printf '{"env":{"B":"2"}}\n' >"$PH/claude-settings.local.json"
t "bootstrap 成功"            run "$R/bootstrap.sh" --skip-install --no-doctor
t "启动器 claude-alice 已链接" test -L "$HOME_T/.local/bin/claude-alice"
t "启动器 codex-alice 已链接"  test -L "$HOME_T/.local/bin/codex-alice"
t "PROFILE_HOME 权限 700"     test "$(stat -c %a "$PH")" = 700
t "只部署选中的 skills"        bash -c "[ -d '$PH/claude/skills/gh-fix-ci' ] && [ ! -d '$PH/claude/skills/gh-address-comments' ] && [ ! -d '$PH/claude/skills/oil-ui' ]"
t "module claude.md 已拼接"   grep -q 'use tabs' "$PH/claude/CLAUDE.md"
t "codex 顶层键被提到表之前"   python3 -c "
import tomllib,sys; d=tomllib.load(open('$PH/codex/config.toml','rb'))
assert d['model']=='m-x' and d['sandbox_mode']=='workspace-write' and 'model' not in d['agents'], d
assert d['projects']['$HOME_T/work/p']['trust_level']=='trusted', d"
t "claude 设置三层深度合并"    python3 -c "
import json; d=json.load(open('$PH/claude/settings.json'))
assert d['model']=='sonnet' and d['env']=={'A':'1','B':'2'} and d['theme']=='auto', d"
t "dev 预设: 联网 + 可写缓存目录" python3 -c "
import tomllib; d=tomllib.load(open('$PH/codex/config.toml','rb')); w=d['sandbox_workspace_write']
assert w['network_access'] is True and '$HOME_T/.cache' in w['writable_roots'], d"
t "doctor PASS"               run "$R/doctor.sh"
t "doctor --deep 不崩溃(桩二进制无 codex doctor)" run "$R/doctor.sh" --deep
t "bootstrap 幂等(二次无更新)" bash -c "run() { env -i HOME='$HOME_T' PATH='$PATH' \"\$@\"; }; ! run '$R/bootstrap.sh' --skip-install --no-doctor | grep -q 'updated\|  claude:'"
OUT_C="$(run ANTHROPIC_API_KEY=x OPENAI_API_KEY=y "$HOME_T/.local/bin/claude-alice")"
t "启动器: 身份来自 profile.env" bash -c "grep -q '^GIT_AUTHOR_EMAIL=alice@example.org\$' <<<'$OUT_C'"
t "启动器: Anthropic 凭据被清除" bash -c "! grep -q '^ANTHROPIC_API_KEY=' <<<'$OUT_C'"
t "启动器: 目录来自 AGENT_NAME"  bash -c "grep -q '^CLAUDE_CONFIG_DIR=$PH/claude\$' <<<'$OUT_C'"
OUT_X="$(run OPENAI_API_KEY=y "$HOME_T/.local/bin/codex-alice")"
t "codex 启动器: OpenAI 凭据被清除" bash -c "! grep -q '^OPENAI_API_KEY=' <<<'$OUT_X'"
OUT_K="$(run OPENAI_API_KEY=y KEEP_ENV=OPENAI_API_KEY "$HOME_T/.local/bin/codex-alice")"
t "KEEP_ENV 保留变量"           bash -c "grep -q '^OPENAI_API_KEY=y\$' <<<'$OUT_K'"

echo "[B] 第二个 profile (bob) 与 alice 互不干扰, 路径含特殊字符"
HOME_T="$T/b/home"; mkdir -p "$HOME_T"; R="$T/b/re&po #x"; cp -a "$REPO" "$R"; rm -rf "$R/.git" "$R/profile.env"
PH="$HOME_T/.agent-profiles/bob"; stub_bins "$PH"
printf 'AGENT_NAME=bob\nWORKSPACE_ROOT="%s/w#s&k"\nMODULES=m2\n' "$HOME_T" >"$R/profile.env"
mkdir -p "$PH/modules.local/m2"; printf 'root=@WORKSPACE_ROOT@ me=@AGENT_NAME@\n' >"$PH/modules.local/m2/claude.md"
t "bootstrap(路径含 # & 空格)"  run "$R/bootstrap.sh" --skip-install --no-doctor --zsh
t "模板替换正确"               grep -qF "root=$HOME_T/w#s&k me=bob" "$PH/claude/CLAUDE.md"
t "zshrc 模板含 PROFILE_HOME"  grep -qF "AGENT_PROFILE_HOME=\"$PH\"" "$PH/zsh/.zshrc"
t "未设 SKILLS = 全部(旧行为)"  test -d "$PH/claude/skills/oil-ui"
t "doctor PASS(bob)"           run "$R/doctor.sh"
t "占位 Git 身份有警告"         bash -c "run() { env -i HOME='$HOME_T' PATH='$PATH' \"\$@\"; }; run '$R/doctor.sh' | grep -q '占位身份'"

echo "[B2] codex 访问预设与信任目录"
mkdir -p "$T/b/trust"; 
t "safe 预设无联网"            bash -c "env -i HOME='$HOME_T' PATH='$PATH' CODEX_ACCESS=safe CODEX_TRUSTED_DIRS='~/w1 $HOME_T/p\"q' '$R/bootstrap.sh' --skip-install --no-doctor && python3 -c \"
import tomllib; d=tomllib.load(open('$PH/codex/config.toml','rb'))
assert d['sandbox_mode']=='workspace-write' and 'sandbox_workspace_write' not in d, d
assert d['projects']['$HOME_T/w1']['trust_level']=='trusted' and d['projects']['$HOME_T/p\\\"q']['trust_level']=='trusted', d\""
t "full 预设"                  bash -c "env -i HOME='$HOME_T' PATH='$PATH' CODEX_ACCESS=full '$R/bootstrap.sh' --skip-install --no-doctor && grep -q 'danger-full-access' '$PH/codex/config.toml'"
t "none 预设无 sandbox_mode"    bash -c "env -i HOME='$HOME_T' PATH='$PATH' CODEX_ACCESS=none '$R/bootstrap.sh' --skip-install --no-doctor && ! grep -q sandbox_mode '$PH/codex/config.toml'"
mkdir -p "$PH/modules.local/dup"; printf '[sandbox_workspace_write]\nnetwork_access = false\n' >"$PH/modules.local/dup/codex-config.toml"
tn "重复表被校验拦截(不写入坏配置)" env -i HOME="$HOME_T" PATH="$PATH" CODEX_ACCESS=dev MODULES=dup "$R/bootstrap.sh" --skip-install --no-doctor
t "CODEX_ACCESS=none + 自定义表可用" env -i HOME="$HOME_T" PATH="$PATH" CODEX_ACCESS=none MODULES=dup "$R/bootstrap.sh" --skip-install --no-doctor
tn "无效 CODEX_ACCESS 被拒绝"    env -i HOME="$HOME_T" PATH="$PATH" CODEX_ACCESS=bogus "$R/bootstrap.sh" --skip-install --no-doctor

echo "[C] 路径推导 / 非法输入"
mkenv c; mkdir -p "$HOME_T/.agent-profiles/carol"; R2="$HOME_T/.agent-profiles/carol/repo"; mv "$R" "$R2"
stub_bins "$HOME_T/.agent-profiles/carol"
t "仓库在 ~/.agent-profiles/<名>/repo 时自动推导名称" bash -c "env -i HOME='$HOME_T' PATH='$PATH' '$R2/bin/agent-claude' | grep -q '^CLAUDE_CONFIG_DIR=$HOME_T/.agent-profiles/carol/claude\$'"
rm -f "$R2/profile.env"
mkenv d
tn "无 AGENT_NAME 且位置不规范 -> 明确报错"  run "$R/bootstrap.sh" --skip-install --no-doctor
tn "非法 AGENT_NAME 被拒绝"                 run AGENT_NAME='Bad Name' "$R/bootstrap.sh" --skip-install --no-doctor
tn "PROFILE_HOME=\$HOME 被拒绝"              run AGENT_NAME=x PROFILE_HOME="$HOME_T" "$R/bootstrap.sh" --skip-install --no-doctor
tn "未知 module 被拒绝"                     run AGENT_NAME=x MODULES=nope "$R/bootstrap.sh" --skip-install --no-doctor
tn "SKILLS 拼错被拒绝"                      run AGENT_NAME=x SKILLS="gh-fix-cii" "$R/bootstrap.sh" --skip-install --no-doctor
tn "模板 module(_template) 被拒绝"           run AGENT_NAME=x MODULES=_template "$R/bootstrap.sh" --skip-install --no-doctor

echo "[D] 仓库本体通用性: 不含个人信息"
t "无个人标识残留" bash -c "! git -C '$REPO' ls-files 2>/dev/null | grep -v '^skills/' | xargs grep -nIiE 'kooki3|michaelwang' | grep -v 'SKILL_LOOM_REPO' | grep -v '^tests/smoke.sh'"

echo; echo "passed=$pass failed=$fails"; [ $fails -eq 0 ]
