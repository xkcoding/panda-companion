# 熊猫伴行 · Panda Companion

<img src="assets/icon.png" width="96" alt="熊猫伴行图标">

PandaFan 的轻量配套助手。原生 macOS 菜单栏工具，提供直连规则维护与网络兼容性检查；非 PandaFan 官方产品。

## 下载安装

当前安装包使用 **临时签名（ad-hoc）**，尚未使用 Developer ID 证书签名，也未经过 Apple 公证。首次运行可能被 macOS 拦截，按下面步骤为对应程序单独确认即可；受管理设备可能不允许这样操作。

### 1. 下载并校验

在 [Releases](https://github.com/xkcoding/panda-companion/releases) 下载与你的 Mac 匹配的 ZIP 和同名 `.sha256` 文件：

- `arm64`：Apple Silicon（M 系列芯片）。
- `x86_64`：Intel。

若尚无正式版本，可在 [Release 工作流](https://github.com/xkcoding/panda-companion/actions/workflows/release.yml) 最近成功运行的 **Artifacts** 中下载。Actions 产物需要先解压一层，才能得到安装 ZIP 和校验文件。

在终端进入 ZIP 与校验文件所在目录，执行：

```sh
shasum -a 256 -c PandaCompanion-*-macOS-*.sha256
```

对应 ZIP 显示 `OK` 后再解压。校验和用于检查文件是否完整，应与安装包一起从本仓库下载。

### 2. 安装

1. 升级前，从菜单栏退出正在运行的「熊猫伴行」。仅关闭面板不等于退出。
2. 保持解压后的文件在同一目录，双击 **`Install.command`**。它会调用同目录的原生安装器 `Install`，无需 Python、Xcode 或 `sudo`。
3. 看到“安装完成”后，按回车关闭安装窗口。安装器会保留个人规则、检查间隔和自动维护状态。
4. 在 Finder 使用“前往 → 前往文件夹”，输入 `~/Applications`，打开 **熊猫伴行.app**。不要直接运行解压目录中的 App，以免跳过配置安装。

### 3. 首次运行被 macOS 拦截时

如果提示无法验证开发者或 Apple 无法检查是否包含恶意软件，且你已确认文件来自本仓库：

1. 先尝试打开被拦截的程序一次，然后关闭提示框。
2. 进入 **系统设置 → 隐私与安全性 → 安全性**，找到该程序对应的 **“仍要打开”（Open Anyway）**。
3. 按系统提示完成身份验证，并确认打开。
4. 安装过程中若被拦截的是 **`Install.command` 或 `Install`**，确认后重新双击 `Install.command`；安装成功后，首次打开 **熊猫伴行.app** 时也可能需要单独确认。

这些步骤采用 [Apple 官方提供的单个 App 打开方式](https://support.apple.com/zh-cn/102445)，无需关闭 Gatekeeper 或 SIP。

如果没有“仍要打开”，设备可能受组织策略限制，请联系管理员或选择从源码构建。若提示“已损坏”“将损坏你的电脑”，不要直接当作未公证提示忽略；请重新下载、核对校验和，并向项目反馈提示内容。

> CI 已验证构建、打包及隔离安装流程；浏览器下载后触发的 macOS 安全提示尚未在所有系统版本上实测，实际文案与可用选项以系统为准。

## 从源码构建

需要 macOS、Xcode Command Line Tools 和 Python 3。应用部署目标为 macOS 14+；本地交互已在 macOS 26 的 Apple Silicon 设备上验证；CI 分别检查两个 CPU 架构，不能代替所有系统版本的实机交互验证。

```sh
git clone https://github.com/xkcoding/panda-companion.git
cd panda-companion
python3 build-app.py
python3 install-app.py
```

升级前先退出「熊猫伴行」菜单栏应用。安装后从 `~/Applications/熊猫伴行.app` 打开，后台维护开关由你控制。构建产物使用本机临时签名，尚未进行 Developer ID 签名或 Apple 公证。

## 开始使用

1. 安装并连接 PandaFan。
2. 打开「熊猫伴行」→ 设置 → 直连规则，填写需要直接访问的域名。
3. 确认运行设置中的本机地址和端口与 PandaFan 一致，再开启自动维护。

新安装默认没有规则。已有用户升级后保留原规则、检查间隔及自动维护状态。

每行一个域名，例如 `example.com`、`*.example.com`。最多 200 条。裸域名和通配符分别填写。空列表停止维护规则；删除条目不会自动删除系统中已有的代理例外。

## 两个入口

- **直连规则**：维护 macOS 系统代理例外。仅在 PandaFan 运行且系统代理匹配指定本机地址、端口时补齐缺失条目。显示「已就绪」代表例外完整，不代表业务网站已经验证可用。
- **网络兼容性**：按需检查 PandaFan 增强模式的 Fake-IP 网段是否与其他 VPN 路由冲突。支持从 `198.18.0.1/16` 迁移到 `198.19.0.1/16`，目标也冲突时拒绝应用。

兼容性修改需要先完全退出 PandaFan。工具会备份配置，只修改网段字段，再由用户打开 PandaFan 连接并复测应用。恢复操作同样要求退出。检查本身不会修改配置；工具不切换 PandaFan 节点、不修改其他 VPN 路由。

系统代理例外只对遵循系统代理的连接有效，不能代替增强模式自身的分流规则。

## 自动维护

由 macOS launchd 调度：网络设置变化触发检查，默认每 10 秒兜底一次。状态正常时走快速检查，只有规则缺失才写入。菜单栏退出后自动维护仍可继续；暂停开关会持久停用维护。网络兼容性只在打开对应页面或手动检查时执行。

## 开发

- `App.swift`：菜单栏与主面板。
- `SettingsController.swift` / `CompatibilityPane.swift`：设置与兼容性界面。
- `DesignSystem.swift`：共用设计 token 和原生组件，设计约定见 [DESIGN.md](DESIGN.md)。
- `Configuration.swift` / `panda-companion`：配置、系统代理例外维护和 launchd 调度。
- `PandaCompatibility.swift`：网段检查、备份、修改与恢复。

运行测试：

```sh
zsh test-all.zsh
```

测试使用内存数据和临时目录，不需要 PandaFan，不修改系统网络设置。构建和测试只使用系统 Swift 工具链与标准库；运行应用无需 Python、Node 或 Electron。

## 使用边界

- 此工具不是 VPN，也不管理 PandaFan 订阅或节点。
- 系统代理例外无法保证所有应用的连接都直连，尤其是增强模式或自行使用代理的应用。
- Fake-IP 检查只覆盖当前支持的两个网段与采样路由，不能代替完整路由审计。PandaFan 配置格式变化时可能需要更新工具。
- PandaFan 配置备份可能含有账号信息，仅保存在本机；提交 issue 时不要上传配置备份、令牌或完整网络日志。

性能实现与限制见 [PERFORMANCE.md](PERFORMANCE.md)。欢迎通过 issue 或 pull request 提交问题与改进，参考 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License

[MIT](LICENSE) · Copyright (c) 2026 Yangkai.Shen

本项目与 PandaFan 官方没有隶属关系。项目图标为独立设计，PandaFan 名称用于说明兼容对象。

## 持续检查与发布

- Push / Pull Request：在两个架构上执行语法检查、测试、完整构建及安装包验证，并上传 ZIP 与 SHA-256 校验和。
- 手动运行 Release 工作流：构建所选分支的安装包，仅作为 Actions 产物保存，不创建正式 Release。
- 正式发布：更新 `VERSION`、合并代码，再推送对应 `vX.Y.Z` 标签。标签必须与 `VERSION` 一致；两个架构全部通过后，才会创建 GitHub Release 并上传产物。

```sh
# VERSION 内容为 1.3.0 时：
git tag v1.3.0
git push origin v1.3.0
```

CI 构建时会验证二进制架构、最低系统版本、签名、包内必要文件、无个人配置，以及临时目录中的安装与升级。发布失败后可重跑；已存在的正式 Release 不会被覆盖。
