# MNovel 本地优先架构

## 目标

MNovel 采用单体 Flutter 架构，面向个人使用场景：没有账户、支付、广告、推荐服务或自建 API。App 可以联网直连外部公开源，但全部业务逻辑和用户数据都在设备端。

## 模块边界

- `domain/content.dart`：小说、短剧、影视和章节的统一模型。
- `domain/content_source.dart`：来源描述、来源类型与内置源清单。
- `data/content_repository.dart`：聚合与标准化内容；单个来源失败时回退到本地目录。
- `data/source_store.dart`：持久化来源启停状态和自定义 JSON 来源。
- `data/shelf_store.dart`：本地书架。
- `data/reading_progress_store.dart`：按内容 ID 保存章节和总体进度。
- `features/reader`：原生 Flutter 阅读器，不使用 WebView。

## 来源扩展

内置适配器通过 `SourceKind` 显式注册。新增复杂 HTML、OPDS 或鉴权来源时，应增加独立适配器，不把站点解析规则写进页面。

通用 JSON 来源用于简单扩展：

```json
{
  "items": [
    {
      "id": "book-1",
      "channel": "novel",
      "title": "书名",
      "creator": "作者",
      "category": "分类",
      "summary": "简介",
      "cover": "https://example.com/cover.jpg",
      "popularity": "更新中",
      "progress": 0,
      "unit_count": 100,
      "is_live": true
    }
  ]
}
```

来源配置只保存 URL 和展示信息。需要密钥的来源后续应使用 Keychain / Keystore，不应把密钥写入普通偏好存储。

## 本地存储策略

当前数据量较小，使用 `SharedPreferences` 保存结构化 JSON，便于先完成个人版闭环。当正文缓存、下载任务或书签规模明显增长时，再将这些高容量数据迁移到 SQLite；页面与领域模型无需因此改动。

## 合规与安全

- 仅添加有权访问和使用的内容源。
- 默认只接受 HTTPS 自定义来源，不执行远程脚本，也不放行明文网络请求。
- 不在客户端内置第三方密钥。
- 每个来源独立超时，失败不会阻止本地目录使用。
