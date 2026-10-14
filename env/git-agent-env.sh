#!/usr/bin/env bash

IDENTITY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-identity.gitconfig"

_GIT_NAME="$(git config --file "$IDENTITY" --get user.name)" || exit 1
_GIT_EMAIL="$(git config --file "$IDENTITY" --get user.email)" || exit 1

[[ -n "$_GIT_NAME" && -n "$_GIT_EMAIL" ]] || exit 1

# Agent 子进程使用个人 Git 配置
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=user.name
export GIT_CONFIG_VALUE_0="$_GIT_NAME"
export GIT_CONFIG_KEY_1=user.email
export GIT_CONFIG_VALUE_1="$_GIT_EMAIL"

# 强制默认提交作者和提交者使用个人身份
export GIT_AUTHOR_NAME="$_GIT_NAME"
export GIT_AUTHOR_EMAIL="$_GIT_EMAIL"
export GIT_COMMITTER_NAME="$_GIT_NAME"
export GIT_COMMITTER_EMAIL="$_GIT_EMAIL"

unset _GIT_NAME _GIT_EMAIL IDENTITY

# kooki3 credential isolation

# 禁止使用共享终端的 VS Code Git 认证
unset GIT_ASKPASS
unset SSH_ASKPASS
unset VSCODE_GIT_ASKPASS_NODE
unset VSCODE_GIT_ASKPASS_MAIN
unset VSCODE_GIT_ASKPASS_EXTRA_ARGS

# 禁止 Git 自动弹出认证提示
export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=never

# 清空个人 Agent 的 Git Credential Helper 列表
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_2=credential.helper
export GIT_CONFIG_VALUE_2=
