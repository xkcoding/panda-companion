# 熊猫伴行 · 交互设计

定位：PandaFan 的非官方轻量配套助手，不管理订阅、节点或 VPN 连接。

主面板依次为品牌、直连规则状态及主要操作、自动维护开关、网络兼容性入口、PandaFan 与设置入口。两个功能分开呈现，避免「规则完整」被误认为所有网络都已验证正常。

设置分为直连规则、运行设置、网络兼容性。首次使用规则为空，主操作引导添加规则；升级保留个人配置。兼容性页的检查、备份应用、恢复按钮沿用原有安全条件。

图标为原创薄荷绿底熊猫，鼻口使用分岔路径，菜单栏采用单色轮廓版本。使用系统文字、语义颜色与原生控件，支持系统深浅色外观。不添加动画轮询、WebView 或额外后台进程。

## Shared design tokens

`DesignSystem.swift` is the source of truth for the native UI:

| Token | Value / behavior |
|---|---|
| Color.accent | systemTeal, shared by selected navigation and primary buttons |
| Color.surface / text / muted | semantic AppKit colors, adapting to system appearance |
| Font | title 22, heading 16, section 13, body 12, caption 11, micro 10 pt |
| Space | 4 / 8 / 12 / 16 / 24 pt |
| cardRadius / fieldRadius | 14 / 8 pt |
| controlHeight | 30 pt |

Both surfaces use `DesignComponent.background`, `header`, `card`, and `primary`. Settings navigation uses `DesignTabs`, built from the same native button style. Native focus rings, input selection, and switches retain macOS accessibility behavior. Main-panel dimensions and settings dimensions are layout tokens; individual card heights are content-specific.
