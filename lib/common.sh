# shellcheck shell=bash
# 公共库: 解析 REPO / PROFILE_HOME / 模块,提供渲染与备份函数。
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_o_ph="${PROFILE_HOME:-}"; _o_ws="${WORKSPACE_ROOT:-}"; _o_mod="${MODULES-__unset__}"
[ -f "$REPO/profile.env" ] && . "$REPO/profile.env"
. "$REPO/pins.env"
[ -n "$_o_ph" ] && PROFILE_HOME="$_o_ph"
[ -n "$_o_ws" ] && WORKSPACE_ROOT="$_o_ws"
[ "$_o_mod" != "__unset__" ] && MODULES="$_o_mod"
PROFILE_HOME="${PROFILE_HOME:-$(dirname "$REPO")}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/work}"
MODULES="${MODULES:-}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
STATE="$PROFILE_HOME/.profile-state"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BK="$STATE/backups/$TS"
HOSTS="claude codex"

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
rel()  { printf '%s' "${1#"$PROFILE_HOME"/}"; }

subst() { sed "s#@WORKSPACE_ROOT@#$WORKSPACE_ROOT#g"; }

# 备份 live 路径(文件或目录)到本次备份目录
backup() {
  local p="$1" r; r="$(rel "$p")"
  mkdir -p "$BK/$(dirname "$r")"; cp -a "$p" "$BK/$r"
}

# stdin -> $1;内容相同则跳过,不同则先备份再写入
put() {
  local dst="$1" tmp; tmp="$(mktemp)"; cat >"$tmp"
  if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then rm -f "$tmp"; return 0; fi
  [ -e "$dst" ] && backup "$dst"
  mkdir -p "$(dirname "$dst")"; mv "$tmp" "$dst"; chmod 644 "$dst"
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

enabled_modules() { local m; for m in $MODULES; do [ -d "$REPO/modules/$m" ] || die "unknown module: $m"; echo "$m"; done; }

# skills.conf: "name = host1,host2"
skill_names() { grep -E '^[A-Za-z0-9._-]+[[:space:]]*=' "$REPO/skills/skills.conf" | sed -E 's/[[:space:]]*=.*//'; }
skill_hosts() { grep -E "^$1[[:space:]]*=" "$REPO/skills/skills.conf" | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]#].*//; s/,/ /g'; }
skill_src()   { # name host -> repo source dir
  if [ "$2" = codex ] && [ -d "$REPO/skills/$1@codex" ]; then echo "$REPO/skills/$1@codex"; else echo "$REPO/skills/$1"; fi
}
