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

## 2026-07-27 授权私用站点内置源替换

### 交付结果

- Flutter 默认书源已替换为“书趣阁（授权私用）”和“笔趣阁 b520（授权私用）”；
  原 Project Gutenberg、中文维基文库和 Internet Archive 不再出现在默认源列表及
  来源筛选项。用户自定义源和设备离线书籍不受影响。
- `unified_backend` 默认聚合器、数据库种子同步替换。数据库中已存在的旧内置源只会
  被设为停用，不硬删除其历史小说和章节记录。
- 采用后端在线解析，不把站点规则放进 App，也不整站下载入库。上游请求使用
  `MNovelPrivateTest/1.0` 专用标识、单源串行 350ms 间隔、5 秒聚合预算、15 分钟
  目录缓存和 30 分钟正文缓存。
- `xshuquge.net` 的 HTTP 连接只发生在后端，App 仍连接统一 HTTPS API。已实现首页、
  POST 搜索、详情、目录和正文清洗，并修正“最新章节倒序区 + 正文正序区”导致的
  章节错序。
- `b520.cc` 首页目录可解析，但实站详情页章节链接当前全部是 `/`。适配器会主动抛出
  “当前未提供可解析的章节链接”，源健康状态显示异常，不再让阅读或听书持续转圈。

### 实站与自动化验证

```text
xshuquge.net 首页目录        30 条（单页上限）
xshuquge.net 实测样本目录    1838 章，第一章 → 第一千八百三十七章
xshuquge.net 首章正文        120 个清洗后段落
xshuquge.net 中文搜索        万相之王 / 斗破苍穹 / 剑来均返回结果
b520.cc 首页目录             30 条（单页上限）
b520.cc 健康检查             明确报告章节链接不可解析
unified_backend Ruff         All checks passed
unified_backend Pytest       9 passed
Flutter Analyze             No issues found
Flutter Test                30 passed
```

Android Debug APK 构建已尝试两次，但当前机器仅约 1.8GB 可用物理内存，
`kernel_snapshot_program` 均触发 Out of memory；这是构建环境资源不足，不是编译
错误。代码分析和全部 Flutter 测试已通过，释放内存后可重新执行：

`flutter build apk --debug`

## 2026-07-27 书源检测与书城空状态修复

### 修复结果

- 内置源检测不再把所有异常转换成“章节无法加载”。生产接口返回 404 时明确提示
  “服务器尚未部署此内置源”；后端返回的上游 HTML 结构异常原样展示；超时、连接失败
  和 TLS 失败分别使用对应提示。
- 连续点击检测时使用按书源递增的请求代次，较早返回的旧检测结果不能覆盖新结果。
- 书城启动和在线请求失败后均不再读取 `curatedCatalog` 或最近目录缓存；所有在线来源
  无数据时保持真实空状态。
- 空状态保留顶部频道与搜索入口，支持下拉刷新，并使用统一的克制图标、说明文字和
  “重新加载”按钮。零数据与网络/全源失败使用不同标题和图标。

### 验证结果

```text
Flutter Analyze                         No issues found
Flutter Test                            35 passed
正式 /api/v1/mnovel/health              HTTP 200
正式 xshuquge-authorized 健康接口        HTTP 404（旧后端未部署）
正式 b520-authorized 健康接口            HTTP 404（旧后端未部署）
GitHub Actions run 30249919885           failure: missing server host
```

生产发布未完成且线上未被修改。进一步检查确认现有服务器属于旧式
`/var/www/unified_backend` 单容器部署，新版发布目录和生产环境文件不存在，Compose
声明引用的文件也已缺失，无法确认现有数据库是否持久化。为避免重建容器造成数据丢失，
本轮安全停止生产操作。恢复条件是先备份数据库并补齐生产 Environment secrets 与
`/opt/madmin/.env.production`，或提供现有容器的可验证 Compose/回滚配置。

## 2026-07-30 三站统一规则源、生产发布与移动端验收

### 已交付

- 后端新增通用 JSON 书源规则引擎，HTML 规则使用 BeautifulSoup CSS Selector，JSON 规则使用 `jsonpath-ng`。
- 三个入口统一实现发现/搜索、详情、目录、正文和全链路健康检查：
  - 免费小说之王（MIUI）：完整可用；
  - 书虫中文网：规则存在，当前上游域名不可用；
  - 567中文：规则存在，当前上游域名超时/503。
- Flutter 默认 API 更新为 `https://api.flowercat.art/api/v1/mnovel`，移除旧参数、无效写接口和本地试读兜底。
- 底部导航调整为“书架 / 书城 / 我的”；书城内部提供“推荐 / 分类 / 榜单”。
- 书源页首次进入显示“未检测”，检测后展示真实延迟与正常/异常结果。
- 阅读器与听书页已用生产小说完成可视化验收，不再持续转圈或进入无响应状态。

### 生产发布

正式版本已切换到：

```text
release       /opt/madmin/releases/20260729101600
image tag     20260729101600
backup        /opt/madmin/backups/madmin-20260729T101600Z.dump
```

发布脚本同时修复：

- 管道执行远端脚本时子进程吞掉后续标准输入；
- Windows PowerShell 把 Docker Compose 正常 stderr 当成终止错误；
- 缺少完整远端发布标记仍误报成功；
- 只验证通用健康页、未验证 MNovel 三个规则源；
- 管理端使用构建时同源默认配置时被错误判定为失败。

### 公网真实链路

```text
MIUI 健康检查       healthy，约 2.2 秒，正文 31 段
书虫中文网          error，上游暂时不可用
567中文             error，上游超时/503
书城首页             返回真实 MIUI 小说
搜索“修仙”          返回《修仙狂徒》
详情                 《女总裁的顶级高手》，2508 章
目录                 前三章可读，总数 2508
第一章正文           31 段
```

应用内浏览器进一步完成《修仙狂徒》端到端验证：书城卡片 → 详情 → 阅读正文 → 听书页面，阅读器显示真实正文并识别 4637 章总数。

### 自动化与构建

```text
unified_backend pytest                 53 passed
unified_backend MNovel scoped Ruff     passed
Flutter analyze                        No issues found
Flutter test                           35 passed
Flutter Web release                    Built build/web
Flutter Android release                Built app-release.apk (74.7 MB)
APK SHA-256                            362983D57F44A0C24213873E9F5510A350C5BEC358812B28B831774CE6428471
```

Android Release APK：

`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

视觉验收截图位于 `qa/screenshots/`，详细结论见 `design-qa.md`。

### 当前外部限制

两个 HTML 站点当前域名本身已失效或被重新分配，规则引擎无法从不存在的小说 DOM 中提取正文。应用不会伪造成功，也不会回退到本地目录；站点恢复原小说页面或提供新域名后，只需更新对应 JSON 规则，无需修改 Flutter。
## 2026-07-30 APK 书源提取与兼容集成

### 完成内容

- 从 `D:\work\project\AP\base.apk` 可复现提取 `assets/bookSource.json`：
  - 原始记录 1,142 条；
  - 资源大小 1,939,268 bytes；
  - APK SHA-256：`8d3194c81f07bd1ecb5faf241a8a0a16e70455535443cde11834c3d867429134`；
  - 资源 SHA-256：`f9c9779c6828d3b8f46f8e24d32c09b427bd4e0e3ccd74e9a0b8df8ab035b2ec`。
- 新增 `scripts/extract_book_sources.py`：
  - 解析 `$ref`、生成稳定 ID、保留完整规则；
  - 区分基础兼容、需脚本、需登录、音频、规则不完整和无效引用；
  - 同时生成后端完整规则目录、审计报告和 Flutter 精简元数据资产。
- 最终静态分类：
  - `compatible_core`：925；
  - `script_required`：169；
  - `login_required`：33；
  - `audio`：7；
  - `incomplete`：7；
  - `invalid_reference`：1。
- APK 使用 360 加固，JADX 1.5.5 静态反编译只能看到壳代码；因此按完整规则资产与可观察行为重写兼容层，没有复制 APK 应用代码。
- Flutter“我的 → 书源管理”：
  - 集成 APK 书源目录，并以现有三个主规则源替换同域重复项；
  - 三个主规则源固定置顶，用户自定义源紧随其后，APK 目录作为独立分组；
  - 千级目录使用惰性普通列表，不再为全部记录维护拖拽排序状态；
  - 只缓存成功解析的目录数据，避免复用挂起的异步加载任务；
  - 加载状态改为无持续动画提示，隐藏底部导航页同时暂停 Ticker；
  - 支持名称、域名和原始分组搜索；
  - 支持基础兼容、需脚本、需登录、规则不完整和音频筛选；
  - 展示总数、已启用数和基础兼容数；
  - 不兼容规则不能直接启用，并显示具体原因；
  - 批量检测限制为 4 路并发，聚合搜索最多使用优先级最高的 12 个启用源；
  - 首页“我的”只读取轻量书源计数，千级规则资产延迟到书源管理页加载。
- Flutter 阅读链路已经接入 Legacy 后端接口：
  - 搜索；
  - 详情/目录；
  - 章节正文；
  - 健康检测。
- 旧开发后端 `apps/api` 与实际生产后端 `unified_backend` 均补充规则目录及安全执行接口；生产部署资产位于 `app/api/v1/mnovel/legacy`，会随 Docker 镜像复制。
- 安全边界包括逐次 DNS/IP 校验、私网拦截、重定向复核、请求超时、2 MB 响应上限、规则兼容分级和默认关闭。

### 验证结果

- APK 提取脚本：成功生成 1,142 条记录，分类总数一致。
- `MNovel/apps/api`：
  - Ruff：通过；
  - Pytest：13 passed。
- `unified_backend`：
  - 本次改动文件 Ruff：通过；
  - 全量 Pytest：57 passed，4 个既有依赖弃用警告；
  - 全仓 Ruff 仍有 80 个既有历史问题，本次改动文件没有新增错误。
- Flutter：
  - Analyze：通过，0 issues；
  - 全量测试：38 passed；
  - 新增千级目录加载收敛回归测试，并修复主导航、书源管理和自定义书源编辑测试；
  - Web release：构建成功；
  - Android release APK：构建成功，78,273,557 bytes；
  - APK SHA-256：`693EE61B0F56EFE3CAB6C72DE2A58AEFB7EB2C89AC8A62FA3B033BD0860B3B12`。

### 构建产物

- Android：`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`
- Web：`apps/mobile/build/web`
- APK 书源审计：`data/book_sources/audit.md`
- 完整转换目录：`data/book_sources/legacy_sources.json`
- Flutter 精简目录：`apps/mobile/assets/book_sources/legacy_sources.json`
