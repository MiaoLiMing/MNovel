# MNovel

私人使用、无广告的 Flutter 内容聚合 App。

## 当前架构

```text
Flutter App
├─ 本地目录（随 App 提供）
├─ MNovel API（影视元数据、网页线路解析）
├─ 影视 CDN（优先设备端直连，失败时按需走云端代理）
├─ 用户添加的 JSON 来源（设备端直连）
└─ 设备本地数据
   ├─ 书架
   ├─ 阅读进度
   ├─ 阅读设置
   └─ 来源配置
```

Flutter 应用位于 `apps/mobile`，FastAPI 服务位于 `apps/api`。影视采用智能混合播放，云端代理是失败兜底，不会让所有视频流量固定经过服务器。

详细设计见 [本地优先架构](docs/architecture/local-first.md)。

## iPhone 自用安装

项目提供 GitHub Actions 云端 macOS 工作流，可在不发布 App Store、不使用付费开发者账号的情况下生成未签名 IPA，再通过 Windows 上的 Sideloadly 使用免费 Apple ID 安装。

完整步骤见 [Windows 构建与侧载 iOS 版](docs/ios-windows-sideload.md)。
