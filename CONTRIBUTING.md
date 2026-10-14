# Contributing

欢迎提交 issue 或 pull request。请说明 macOS 版本、PandaFan 版本、复现步骤，以及期望和实际行为。

提交前运行 `zsh test-all.zsh` 和 `python3 build-app.py`。UI 改动沿用 `DesignSystem.swift` 中的 token，并检查主面板、三个设置页、禁用与错误状态。

网络相关改动应保持以下边界：只处理匹配 PandaFan 的系统代理；保留其他代理例外；配置修改前备份；PandaFan 运行时拒绝修改 Fake-IP；恢复仅还原工具修改的字段。不要用测试修改真实网络配置。

不要提交个人规则、PandaFan 配置、订阅地址、账号令牌或本机诊断日志。请使用 example.com 和虚构的测试数据。
