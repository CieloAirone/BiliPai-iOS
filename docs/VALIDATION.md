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
