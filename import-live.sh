#!/usr/bin/env bash
# 把 live 目录(PROFILE_HOME/{claude,codex}/skills[-disabled])里的 skills 收回仓库。
# 首次迁移与日后 adopt(在线改动回收)是同一个动作,可重复运行。
#   claude 在用版本 = 基准 skills/<name>;codex 版本不同则存为 skills/<name>@codex
#   claude 未启用的 skill 以 codex 在用版本为基准(claude 的 skills-disabled 旧副本被忽略)
#   skills.conf 里已有条目的 hosts 保持不变,新 skill 才按 live 状态推导
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/lib/common.sh"

C="$PROFILE_HOME/claude"; X="$PROFILE_HOME/codex"
conf="$REPO/skills/skills.conf"
mkdir -p "$REPO/skills"
[ -f "$conf" ] || printf '# name = hosts(claude,codex)。改这里即启用/停用;不要靠移动目录。\n' >"$conf"

is_skill() { [ -f "$1/SKILL.md" ]; }
names="$( { for d in "$C"/skills/* "$C"/skills-disabled/* "$X"/skills/*; do
              [ -d "$d" ] && is_skill "$d" && basename "$d"; done; } | grep -v '^synced$' | sort -u )"

clean() { find "$1" \( -name __pycache__ -o -name .DS_Store \) -prune -exec rm -rf {} + 2>/dev/null || true; }
copy_dir() { rm -rf "$2"; cp -a "$1" "$2"; clean "$2"; }

n_new=0; n_upd=0; n_var=0
for n in $names; do
  # 只有"在用"的副本才参与比较;claude 停用的旧副本只在两边都没有在用版本时兜底
  c=""; [ -d "$C/skills/$n" ] && c="$C/skills/$n"
  x=""; [ -d "$X/skills/$n" ] && x="$X/skills/$n"
  base="${c:-$x}"
  [ -z "$base" ] && base="$C/skills-disabled/$n"
  # 基准内容变化才复制,避免无谓 diff
  if ! [ -d "$REPO/skills/$n" ] || ! diff -rq -x __pycache__ -x .DS_Store "$base" "$REPO/skills/$n" >/dev/null 2>&1; then
    [ -d "$REPO/skills/$n" ] && n_upd=$((n_upd+1)) || n_new=$((n_new+1))
    copy_dir "$base" "$REPO/skills/$n"
  fi
  if [ -n "$c" ] && [ -n "$x" ] && ! diff -rq -x __pycache__ -x .DS_Store "$c" "$x" >/dev/null 2>&1; then
    diff -rq -x __pycache__ -x .DS_Store "$x" "$REPO/skills/$n@codex" >/dev/null 2>&1 || { copy_dir "$x" "$REPO/skills/$n@codex"; n_var=$((n_var+1)); }
  else
    rm -rf "$REPO/skills/$n@codex"
  fi
  if ! grep -qE "^${n}[[:space:]]*=" "$conf"; then
    h=""; [ -d "$C/skills/$n" ] && h="claude"; [ -d "$X/skills/$n" ] && h="${h:+$h,}codex"
    [ -n "$h" ] || h="codex"
    printf '%s = %s\n' "$n" "$h" >>"$conf"
  fi
done
say "import-live: new=$n_new updated=$n_upd codex-variants-written=$n_var (total $(echo "$names" | wc -l))"
for n in $(skill_names); do echo "$names" | grep -qx "$n" || warn "skills.conf lists '$n' but no live copy found (kept in repo)"; done
