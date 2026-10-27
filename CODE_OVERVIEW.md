# 代码结构

## 应用与界面

`ClipboardHistoryApp.swift` 使用 AppKit 主循环，持有服务、菜单栏状态项、历史弹出面板和设置窗口。SwiftUI 负责窗口内容。菜单栏使用 18pt 模板图标，应用图标位于 Assets.xcassets。

`Views/ClipboardHistoryView.swift` 与 `ClipboardRowView.swift` 展示文字、图片、搜索、删除和清空功能；`SettingsView.swift` 管理偏好。历史面板和右键菜单采用应用的系统外观，支持浅色和深色模式。

`Support/ImagePreviewController.swift` 由 AppDelegate 持有，使用图片数据的 SHA-256 管理独立预览窗口；相同内容复用窗口，不同图片可同时显示，关闭时释放对应窗口。图片按原始像素尺寸显示在双向滚动视图中。列表的预览按钮与复制区域分开处理点击，打开预览前关闭历史面板并清除待粘贴状态。

## 记录与保存

`Services/ClipboardMonitor.swift` 每 0.3 秒检查剪贴板 changeCount，读取文字或图片，过滤连续重复内容。写回时同步 changeCount，避免将选中的历史再次入库。

`Services/ClipboardStore.swift` 维护最新优先的历史列表和条数上限。保存开启时，将文字、图片数据、ID 和时间戳统一编码为二进制 plist，以原子替换方式写入 Application Support。支持迁移旧版 UserDefaults 文本历史。新增、删除、清空和调整上限均同步持久化，读写错误在设置中显示。

`Services/ExpirationScanner.swift` 每 60 秒扫描一次，仅在保存关闭且过期时长大于零时删除旧记录。关闭保存时立即按原过期设置清理；开启保存时，启动恢复和扫描均不按时间删除历史。

## 快捷键与粘贴

`Support/GlobalHotkey.swift` 使用 Carbon 注册系统快捷键。设置界面录制时暂停旧快捷键，取消后恢复，成功后保存新组合键。

打开历史面板前记录目标应用 PID。选择记录后先写回剪贴板并关闭面板，`Support/PasteSimulator.swift` 再激活目标应用，等待前台切换和修饰键释放后发送一次 ⌘V。取消面板会清除目标状态。

`Services/AccessibilityService.swift` 管理辅助功能授权状态。未授权时仍可打开列表和写回剪贴板，但无法自动粘贴。

`Support/RightClickMenuController.swift` 提供设置、暂停监听、自启动、授权状态、关于和退出菜单。

`Support/InputFocusDetector.swift` 是保留的辅助功能焦点检测工具，目前不参与自动粘贴流程，以免漏判浏览器或自定义编辑器的输入控件。
