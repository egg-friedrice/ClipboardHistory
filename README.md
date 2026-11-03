# ClipboardHistory

macOS 菜单栏剪贴板历史工具，支持文字、图片、搜索和快捷键粘贴。

## 使用

- 左键点击菜单栏剪贴板图标打开历史列表，或使用默认快捷键 `⌘⇧V`。
- 在目标输入框放置光标，打开列表并选择记录，即可写回剪贴板并尝试自动粘贴。自动粘贴需要在系统设置中授予辅助功能权限。
- 列表打开后，按 `↓` 从第一条开始预选，按 `↑` 从最后一条开始预选；继续按上下键移动，按回车粘贴预选记录。搜索内容变化后重新预选。
- 右键菜单提供设置、暂停监听、开机自启动、辅助功能状态、关于和退出（`⌘Q`）。
- 可在设置中录制历史列表快捷键。
- 图片记录右侧提供“预览”按钮，打开独立窗口完整显示图片；拖动窗口边缘调整大小时，图片居中等比缩放。再次预览相同图片会前置已有窗口，不同图片可以同时预览。预览不会复制或自动粘贴。在任意图片预览窗口按 `Esc` 可关闭所有图片预览。

- 搜索框右侧支持“全部／图片／文字”类型筛选。图片模式显示所有图片并暂停文字搜索；切回全部或文字模式后继续使用原搜索词。

## 历史记录

- 上限支持 5、10、20、30、50 条，默认 20；超过上限删除最早记录。
- 保存历史默认关闭，可在设置中开启。开启后文字和图片保存在本机，启动时恢复，自动过期不生效。
- 关闭保存时删除磁盘副本，当前内存记录按自动过期设置清理。自动过期可关闭或设置为 1–5 小时。
- 降低上限、删除和清空记录会同步更新内存及磁盘历史。
- 保存位置：`~/Library/Application Support/com.clipboard.ClipboardHistory/history.plist`。

## 构建

要求 macOS 14 或更高版本，以及支持该部署目标的 Xcode。

1. 打开根目录下的 `ClipboardHistory.xcodeproj`。
2. 选择 `ClipboardHistory` scheme 和本机 Mac，配置本地签名后运行。

仅用于开发验证的无签名构建（不要用它替换已授权的正式版本）：

```sh
xcodebuild -project ClipboardHistory.xcodeproj \
  -scheme ClipboardHistory -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

构建输出位于 `build/Build/Products/Release/`，已被 Git 忽略。

## 目录

- `ClipboardHistory/`：Swift 源码、应用配置及图标资源。
- `ClipboardHistory.xcodeproj/`：Xcode 工程和共享 scheme。
- `Design/`：应用图标原图及设计说明。
- `CODE_OVERVIEW.md`：代码结构说明。
- `PRD.md`：功能需求说明。

## 覆盖升级与辅助功能权限

macOS 根据代码签名身份识别应用；保持 Bundle ID 不变并不足以让无签名或 ad-hoc 构建继承权限。发布版本应始终使用同一团队的 Developer ID Application 签名，保持 `com.clipboard.ClipboardHistory` 和签名的 designated requirement 稳定，不要在开发签名与发布签名之间切换。

安装好证书和私钥后，执行：

```sh
SIGNING_IDENTITY='Developer ID Application: 你的名称 (TEAMID)' \
DEVELOPMENT_TEAM='TEAMID' bash Scripts/build-release.sh
```

脚本在缺少签名配置时直接失败，不会生成无签名发布包。输出位于 `build/release/Build/Products/Release/ClipboardHistory.app`。对外分发还应完成 Apple 公证。

退出旧版后，将新版覆盖到同一个 `/Applications/ClipboardHistory.app`，再启动。从旧的无签名或不同签名版本首次迁移时，可能仍需重新授权一次；后续保持签名身份的覆盖升级才具备保留授权的条件。应用不能自行授予或迁移系统辅助功能权限。

验证时，先给一个稳定签名版本授权，再构建代码有变化的同签名版本并覆盖安装；确认设置显示已授权，且选择历史记录能自动粘贴。右键菜单应贴在状态栏图标下方，第一项与退出项均完整显示；关闭菜单后左键仍应打开历史列表。也需在多显示器及自动隐藏菜单栏时检查布局。
