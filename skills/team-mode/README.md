# Team Mode 小队模式

主 Agent 按任务价值协调四个工作角色：Explorer 定位大型代码库的主要文件，Executor 完成有边界的实现，Reviewer 独立复审并可按需留存 Markdown 报告，ExpertAdvisor 处理复杂决策、建模、复杂计算机自动化或反复未解决的问题。简单任务可以不派子 Agent。

主 Agent 负责拆解任务并分配具体问题或交付结果；文件提示和故障猜测只是线索，子 Agent 在分配的范围内自行选择做法。

本个人配置的四个已安装角色位于 `$CODEX_HOME/agents/`；`default.toml` 是可选的 GPT-6 Luna Low 派发哨兵，不是 Team Mode 的必要条件。安装和模型优先级见[角色配置说明](references/custom-agents.md)。

[Explore](references/explore.md) 按需定位大型代码库中的相关文件和关系；[Simplify](references/simplify.md) 按请求或在提交前检查改动的复杂度并安排复核。两条路径都按独立任务决定子 Agent 数量，主 Agent 负责整合与验收。

提示词统一使用英语。派发默认使用 `fork_turns="none"`，在任务简报中写明相关决定；Reviewer 和 ExpertAdvisor 从空历史上下文开始。当前宿主只支持 `none` 和 `all`，不支持回合数；Executor 只有确实需要完整历史时才使用 `all`。所有已安装角色默认沿用主 Agent 的模型、推理强度与服务档位；只有用户对具体任务要求覆盖时才显式指定。角色职责与只读边界保持原有定义。

本地诊断可按需运行 `python3 scripts/current_model.py` 和 `python3 scripts/usage_by_model.py --days 7 --by-agent --json`。使用前以脚本 `--help` 核对参数；工作流见 [SKILL.md](SKILL.md)，验证边界见[评估说明](references/evaluation.md)。

## 适用边界与依赖

Team Mode 适用于可明确分工、独立复审或确实需要专家处理复杂问题的任务；普通问答和短任务由主 Agent 直接完成。Skill 需要支持自定义子 Agent 的 Codex；本地诊断脚本需要 Python 3.10+ 和保留的会话日志。
