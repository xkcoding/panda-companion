# 熊猫伴行安装说明

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

