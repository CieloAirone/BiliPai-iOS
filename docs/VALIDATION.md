# 验证记录

## 2026-09-17

- 原生导航、设置页和五个主入口已通过 iPhone 16 Pro 模拟器 UI 测试。
- 首页截图显示真实推荐接口数据；截图见 `screenshots/Home.png`。
- 核心单元测试覆盖 WBI 已知签名向量、参数编码、搜索/历史模型、SIDX v0/v1、异常索引、HLS 清单、弹幕 Protobuf 解码与异常输入。
- 新增 4 秒合成 AVC/AAC 素材，运行真实 AVPlayer HLS 桥接播放测试，要求播放进度超过 1 秒且呈现视频尺寸非零。
- 最新媒体测试构建：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35201006476
- 已知通过的页面截图构建：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35200796660

## 尚未验收

无真实用户登录凭证，未代替用户验证扫码确认、会员画质、投币/点赞/收藏状态。未完成 iPhone 实机安装、长时间播放、后台/PiP、AirPlay、低网速及所有 Android 页面逐项视觉对照。

构建通过不等于原版全功能移植完成。详见 PARITY.md。

## Build 5 设置迁移

- 构建提交：ca3ba5ac56def3035ca39e2d52f0b94f88b1a806。
- Actions：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35219602320
- 18 项单元测试、2 项界面测试全部通过；包含设置开关重启持久化、搜索到 WebDAV 页面、无地址时上传不可用、非法备份拒绝、凭证/历史不进入导出、原版 AND/OR hide 规则。
- Settings.png、PlaybackSettings.png、WebDAVSettings.png 已更新为此构建的真实模拟器截图。
- WebDAV 上传/恢复代码已接入，但未提供真实服务器凭证，尚未进行用户服务器端到端验证。
- 设置差异详见 SETTINGS_PARITY.md，尚未达到全部设置/行为对等。

## Build 6 设置补接与播放/评论回归

- 构建提交：`d34460017477ea58099f8d04123d951657f46cee`。
- Actions：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35224829337
- 25 项单元测试、4 项 UI 测试全部通过，Release archive 成功。
- 实际点击 AVKit 全屏按钮，确认播放状态及全屏界面；退出后媒体未释放，视频输出继续产生新帧。截图 `NativeFullscreenVideo.png` 与 `VideoAfterFullscreen.png` 使用 60 秒合成视频，不是实际 B 站视频源的全屏验收。
- 楼中楼以 20+1 条测试数据验证第二页加载、父回复引用及末页按钮消失。截图 `CommentReplyParent.png`。
- 真实公开接口抽查：主评论 code 0；一条 54 条回复的根评论，回复接口首批返回 20 条，code 0。不使用用户凭证；不证明所有视频/登录/风控状态。
- Home / HomeDark / Settings / PlaybackSettings / WebDAVSettings 等截图更新为此次构建。
- IPA 版本 `0.1.0 (6)`，包标识 `fun.caservice.bilipai.ios`；SHA256 `afe00bf92f5f281269f383d8b836f76ba3fa6be851b3a34421c0bcaa3827661c`。
- 全部 Android 设置与视觉一致性仍未完成；真机、PiP、用户 WebDAV、生物识别与网络切换需继续验收。

## Build 7 顶部分类、番剧与字幕

- 构建提交：`951a31aee6d3259d3631c80a912bacde001ccb23`。
- Actions：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35236025482
- 29 项单元测试、6 项 UI 测试全部通过；Release archive 成功。
- 分类栏测试测量五项按钮宽高、中心 Y 坐标及相邻 4pt 间距，误差不超过 0.5pt；覆盖 light/dark 首页与 320pt 容器（内部栏宽 288pt）。截图 `CategoryBoxes-light.png`、`CategoryBoxes-dark.png`、`CategoryBoxes-320pt.png`；`CategoryBar-*` 是相同截图的顶部裁剪。
- 番剧真实请求复现：省略 type 返回 -400，补 type=1 返回 code 0。前两页各 20 条且第二页 20 条均为新记录，详情 23 集。UI 路由/详情/分页通过依赖注入数据验证，未把 UI 测试数据误称为真实网络验收。
- 字幕测试提供两条同语言 AI/人工轨道，验证“仅非 AI”选择正确轨道，并通过 AVPlayerItemLegibleOutput 收到实际解码文本；VTT 转换检查时间戳、转义和异常时序。
- iOS 会本地化字幕 displayName，因此不使用名称匹配，改用稳定的 HLS CHARACTERISTICS 轨道标识。
- SHA256：`2dffbeb95f3e5ad3e9c9aad5701709294c63f905055886c8c1c170c37ad1f6b4`，版本 `0.1.0 (7)`。

Build 8：30 项单元测试、8 项 UI 测试通过；自动全屏退出后视频帧继续更新，开关重启持久化，关注列表分页/重试/账号清空及未登录入口验证通过。尚未使用用户登录账号验收真实关注数据。
构建：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35245920283
提交：b41425b40d9d079eb5fb57540a608464b4ff3f6a
版本：0.1.0 (8)；SHA256：f23fb26dfb0942014ddbdd0ad06f3f29e5d95e7887acba533d7e5a4ba0b9cd5b

## Build 9 原生空间、卡片与互动

- 提交：`932ea91661211a48f44ab8f9abe114212174cf7d`；Actions：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35252993389
- 36 项单元测试、10 项 UI 测试全部通过；Release archive 成功。版本 `0.1.0 (9)`。
- 单元测试新增：空间分页/失败重试/排序重置/重复动态和停滞游标、旧视频缓存兼容、时长格式、评论 root/parent 关系、收藏夹差量提交。
- UI 测试新增：原生空间投稿/动态切换、三种卡片比例和时长展示。固定数据素材，无真实账号写入。
- 评论分页在接入回复按钮后曾出现尾部控件缺失；两次失败构建没有发布。将分页区域移出 LazyVStack、独立观察 CommentPages 后，原有第二页和父回复引用断言通过，未放宽断言。
- 更新截图：Settings、NativeSpace、VideoCards-16x9/4x3/16x10、CommentReplyParent。
- IPA SHA256：`abbdcf8179fb659c5b50e9dc4e36d1820e28f97e9b3e4859af4c86b9438dd2ae`，已核对 IPA 内 Info.plist 版本及随包校验文件。
- 公开资料 WBI 接口 code 0；投稿及原版聚合备用接口在当前网络 HTTP 412，不能宣称真实空间投稿已验收。关注/评论/收藏写入需用户在已登录设备验证。
- 全量设置与功能仍未对等，见 PARITY.md；本版不是完整移植完成版。


## 全屏与手势修复：尚未发布

- 35296778106 实际手势测试失败，两侧 HUD 未通过，未发布。
- 35297263322 横屏窗口断言通过，窗口为 874×402；亮度 HUD 通过，音量 HUD 失败。
- 手势改为左右各 22% 宽、中央 60% 高区域。修复旧隐藏计时任务清除新 HUD 的竞态；此修复尚未运行验收。
- 加入真实竖屏素材及竖屏全屏测试。
- 35297319105 因 GitHub 账号付款失败或支出限额不足无法启动，build 跳过。需要恢复 Actions 额度再验证，禁止将未验收代码称为已修复发行版。

## Release 12 验证通过
本版修正自动全屏方向和局部调节手势。

- 等待实际视频画面尺寸；横屏素材进入横向窗口，竖屏素材保持纵向全屏。
- 左右各约 22% 宽、中央 60% 高的局部区域用于亮度/播放器音量调节，中间区域不用于调节。
- 显示百分比提示，松手后保留 3 秒；修复旧计时器提前清除新提示的问题。

验证：38 项单元测试、12 项 UI 测试通过。实际横屏窗口与竖屏素材测试、左右滑动 HUD、全屏退出后播放均已验证。已人工检查窗口截图，音量提示完整可见。模拟器测试不代替 iPhone 真机验收；音量为应用播放器音量。
Actions：https://github.com/CieloAirone/BiliPai-iOS/actions/runs/35299607091
IPA 内版本为 0.1.0 (10)，Release 序号为 12（此前 Release 10/11 未递增包内版本）。IPA 未签名，需自行签名安装。
SHA256：6f680d2f3fe6f4eb086edab65647d1092b077220831915c182b971da6b82f506
