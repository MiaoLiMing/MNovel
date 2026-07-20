# MNovel Flutter 客户端

MNovel 是一个纯本地架构的小说、短剧与影视聚合 App。它不依赖自建后端：内容源由 Flutter 客户端直接访问，书架、阅读进度、阅读设置和来源配置只保存在设备上。

## 运行

```powershell
cd D:\work\project\AP\MNovel
.\scripts\flutter.ps1 pub get
.\scripts\flutter.ps1 run
```

## 验证

```powershell
.\scripts\verify-mobile.ps1
```

## 数据边界

- `ContentRepository`：聚合启用的设备端来源适配器。
- `SourceStore`：保存内置源启停状态和用户添加的 JSON 来源。
- `ShelfStore`：保存书架。
- `ReadingProgressStore`：保存每本内容的章节进度。
- `ReaderSettingsStore`：保存阅读器外观与交互设置。

自定义 JSON 来源可返回一个数组，或返回含 `items` / `results` 数组的对象。条目字段采用 `ContentItem.toJson()` 的结构。
