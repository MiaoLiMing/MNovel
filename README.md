# MNovel

私人使用、无广告、无自建服务端的 Flutter 内容聚合 App。

## 当前架构

```text
Flutter App
├─ 本地目录（随 App 提供）
├─ 内置公开源适配器（设备端直连）
├─ 用户添加的 JSON 来源（设备端直连）
└─ 设备本地数据
   ├─ 书架
   ├─ 阅读进度
   ├─ 阅读设置
   └─ 来源配置
```

应用入口位于 `apps/mobile`。项目不再包含 FastAPI、Docker、Nginx 或云端数据库。

详细设计见 [本地优先架构](docs/architecture/local-first.md)。

## iPhone 自用安装

项目提供 GitHub Actions 云端 macOS 工作流，可在不发布 App Store、不使用付费开发者账号的情况下生成未签名 IPA，再通过 Windows 上的 Sideloadly 使用免费 Apple ID 安装。

完整步骤见 [Windows 构建与侧载 iOS 版](docs/ios-windows-sideload.md)。
