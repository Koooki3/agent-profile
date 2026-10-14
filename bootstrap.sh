#!/usr/bin/env bash
# 个人 agent profile 部署(幂等)。
#   ./bootstrap.sh              渲染配置 + 同步 skills + 安装二进制 + 链接启动器 + doctor
#   ./bootstrap.sh --sync       先 git pull --ff-only 再执行
#   --skip-install              不装 claude/codex/skill-loom(离线或只刷新配置)
#   --no-link                   不在 BIN_DIR(默认 ~/.local/bin)创建启动器软链
#   --no-doctor                 跳过最后的自检
#   --zsh                       渲染 PROFILE_HOME/zsh/.zshrc(需让个人 SSH 会话 export ZDOTDIR=PROFILE_HOME/zsh)
# 环境变量: PROFILE_HOME / WORKSPACE_ROOT / MODULES / BIN_DIR / CODEX_BIN 可临时覆盖 profile.env
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/lib/common.sh"

SYNC=0; INSTALL=1; LINK=1; DOCTOR=1; ZSH=0
for a in "$@"; do case "$a" in
  --sync) SYNC=1;; --skip-install) INSTALL=0;; --no-link) LINK=0;; --no-doctor) DOCTOR=0;; --zsh) ZSH=1;;
  -h|--help) sed -n '2,9p' "$0"; exit 0;; *) die "unknown option: $a";; esac; done

[ $SYNC -eq 1 ] && { say "== git pull"; git -C "$REPO" pull --ff-only; }
say "REPO=$REPO"; say "PROFILE_HOME=$PROFILE_HOME"; say "MODULES='$MODULES' WORKSPACE_ROOT=$WORKSPACE_ROOT"
enabled_modules >/dev/null   # 提前校验 MODULES,名字写错就在这里终止
mkdir -p "$PROFILE_HOME"/{claude,codex,claude-home,codex-home,tools} "$STATE"
chmod 700 "$PROFILE_HOME/claude" "$PROFILE_HOME/codex" "$PROFILE_HOME/claude-home" "$PROFILE_HOME/codex-home"

# ---------- 1. 配置渲染 ----------
say "== render config"
# shellcheck disable=SC2046
compose "$REPO/claude/CLAUDE.base.md" $(module_files claude.md) | subst | put "$PROFILE_HOME/claude/CLAUDE.md"
# shellcheck disable=SC2046
compose "$REPO/codex/AGENTS.base.md" $(module_files codex.md)   | subst | put "$PROFILE_HOME/codex/AGENTS.md"
put "$PROFILE_HOME/claude/settings.json" <"$REPO/claude/settings.json"
# shellcheck disable=SC2046
compose "$REPO/codex/config.base.toml" $(module_files codex-config.toml) "$PROFILE_HOME/config.local.toml" | subst | put "$PROFILE_HOME/codex/config.toml"
for f in "$REPO"/codex/agents/*.toml; do put "$PROFILE_HOME/codex/agents/$(basename "$f")" <"$f"; done

if [ $ZSH -eq 1 ]; then
  sed "s#@REPO@#$REPO#g" "$REPO/env/zshrc.tmpl" | put "$PROFILE_HOME/zsh/.zshrc"
  say "  zsh: 个人会话需 export ZDOTDIR=$PROFILE_HOME/zsh 才会加载"
fi

# ---------- 2. skills ----------
say "== sync skills"
changed=0
for host in $HOSTS; do
  mkdir -p "$PROFILE_HOME/$host/skills"
  for n in $(skill_names); do
    live="$PROFILE_HOME/$host/skills/$n"
    if [[ " $(skill_hosts "$n") " == *" $host "* ]]; then
      src="$(skill_src "$n" "$host")"
      [ -d "$src" ] || die "missing skill source: $src"
      if [ -d "$live" ] && diff -rq -x __pycache__ -x .DS_Store "$src" "$live" >/dev/null 2>&1; then continue; fi
      [ -d "$live" ] && backup "$live"
      rm -rf "$live"; cp -a "$src" "$live"; changed=$((changed+1)); say "  $host: $n"
    elif [ -d "$live" ]; then   # 已停用: 移到 skills-disabled,不删除
      mkdir -p "$PROFILE_HOME/$host/skills-disabled"
      [ -d "$PROFILE_HOME/$host/skills-disabled/$n" ] && backup "$PROFILE_HOME/$host/skills-disabled/$n" && rm -rf "$PROFILE_HOME/$host/skills-disabled/$n"
      mv "$live" "$PROFILE_HOME/$host/skills-disabled/$n"; changed=$((changed+1)); say "  $host: disabled $n"
    fi
  done
done
say "  skills changed: $changed"

# ---------- 3. 启动器 ----------
if [ $LINK -eq 1 ]; then
  say "== link launchers -> $BIN_DIR"
  mkdir -p "$BIN_DIR"
  for b in claude-kooki3 codex-kooki3; do
    t="$BIN_DIR/$b"
    if [ -L "$t" ] && [ "$(readlink -f "$t")" = "$REPO/bin/$b" ]; then continue; fi
    if [ -e "$t" ] || [ -L "$t" ]; then
      mkdir -p "$STATE/backups/$TS"; mv "$t" "$STATE/backups/$TS/$b.launcher"; say "  moved old $b -> $STATE/backups/$TS/"
    fi
    ln -s "$REPO/bin/$b" "$t"; say "  linked $b"
  done
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR 不在 PATH,请加入 shell rc";; esac
fi

# ---------- 4. 二进制 ----------
if [ $INSTALL -eq 1 ]; then
  say "== install binaries (pins.env)"
  cbin="$PROFILE_HOME/claude-home/.local/bin/claude"
  if [ -x "$cbin" ] && [ "$("$cbin" --version 2>/dev/null | awk '{print $1}')" = "$CLAUDE_VERSION" ]; then
    say "  claude $CLAUDE_VERSION ok"
  else
    say "  installing claude $CLAUDE_VERSION into $PROFILE_HOME/claude-home (HOME 重定向,不碰共享安装)"
    env -u CLAUDE_CONFIG_DIR -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
      HOME="$PROFILE_HOME/claude-home" bash -c "curl -fsSL https://claude.ai/install.sh | bash -s -- $CLAUDE_VERSION" \
      || warn "claude 安装失败;可手动安装后确保存在 $cbin"
  fi
  # codex: 显式 CODEX_BIN 优先;否则装一份私有副本(官方 install.sh,HOME/CODEX_HOME 重定向,不碰共享安装)
  xbin="$PROFILE_HOME/codex-home/.local/bin/codex"
  if [ -n "${CODEX_BIN:-}" ]; then
    say "  codex: 使用 profile.env 指定的 $CODEX_BIN"
  elif [ -x "$xbin" ] && [ "$("$xbin" --version 2>/dev/null | awk '{print $NF}')" = "$CODEX_VERSION" ]; then
    say "  codex $CODEX_VERSION ok (private)"
  else
    say "  installing codex $CODEX_VERSION into $PROFILE_HOME/codex-home (HOME 重定向,不碰共享安装)"
    mkdir -p "$PROFILE_HOME/codex-home"
    curl -fsSL https://chatgpt.com/codex/install.sh -o "$STATE/codex-install.sh" \
      && env -u CODEX_HOME HOME="$PROFILE_HOME/codex-home" CODEX_HOME="$PROFILE_HOME/codex" \
             CODEX_INSTALL_DIR="$PROFILE_HOME/codex-home/.local/bin" CODEX_NON_INTERACTIVE=1 \
             bash "$STATE/codex-install.sh" --release "$CODEX_VERSION" \
      || warn "codex 安装失败;可手动安装后在 profile.env 设置 CODEX_BIN"
  fi
  if [ ! -d "$PROFILE_HOME/tools/skill-loom/.git" ] && [ ! -f "$PROFILE_HOME/tools/skill-loom/pyproject.toml" ]; then
    say "  cloning skill-loom @ ${SKILL_LOOM_COMMIT:0:8}"
    { git clone -q "$SKILL_LOOM_REPO" "$PROFILE_HOME/tools/skill-loom" && git -C "$PROFILE_HOME/tools/skill-loom" checkout -q "$SKILL_LOOM_COMMIT"; } \
      || warn "skill-loom clone 失败(需要 GitHub 访问);其余功能不受影响"
  fi
fi

[ $DOCTOR -eq 1 ] && { say "== doctor"; "$REPO/doctor.sh" || true; }
cat <<MSG

下一步(每台机器各做一次,凭据不在仓库里):
  claude-kooki3         # 进入后 /login
  codex-kooki3 login    # 无头机器: codex-kooki3 login --device-auth
MSG
