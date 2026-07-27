# MNovel

私人使用、无广告的 Flutter 内容聚合App。

## 当前架构

```text
Flutter App
├─ Unified Backend MNovel API
│  ├─ Gutendex / Project Gutenberg 适配器
│  ├─ 中文维基文库适配器
│  └─ Internet Archive 适配器
├─ 内置试读目录（网络失败兜底）
├─ 用户添加的 JSON / JS 来源（设备端直连，不上传规则）
└─ 设备本地数据
   ├─ 书架
   ├─ 阅读进度
   ├─ 阅读设置
   ├─ 来源配置
   └─ 离线正文
```

Flutter 应用位于 `apps/mobile`。生产小说聚合服务位于
`D:\work\project\AP\unified_backend\app\api\v1\mnovel`，默认接口为
`https://www.flowercat.art/api/v1/mnovel`。`apps/api` 保留为旧版独立开发服务，
不再作为 App 的生产书源解析入口。

构建时可以覆盖后端地址：

```powershell
flutter build apk --dart-define=MNOVEL_API_URL=https://example.com/api/v1/mnovel
```

详细设计见 [本地优先架构](docs/architecture/local-first.md)。

## iPhone 自用安装

项目提供 GitHub Actions 云端 macOS 工作流，可在不发布 App Store、不使用付费开发者账号的情况下生成未签名 IPA，再通过 Windows 上的 Sideloadly 使用免费 Apple ID 安装。

完整步骤见 [Windows 构建与侧载 iOS 版](docs/ios-windows-sideload.md)。
