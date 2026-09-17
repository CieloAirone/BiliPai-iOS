# 应用图标来源

原版提交：d9470b11297ea7948e5711491b73f6756c170dfe。
AndroidManifest.xml 默认图标为 ic_launcher_blue_snow_maid。

iOS 图标直接从上游 artwork/app-icon/blue_snow_maid_master_4096.png 和 blue_snow_maid_dark_master_4096.png 使用 Lanczos 缩小到 1024×1024，保留原始构图、配色和留白，无新增背景、重绘或裁切。深色变体由 iOS 18+ 的图标外观机制选择；iOS 17 使用普通变体。

图标外轮廓由 iOS 系统裁切，不仿制 Android 启动器遮罩。

## 无留白版本

构建版本 3 对原版母图按非白色像素边界裁切（(来自 4096×4096 母图的 474..3623 正方形区域)），再缩放到 1024×1024，使蓝色圆形铺满图标画布，不再保留四周白色留白。
