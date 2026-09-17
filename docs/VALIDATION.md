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
