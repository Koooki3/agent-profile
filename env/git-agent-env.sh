# shellcheck shell=bash
# 被启动器 source。身份来自 lib/common.sh 解析出的 AGENT_GIT_NAME / AGENT_GIT_EMAIL
# (profile.env 或环境变量;未配置时是占位身份,doctor 会提示)。
: "${AGENT_GIT_NAME:?AGENT_GIT_NAME not set (source lib/common.sh first)}"
: "${AGENT_GIT_EMAIL:?AGENT_GIT_EMAIL not set (source lib/common.sh first)}"

# 禁止使用共享终端的 VS Code / askpass 认证
unset GIT_ASKPASS SSH_ASKPASS VSCODE_GIT_ASKPASS_NODE VSCODE_GIT_ASKPASS_MAIN VSCODE_GIT_ASKPASS_EXTRA_ARGS

# GitHub CLI/API 令牌会优先于已登录凭据,可能让 push/gh 以别人的身份执行;KEEP_ENV 可保留自己的
unset_isolated GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN

# 禁止 Git 自动弹出认证提示
export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=never

# 默认提交作者与提交者
export GIT_AUTHOR_NAME="$AGENT_GIT_NAME"  GIT_AUTHOR_EMAIL="$AGENT_GIT_EMAIL"
export GIT_COMMITTER_NAME="$AGENT_GIT_NAME" GIT_COMMITTER_EMAIL="$AGENT_GIT_EMAIL"

# 通过 GIT_CONFIG_* 注入(优先于全局/系统 gitconfig): 身份 + 清空 credential.helper 列表
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0=user.name  GIT_CONFIG_VALUE_0="$AGENT_GIT_NAME"
export GIT_CONFIG_KEY_1=user.email GIT_CONFIG_VALUE_1="$AGENT_GIT_EMAIL"
export GIT_CONFIG_KEY_2=credential.helper GIT_CONFIG_VALUE_2=
