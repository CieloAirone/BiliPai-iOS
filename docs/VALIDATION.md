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
