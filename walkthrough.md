# MNovel 第二版重构交付说明

## 改动概览

本轮接续既有重构，完成小说领域 API、Flutter 页面链路和本地/云端状态协同。后端目录、搜索、筛选、详情、章节、收藏、进度、历史、统计和书源管理形成完整契约；Flutter 端覆盖设计稿中的十个主要视图，并保留离线阅读与自定义书源能力。

移动端原先依赖缺失的 `flutter_js` 包，现改为应用内 `mnovel/js_runner` 平台通道：Android 使用系统 WebView，iOS 使用 WKWebView，Web 继续使用浏览器 JS 引擎。这样不需要第三方包缓存即可保留 JSON/JS 书源解析能力。

收藏和阅读进度先写入本地，再以 best-effort 方式同步 FastAPI；网络失败不会阻塞打开详情、翻章或退出阅读器。

## 验证命令与结果

```text
apps/api: python -m pytest -q                  10 passed
apps/api: python -m ruff check app tests       passed
apps/mobile: flutter test --no-pub             14 passed
apps/mobile: dart analyze                      No issues found
apps/mobile: flutter build web --release       Built build/web
```

`flutter build apk --debug --no-pub` 和直接执行 Gradle 均被本机 socket 资源错误阻塞：`No buffer space available (maximum connections reached?): bind`。检查确认没有残留 Java/Gradle 进程；该限制发生在 Gradle 启动阶段，未进入 Kotlin 源码编译。

## 主要产物

- `apps/api/app/schemas/content.py`
- `apps/api/app/repositories/catalog.py`
- `apps/api/app/api/routes.py`
- `apps/api/tests/test_novel_endpoints.py`
- `apps/mobile/lib/domain/content.dart`
- `apps/mobile/lib/data/content_repository.dart`
- `apps/mobile/lib/core/js_runner_mobile.dart`
- `apps/mobile/android/app/src/main/kotlin/app/mnovel/mnovel/MainActivity.kt`
- `apps/mobile/lib/features/reader/reader_page.dart`
- `apps/mobile/test/content_repository_test.dart`

## 已知后续

在网络与 Gradle socket 资源恢复后，补跑 Android Debug/Release APK 和真机冷启动；在可联网环境补跑真实书源和媒体代理烟雾测试。现有离线契约、Widget 测试与 Web 构建不依赖这些外部条件。
