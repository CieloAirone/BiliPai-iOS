# BiliPai iOS

基于 [jay3-yy/BiliPai](https://github.com/jay3-yy/BiliPai) 的独立 SwiftUI iOS 移植工程，非原作者官方发行版。最低 iOS 17，支持 iPhone / iPad。

**当前为功能移植预览，不是与 Android 功能齐全且完全一致的正式版本。** 页面和核心 API 已开始原生实现，完整状态见 [功能对照](docs/PARITY.md)。

## GitHub Actions 构建

代码推送 main 或在 Actions → Build iOS → Run workflow 手动触发，macOS runner 执行模拟器单元测试并构建 IPA。成功后在 Artifacts 下载 `BiliPai-iOS-unsigned-*`。

IPA **未签名**，需要使用自己的 Apple 签名方式安装。无需将 Apple ID 密码上传到 GitHub。本项目目前未配置证书自动签名。

每天检查上游最新 Release。出现与 `upstream.json` 不同的版本时生成差异报告并重新验证当前 iOS 工程；**不会把 Kotlin 自动翻译成 Swift，也不会自动宣布新增功能已移植**。人工完成适配后更新基线；在此之前每日继续回归构建。

## 本地开发

macOS + Xcode 16.4 + XcodeGen：

```sh
brew install xcodegen
xcodegen generate
open BiliPai.xcodeproj
bash scripts/build-ios.sh test
bash scripts/build-ios.sh archive
```

真实接口可能受 B 站登录状态、账号权限、地区、接口变化与风控影响。测试不使用真实账号凭证。

## 来源与许可

接口路径、WBI 签名逻辑和功能结构参考上游提交 `d9470b11297ea7948e5711491b73f6756c170dfe`。保留原项目 `LICENSE` (GPLv3)。上游 README 同时标注非商业使用，与 LICENSE 文本表述不同；对外分发前应核实上游要求。本仓库公开源码，保留来源，不代表上游背书。
