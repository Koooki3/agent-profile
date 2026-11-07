# shellcheck shell=bash
# shellcheck disable=SC2034  # 这些变量由 source 本文件的脚本使用
# 公共库: 解析 REPO / AGENT_NAME / PROFILE_HOME / 模块,提供渲染与备份函数。
# 被 bootstrap.sh、doctor.sh、import-live.sh 与 bin/ 下的启动器 source。
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# ---------- 配置来源优先级: 环境变量 > profile.env > 默认值 ----------
_CFG_VARS="PROFILE_HOME AGENT_NAME AGENT_GIT_NAME AGENT_GIT_EMAIL WORKSPACE_ROOT MODULES SKILLS CODEX_BIN KEEP_ENV EXTRA_UNSET_ENV BIN_DIR CODEX_ACCESS CODEX_TRUSTED_DIRS"
for _v in $_CFG_VARS; do
  if [ -n "${!_v+x}" ]; then printf -v "_o_$_v" '%s' "${!_v}"; fi
done
[ -f "$REPO/profile.env" ] && . "$REPO/profile.env"
# pins.env 只提供默认值(用 ${VAR:=...}),所以 profile.env / 环境变量也可以覆盖版本
. "$REPO/pins.env"
for _v in $_CFG_VARS; do
  _k="_o_$_v"
  if [ -n "${!_k+x}" ]; then printf -v "$_v" '%s' "${!_k}"; fi
done
unset _v _k

# ---------- AGENT_NAME / PROFILE_HOME ----------
# 1) 显式 PROFILE_HOME;2) 否则 $HOME/.agent-profiles/$AGENT_NAME;
# 3) 都没给时,仅当仓库位于 $HOME/.agent-profiles/<name>/<repo> 才自动推导,避免把 $HOME 当成 PROFILE_HOME。
if [ -z "${PROFILE_HOME:-}" ]; then
  if [ -n "${AGENT_NAME:-}" ]; then
    PROFILE_HOME="$HOME/.agent-profiles/$AGENT_NAME"
  else
    _parent="$(dirname "$REPO")"
    case "$_parent" in
      "$HOME"/.agent-profiles/*) PROFILE_HOME="$_parent"; AGENT_NAME="$(basename "$_parent")";;
      *) die "无法确定 profile 名称与目录: 请在 profile.env 设置 AGENT_NAME(例如 AGENT_NAME=alice)," \
             "或把仓库克隆到 \$HOME/.agent-profiles/<名称>/repo。见 profile.env.example";;
    esac
    unset _parent
  fi
fi
AGENT_NAME="${AGENT_NAME:-$(basename "$PROFILE_HOME")}"
[[ "$AGENT_NAME" =~ ^[a-z0-9][a-z0-9_-]{0,31}$ ]] \
  || die "AGENT_NAME='$AGENT_NAME' 不合法(小写字母/数字/_/-,以字母或数字开头,最长 32);请在 profile.env 设置 AGENT_NAME"
case "$PROFILE_HOME" in /*) ;; *) die "PROFILE_HOME 必须是绝对路径: $PROFILE_HOME";; esac
# PROFILE_HOME 保护: 不能是 $HOME 或其上级、不能在 ~/.claude ~/.codex ~/.ssh ~/.gnupg 内、不能是仓库本身或其子目录
_ph="$(readlink -m "$PROFILE_HOME")"; _home="$(readlink -f "$HOME")"
case "$_home/" in "$_ph"/*) die "PROFILE_HOME 不能是 \$HOME 或其上级目录: $PROFILE_HOME";; esac
for _d in .claude .codex .ssh .gnupg; do
  case "$_ph/" in "$_home/$_d/"*) die "PROFILE_HOME 不能位于 ~/$_d 内(那是共享安装/密钥目录): $PROFILE_HOME";; esac
done
case "$_ph/" in "$REPO/"*) die "PROFILE_HOME 不能是仓库目录本身或其子目录: $PROFILE_HOME";; esac
unset _ph _home _d

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/work}"
MODULES="${MODULES:-}"
KEEP_ENV="${KEEP_ENV:-}"
EXTRA_UNSET_ENV="${EXTRA_UNSET_ENV:-}"
CODEX_ACCESS="${CODEX_ACCESS:-dev}"
CODEX_TRUSTED_DIRS="${CODEX_TRUSTED_DIRS:-}"
[[ "$CODEX_ACCESS" =~ ^[a-z]+$ ]] && { [ "$CODEX_ACCESS" = none ] || [ -f "$REPO/codex/presets/$CODEX_ACCESS.toml" ]; } \
  || die "CODEX_ACCESS='$CODEX_ACCESS' 无效(可选: none $(cd "$REPO/codex/presets" && ls *.toml | sed 's/\.toml$//' | tr '\n' ' '))"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
# 未配置身份时使用占位身份(不会冒用共享账号的 git 身份),doctor 会提示
GIT_IDENTITY_IS_DEFAULT=0
if [ -z "${AGENT_GIT_NAME:-}" ] || [ -z "${AGENT_GIT_EMAIL:-}" ]; then GIT_IDENTITY_IS_DEFAULT=1; fi
AGENT_GIT_NAME="${AGENT_GIT_NAME:-$AGENT_NAME}"
AGENT_GIT_EMAIL="${AGENT_GIT_EMAIL:-$AGENT_NAME@users.noreply.invalid}"
STATE="$PROFILE_HOME/.profile-state"
TS="$(date -u +%Y%m%dT%H%M%SZ)-$$"   # 带 PID,同一秒内的多次运行不共用备份目录
BK="$STATE/backups/$TS"
HOSTS="claude codex"
LAUNCHER_CLAUDE="claude-$AGENT_NAME"
LAUNCHER_CODEX="codex-$AGENT_NAME"

rel()  { printf '%s' "${1#"$PROFILE_HOME"/}"; }

# 模板替换: 值里的 \ # & 先转义,路径里有这些字符也不会坏
sed_esc() { printf '%s' "$1" | sed -e 's/[\\#&]/\\&/g'; }
subst() {
  sed -e "s#@WORKSPACE_ROOT@#$(sed_esc "$WORKSPACE_ROOT")#g" -e "s#@AGENT_NAME@#$(sed_esc "$AGENT_NAME")#g" \
      -e "s#@HOME@#$(sed_esc "$HOME")#g" -e "s#@PROFILE_HOME@#$(sed_esc "$PROFILE_HOME")#g"
}

# 启动器用: 清掉可能属于共享账号的变量;KEEP_ENV(空格分隔)中列出的保留
unset_isolated() {
  local v
  for v in "$@"; do
    case " $KEEP_ENV " in *" $v "*) ;; *) unset "$v";; esac
  done
}

# 备份 live 路径(文件或目录)到本次备份目录
backup() {
  local p="$1" r; r="$(rel "$p")"
  mkdir -p "$BK/$(dirname "$r")"; cp -a "$p" "$BK/$r"
}

# stdin -> $1;内容相同则跳过,不同则先备份再写入
put() {
  local dst="$1" tmp; tmp="$(mktemp)"; cat >"$tmp"
  if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then rm -f "$tmp"; return 0; fi
  if [ -e "$dst" ]; then backup "$dst" || { rm -f "$tmp"; return 1; }; fi
  mkdir -p "$(dirname "$dst")"
  mv "$tmp" "$dst" || { rm -f "$tmp"; return 1; }
  chmod 644 "$dst"
  say "  updated $(rel "$dst")"
}

# 把若干文件按序拼接(跳过空/不存在),用空行分隔
compose() {
  local first=1 f
  for f in "$@"; do
    [ -s "$f" ] || continue
    [ $first -eq 1 ] || printf '\n'
    cat "$f"; first=0
  done
}

# 拼接 TOML 片段: 先输出各文件第一个 [table] 之前的顶层键,再输出各文件的表部分。
# 否则后面 module 里的顶层键(如 model = ...)会被拼进前一个文件末尾的表里,语义出错。
compose_toml() {
  local f part
  for part in top tables; do
    for f in "$@"; do
      [ -s "$f" ] || continue
      awk -v part="$part" '/^[[:space:]]*\[/ {t=1} (part=="top" && !t) || (part=="tables" && t)' "$f"
      printf '\n'
    done
  done
}

# codex 配置 = 访问预设(CODEX_ACCESS) + base + 各 module + CODEX_TRUSTED_DIRS 生成的信任表 + PROFILE_HOME/config.local.toml
render_codex_config() {
  local tf d preset=""; tf="$(mktemp)"
  [ "$CODEX_ACCESS" = none ] || preset="$REPO/codex/presets/$CODEX_ACCESS.toml"
  for d in $CODEX_TRUSTED_DIRS; do
    d="${d/#\~/$HOME}"; d="${d//\\/\\\\}"; d="${d//\"/\\\"}"
    printf '[projects."%s"]\ntrust_level = "trusted"\n\n' "$d"
  done >"$tf"
  # shellcheck disable=SC2046
  compose_toml "$preset" "$REPO/codex/config.base.toml" $(module_files codex-config.toml) "$tf" "$PROFILE_HOME/config.local.toml" | subst
  rm -f "$tf"
}
# 校验渲染结果是合法 TOML(重复的 [table]/键会在这里暴露);python < 3.11 无 tomllib 时跳过
validate_toml() {
  python3 -I - "$1" <<'PY' 2>&1 || return 1
import sys
try: import tomllib
except ImportError: sys.exit(0)
try: tomllib.loads(sys.argv[1])
except tomllib.TOMLDecodeError as e: print(e); sys.exit(1)
PY
}

# module 解析: PROFILE_HOME/modules.local/<m>(仓库之外,优先) > REPO/modules/<m>
module_dir() {
  if [ -d "$PROFILE_HOME/modules.local/$1" ]; then echo "$PROFILE_HOME/modules.local/$1"
  elif [ -d "$REPO/modules/$1" ]; then echo "$REPO/modules/$1"
  else return 1; fi
}
enabled_modules() {
  local m
  for m in $MODULES; do
    [[ "$m" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ && "$m" != *..* ]] || die "非法 module 名 '$m'(只允许单段名称: 字母/数字/_/./-,不含 .. 与 /)"
    [[ "$m" != _* ]] || die "module '$m' 是模板(以 _ 开头),请先复制为新名字: cp -r modules/_template \"$PROFILE_HOME/modules.local/<name>\""
    module_dir "$m" >/dev/null || die "unknown module: $m (找不到 modules.local/$m 或 modules/$m)"
    echo "$m"
  done
}
# 已启用 module 中存在的指定文件,按 MODULES 顺序输出
module_files() { local m d; for m in $(enabled_modules); do d="$(module_dir "$m")"; [ -f "$d/$1" ] && echo "$d/$1"; done; return 0; }

# claude settings.json = 仓库 base + 各 module 的 claude-settings.json + PROFILE_HOME/claude-settings.local.json,
# 逐层深度合并(后者覆盖前者)。只有一层时原样输出,不需要 python3。
render_claude_settings() {
  local files=("$REPO/claude/settings.json") f
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(module_files claude-settings.json)
  [ -f "$PROFILE_HOME/claude-settings.local.json" ] && files+=("$PROFILE_HOME/claude-settings.local.json")
  if [ ${#files[@]} -eq 1 ]; then subst <"${files[0]}"; return; fi
  command -v python3 >/dev/null || die "合并 claude 设置需要 python3"
  python3 -I - "${files[@]}" <<'PY' | subst
import json, sys
def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict): merge(a[k], v)
        else: a[k] = v
    return a
out = {}
for p in sys.argv[1:]:
    with open(p, encoding="utf-8") as fh: merge(out, json.load(fh))
print(json.dumps(out, indent=2, ensure_ascii=False))
PY
}

# ---------- skills ----------
# skills/skills.conf 是目录("name = host1,host2" 为该 skill 可用的 host)。
# 启用哪些由 SKILLS 决定: 未设置 = skills.conf 里全部(兼容旧行为);"all" = 全部;空 = 一个都不启用;
# 其余 = 空格分隔的名字列表。
skill_names() { grep -E '^[A-Za-z0-9][A-Za-z0-9._-]*[[:space:]]*=' "$REPO/skills/skills.conf" | sed -E 's/[[:space:]]*=.*//'; }
skill_enabled() {
  [ -z "${SKILLS+x}" ] && return 0
  [ "$SKILLS" = all ] && return 0
  case " $SKILLS " in *" $1 "*) return 0;; esac
  return 1
}
skill_hosts() {
  skill_enabled "$1" || return 0
  grep -E "^$1[[:space:]]*=" "$REPO/skills/skills.conf" | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]#].*//; s/,/ /g'
}
# SKILLS 里写了 skills.conf 没有的名字 -> 立即报错(拼写错误不要静默忽略)
check_skills() {
  local s; [ -z "${SKILLS:-}" ] || [ "$SKILLS" = all ] && return 0
  for s in $SKILLS; do skill_names | grep -qx -- "$s" || die "SKILLS 里的 '$s' 不在 skills/skills.conf 中"; done
}
skill_src()   { # name host -> repo source dir
  if [ "$2" = codex ] && [ -d "$REPO/skills/$1@codex" ]; then echo "$REPO/skills/$1@codex"; else echo "$REPO/skills/$1"; fi
}
