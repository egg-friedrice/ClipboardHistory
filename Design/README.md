# ClipboardHistory 图标

生成方式：内置 image_gen 工具。

原图：ClipboardHistory-icon.png（透明背景）。
应用资源：../ClipboardHistory/Assets.xcassets/AppIcon.appiconset，使用 sips 导出 macOS 所需的 16–1024px 各尺寸。
菜单栏：AppDelegate.makeStatusIcon() 绘制 18pt 单色模板图标，独立于彩色应用图标，随系统明暗模式着色。

最终生成提示词：

Use case: logo-brand. Create a polished macOS application icon for ClipboardHistory, a clipboard history utility. Single centered rounded-square app tile, subtle blue-to-indigo gradient, a crisp white clipboard with two slightly offset paper cards suggesting history, small turquoise clock-like circular arrow integrated at bottom right. Modern native macOS aesthetic, restrained soft depth, excellent recognizability at small sizes, no letters or words, no watermark, straight-on square composition. Transparent outside the rounded square, generous consistent macOS icon margin. Production icon asset, 1024x1024.
