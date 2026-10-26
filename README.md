# ClipboardHistory

macOS 菜单栏剪贴板历史工具，支持文字、图片、搜索和快捷键粘贴。

## 使用

- 左键点击菜单栏剪贴板图标打开历史列表，或使用默认快捷键 `⌘⇧V`。
- 在目标输入框放置光标，打开列表并选择记录，即可写回剪贴板并尝试自动粘贴。自动粘贴需要在系统设置中授予辅助功能权限。
- 右键菜单提供设置、暂停监听、开机自启动、辅助功能状态、关于和退出（`⌘Q`）。
- 可在设置中录制历史列表快捷键。

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

也可在仓库根目录执行本地无签名构建：

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
