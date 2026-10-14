# 在 source 时捕获 profile 目录(本文件位于 <PROFILE_HOME>/repo/env/)
_AGENT_PROFILE_HOME_DEFAULT="${${(%):-%x}:A:h:h:h}"

# Shared Codex
codex() {
  env -u CODEX_HOME \
      -u OPENAI_API_KEY \
      -u CODEX_API_KEY \
      $HOME/.local/bin/codex --no-daemon "$@"
}

# Shared Claude Code
claude() {
  local bin="$HOME/.local/bin/claude"

  # 共享 CLI 未安装时，复用已有二进制程序
  if [[ ! -x "$bin" ]]; then
    bin="${AGENT_PROFILE_HOME:-$_AGENT_PROFILE_HOME_DEFAULT}/claude-home/.local/bin/claude"
  fi

  if [[ ! -x "$bin" ]]; then
    echo "Claude Code executable not found" >&2
    return 127
  fi

  env -u CLAUDE_CONFIG_DIR \
      -u ANTHROPIC_API_KEY \
      -u ANTHROPIC_AUTH_TOKEN \
      DISABLE_AUTOUPDATER=1 \
      "$bin" "$@"
}
