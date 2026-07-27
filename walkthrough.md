# MNovel 阅读、听书、书源与离线能力交付说明

## 交付 结论

本轮五项需求均已落地。阅读器现在以章内页面为翻页单位，读完当前章最后一页才进入下一章第一页；四种翻页模式具有独立行为；听书、离线下载和离线书库已形成完整链路；书城不再只依赖固定的 8 本静态目录，而是聚合公开书源和用户配置书源。

## 一、阅读分页与动画

- 使用 `TextPainter` 按实际阅读区域、字体、字号、字距、行高、边距和段首缩进计算分页。
- 阅读进度增加章内页码和字符偏移；字号、方向或窗口尺寸变化后会按字符位置恢复。
- 左右点击、滑动和自动翻页都先翻章内页；章首/章末通过边界页无缝衔接相邻章节。
- 覆盖模式使用前后层位移和阴影，仿真模式使用透视旋转和明暗变化，滑动模式保持标准平移，无动画模式即时切换。

## 二、听书

- 阅读页右下角固定听书入口，进入独立听书页面。
- 基于系统 TTS，支持播放、暂停、停止、上一章、下一章、段落前后跳转。
- 支持语速、音调、音量、系统语音选择和 15/30/60 分钟或本章结束后定时关闭。
- 播放完成可自动续播下一章，并同步当前段落和章节状态。

## 三、离线下载

- 正文文件保存到应用文档目录，元数据由本地索引维护，不再把大段正文长期塞入偏好存储。
- 下载队列最多并发 3 章，支持下载 20 章、50 章、全本或仅补缺失章节，并支持取消和失败重试。
- 兼容迁移旧的 `offline.chapter.*` 缓存。
- 书城、书架、详情、章节目录均显示完整或部分下载标识。
- “我的 > 离线书库”可统一查看、继续阅读、重试、取消和删除已下载小说。

## 四、动态书源

- 已确认旧问题根因：原来的多个商业站点仅保存名称和网址，没有可执行适配器；书城失败时固定回退 8 本静态书目。
- 默认启用 Gutendex、中文维基文库和 Internet Archive 公开来源，支持并发聚合、标准化去重、分页、失败隔离和 7 天目录缓存。
- 中文维基文库会把同一作品的子页面聚合为一本多章节小说。
- 书城刷新会轮换在线页码；发现列表支持滚动加载更多，不再每次展示完全相同的一小组书。
- 书源管理支持批量导入 MNovel JSON/JS 清单。没有适配器或需授权的商业来源明确标记为“需要配置”，不再伪装成可用书源。
- FastAPI 与 Flutter 的静态目录统一标记为“内置试读”，只提供首章，避免误导为完整在线书源。

## 五、验证结果

使用 Flutter 3.44.6 / Dart 3.12 兼容环境完成验证：

```text
apps/mobile: flutter analyze --no-pub          No issues found
apps/mobile: flutter test --no-pub             22 passed
apps/mobile: flutter build web --release       Built build/web
apps/mobile: flutter build apk --debug         Built app-debug.apk
apps/api:    python -m pytest -q                10 passed
apps/api:    ruff check .                       All checks passed
```

真实接口烟雾验证：

- Gutendex 可返回动态分页目录。
- 中文维基文库 `紅樓夢/` 子页查询返回多章节页面并可聚合。
- Internet Archive 高级检索可返回中文馆藏；客户端额外使用中文标题/作者过滤，减少错误语言标注的结果。

Android 调试安装包位于：

`apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`

## 已知说明

- Android 构建成功，但 `flutter_tts` 当前版本仍会触发 Flutter 关于旧式 Kotlin Gradle Plugin 接入方式的未来兼容性警告，不影响本次 APK 构建和当前功能。
- iOS 需要在 macOS/Xcode 环境补做真机语音和后台策略验证；Windows 环境无法执行该项。
- 公开来源的可用性受网络、地区和上游接口策略影响，应用已提供超时、失败隔离、缓存和静态试读兜底。

## 2026-07-25 阅读错误与书源后端化补充

### 阅读页修复

- App 默认接口从会触发证书 IP 不匹配的裸地址改为
  `https://www.flowercat.art/api/v1/mnovel`。
- 没有采用忽略证书或信任所有证书的危险方案。
- 跨章前保留原章节、页码和排版结果。下一章失败时恢复原章节末页，
  显示可读原因并提供重试；初始章节失败页同时提供“切换书源”。
- TLS、超时、断网、404 和无正文会转换为用户提示，不再展示
  `HandshakeException` 等底层堆栈信息。
- 内置静态条目明确限制为一章试读，不再用虚假的几百章目录诱导继续翻章。

### 书源管理

- 删除起点、纵横、番茄、七猫、飞卢、晋江和刺猬猫七个没有真实适配器的商业占位项。
- 内置列表只保留 Project Gutenberg、中文维基文库和 Internet Archive。
- 页面区分“内置公共书源”和“我的书源”；点击内置来源可查看格式、目录、
  正文能力和处理策略，点击自定义来源直接进入编辑配置。
- 内置健康检查调用统一后端探测；用户 JSON/JS 规则仍只保存在设备上。

### unified_backend

`D:\work\project\AP\unified_backend\app\api\v1\mnovel` 已成为生产书源解析入口：

- `sources.py` 定义统一适配器接口并实现三种异构公开来源；
- `services.py` 实现并发聚合、标准化去重、TTL 缓存、缓存上限和单源失败隔离；
- `router.py` 提供首页、发现、搜索、详情、目录、正文和来源健康接口；
- 新增 5 项 MNovel 契约与适配器测试，全仓 27 项后端测试通过。

真实上游验证结果：

```text
project-gutenberg             healthy
zh-wikisource                 healthy
internet-archive-chinese      healthy
一次聚合                       46 本 / 3 个来源
```

### 最终验证

```text
Flutter Analyze               No issues found
Flutter Test                  25 passed
Web Release                   Built build/web
Android Release APK           Built app-release.apk (75.0 MB)
unified_backend MNovel Ruff   All checks passed
unified_backend Pytest        27 passed
www.flowercat.art TLS         verify_result=0, /health=200
```

生产域名当前 `/api/v1/mnovel/home` 仍返回 404，说明服务器尚未部署本次
`unified_backend` 代码。App 在部署前会使用设备端公开来源适配器降级，不会再因
证书错误进入不可恢复页面；部署后会自动改用统一后端作为主解析入口。

## 2026-07-27 书城慢加载与阅读/听书卡死修复

### 根因与修复结果

- 线上实测 Gutenberg 正文曾以一个约 `1.25MB` 的“全文章节”返回，首字节约
  `5.75s`、完整响应约 `9.38s`；Flutter 章节请求只有 8 秒超时，成功返回后又在
  UI isolate 同步排版整本书，因此会在超时、持续转圈和 Android ANR 之间波动。
- `unified_backend` 现在把 Gutenberg 与 Internet Archive 的整本 TXT 按段落和
  句末切成约 24K 字符的有界章节，单段最多 1600 字符；章节响应新增
  `unit_count`，客户端加载首章后即可获得真实总章数。
- 后端正文只下载和切分一次；同一本书的并发请求会合并。正文缓存使用约 2400 万
  字符的总预算，避免无上限占用服务器内存。
- 后端首页对每个公开书源设置 5 秒预算，并保留单源 last-good 缓存；一个来源变慢
  不再拖住全部来源。
- Flutter 书城先显示 7 天内目录缓存，无缓存时立即显示本地试读内容，再在后台刷新；
  每次加载带请求代次，频道快速切换时旧响应不能覆盖新页面。
- Flutter 章节请求改用 20 秒正文超时，并在 JSON 解析/分页前拒绝超过 512KB 或
  12 万字符的异常单章，旧后端也不能再把 UI 主线程拖死。
- 阅读器使用服务端动态总章数，并保留公共书源的跨会话章节进度；目录、进度条和
  听书入口会同步使用更新后的章节数。
- TTS 原始段落会进一步切成最多 120 字的小段；初始化、播放、暂停和停止均有超时
  与播放代次保护，页面关闭时会取消未完成的初始化等待。

### 验证结果

```text
unified_backend: python -m pytest -q       41 passed
unified_backend: MNovel Ruff              All checks passed
apps/mobile: flutter analyze              No issues found
apps/mobile: flutter test                 30 passed
apps/mobile: flutter build apk --debug    Built app-debug.apk
```

新增回归覆盖大文本分章、并发下载合并、实际总章数、超大旧响应拦截、分页安全上限、
书城网络未返回时的缓存/本地首屏，以及 TTS 安全分段。Android Debug APK 位于：

`apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`

### 发布说明

- 当前生产服务器仍运行旧正文契约；必须部署本次 `unified_backend` 改动，线上阅读
  才会从“拦截超大响应并提示重试”升级为“正常读取有界章节”。
- 本次未执行生产部署，也未覆盖 `unified_backend/README.md` 和本文件原有的用户
  未提交修改。
- Android 构建仍提示 `flutter_tts` 旧式 Kotlin Gradle Plugin 的未来兼容警告，
  不影响当前 Debug APK 构建和运行。
