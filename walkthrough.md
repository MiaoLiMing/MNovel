# 视频模块修复说明

## 结果概览

本次修复已经打通影视模块的完整真实数据链路：

`CMS 来源 → 详情列表 → 影视详情 → 播放线路/剧集 → 原生 HLS 播放器`

三个指定苹果 CMS 源不再被当作普通轻量 JSON 列表使用。列表可以取得封面和分类，详情页会按视频 ID 刷新完整数据，播放器会优先选择可直接播放的 HLS/MP4 线路。

## 主要改动

### 1. 苹果 CMS 适配器

新增 `apps/mobile/lib/data/cms_video_adapter.dart`，集中负责：

- 识别 `/provide/vod` 苹果 CMS 接口；
- 构造 `ac=detail&pg=...` 列表/搜索请求；
- 构造 `ac=detail&ids=...` 单条详情请求；
- 保留源地址已有查询参数；
- 映射封面、分类、主创、简介和备注；
- 清理简介 HTML；
- 解析 `vod_play_from` 与 `vod_play_url`；
- 识别并优先选择 HLS/MP4 直连线路。

### 2. 强类型影视线路与剧集

在 `ContentItem` 中新增 `MediaPlaylist` 和 `MediaEpisode`：

- 保存线路名称、真实集名和真实播放 URL；
- 支持完整序列化，收藏后仍可恢复线路信息；
- 保留原有小说 `chapterUrls`，没有破坏小说阅读链路。

### 3. 列表与搜索

`ContentRepository` 对 CMS 来源自动请求详情列表，不再原样请求缺少 `vod_pic`、`vod_content`、`vod_play_url` 的裸地址。

搜索关键词会作为 `wd` 传给 CMS，同时保留客户端过滤，通用 JSON/JS 来源继续走原有处理逻辑。

### 4. 详情页

详情页进入后会通过 `sourceId + vodId` 获取完整详情，并提供：

- 加载进度；
- 失败信息；
- 重试入口；
- 完整对象替换；
- 使用刷新后对象进行收藏和播放。

没有播放地址时会明确提示，不再进入演示视频。

### 5. 播放器

播放器移除了真实条目的硬编码演示视频回退，新增：

- HLS 格式提示和移动端 User-Agent；
- 控制器在 `build` 外初始化和释放；
- 加载、缓冲、播放和错误状态；
- 重试与下一线路；
- 真实线路面板；
- 真实选集和集名；
- 切集/切线后重新初始化；
- 实时时间和进度条。

红果源会默认选择 `hhm3u8`，不会再把返回 `text/html` 的 `hhyun` 网页线路交给原生播放器。

### 6. 图片与来源表单

- 封面请求保留移动端 User-Agent，移除了空 Referer。
- 实机测试发现来源表单关闭时控制器释放过早，已改为页面下一帧释放，消除了 Flutter `dependents.isEmpty` 运行时断言。

## 自动化验证

- `flutter analyze --no-pub`：通过，无问题。
- `flutter test --no-pub`：15 项全部通过。
- 新增测试覆盖：
  - CMS URL 参数合并；
  - 多线路和剧集分隔规则；
  - HLS 默认线路优选；
  - CMS 字段映射与 HTML 清理；
  - 线路序列化/恢复；
  - 列表与详情仓库请求；
  - 详情页轻量对象替换。
- `flutter build apk --debug --no-pub`：通过。
- APK：`apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`。

构建仅报告现有 `flutter_js` 插件尚未迁移到 Flutter 未来的 Built-in Kotlin 模式；这不是当前构建失败，也与视频修复无关。

## 真实源验证

### 红果

- 详情列表返回真实封面、分类和主创；
- Android 17 模拟器列表封面正常显示；
- 详情页显示真实封面、简介和 34 集；
- 线路面板同时显示：
  - `hhyun`：网页/解析线路；
  - `hhm3u8`：直连媒体；
- 默认选中 `hhm3u8`；
- HLS 返回 `200 application/vnd.apple.mpegurl`；
- 播放时间从 `00:06` 前进到 `00:59`；
- 切换到“外传”后重新加载并播放到 `00:08 / 07:46`。

### 暴风

- 详情返回非空封面、简介和 `bfzym3u8` 剧集；
- HLS 返回 `200 application/vnd.apple.mpegurl`；
- 封面服务器拒绝 HEAD，但实际 GET 返回 `200 image/webp`，Flutter 图片加载可用。

### 无尽

- 详情返回非空封面、简介和 `wjm3u8` 剧集；
- HLS 返回 `200 application/vnd.apple.mpegurl`；
- 封面返回 `200 image/jpeg`。

## 未改动边界

- 初版修复没有引入后端；2026-07-22 起升级为智能混合架构，仍优先设备端直连，云端只负责元数据、网页解析和失败代理。
- 没有回退现有 JSON/JS 来源相关未提交修改。
- 没有修改小说阅读模型和阅读器行为。

## APK 启动闪退修复

- 问题产物 `app-debug.apk` 在执行 x86_64 模拟器调试后被覆盖，包内插件库虽包含 ARM 架构，但 `libflutter.so` 只有 `x86_64`；ARM 真机可安装但启动时会因缺少对应 Flutter 引擎而退出。
- 已重新构建 `app-release.apk`，其 `arm64-v8a`、`armeabi-v7a`、`x86_64` 目录均完整包含 `libapp.so`、`libflutter.so` 和 QuickJS 原生库。
- Release APK 已在 Android 17 模拟器覆盖安装，并在不连接 Flutter 调试器的情况下冷启动；12 秒后进程保持存活，日志无 `FATAL EXCEPTION`、ANR 或 `E/flutter`。
- Release APK SHA-256：`269E7AE42AA4FE0C775D9194F128E96B83C22EA3274A3B00BCB7A0BC5E0F8081`。

## 云端智能混合播放收口（2026-07-22）

- Flutter 影视列表、搜索、详情和播放解析统一请求 `http://114.132.64.216/api/v1/mnovel`。
- 播放器使用 libmpv `auto-safe`，允许硬解失败后回退软件解码；CDN 直连 20 秒无播放进度或发生错误时自动切换云端代理。
- 网页线路不再禁用，交由云端提取真实 HLS/MP4；线路文案改为“CDN 直连，失败自动转云端代理”与“云端解析线路”。
- FastAPI 增加播放页解析、HLS 清单/子清单/AES Key 重写、Range 转发和连接池复用，默认前缀统一为 `/api/v1/mnovel`。
- 真实烟雾验证：`hhyun` 网页线路成功解析为 `https://play.hhuus.com/play/b68B4rLe/index.m3u8`，媒体与本地代理均返回 `200 application/vnd.apple.mpegurl`。
- 验证结果：Flutter Analyze 通过，19 项 Flutter 测试通过；后端 Ruff 通过，7 项 Pytest 通过；Release APK 构建成功。
- 新 APK：`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`，大小 113,371,795 字节，SHA-256 为 `5E27E11331589E4989EDFAF1E6C8E6053F951BB73A5D4D8FDB7A893501290ACD`。
- APK 同时包含 `arm64-v8a`、`armeabi-v7a`、`x86_64` 的 `libapp.so`、`libflutter.so` 和 `libmpv.so`。
- 公网服务器截至本次验证仍未部署新增影视路由；部署 `apps/api` 前，APK 会退回 CDN 直连，无法使用云端解析/代理兜底。
