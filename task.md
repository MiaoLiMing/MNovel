# MNovel 阅读、听书、书源与离线能力任务

## 已完成：阅读错误与书源后端化

- [x] 修复裸 IP HTTPS 证书域名不匹配
- [x] 跨章加载失败时回滚原章节末页并显示友好错误
- [x] 删除没有真实适配器的商业书源占位项
- [x] 为内置来源提供能力说明，为自定义来源提供可点击编辑
- [x] 将三个公开内置来源适配器迁入 unified_backend
- [x] 补齐统一后端 MNovel API 契约、缓存、超时与失败隔离
- [x] 执行 Flutter、后端测试和 Release APK 构建

## 已完成

- [x] 实现按真实视口排版的章内分页
- [x] 实现章末/章首连续跨章
- [x] 实现覆盖、仿真、滑动、无动画四种翻页效果
- [x] 升级阅读进度，保存章内页码和字符偏移
- [x] 接入系统 TTS 和完整听书页面
- [x] 阅读页增加右下角固定听书入口
- [x] 建立离线仓储、下载队列和旧缓存迁移
- [x] 增加离线书库、下载进度和全局已下载标识
- [x] 重构多书源动态聚合、去重、分页和失败隔离
- [x] 修正内置书源的真实能力状态和导入体验
- [x] 补充 Flutter / FastAPI 测试
- [x] 执行 Analyze、Flutter Test、Pytest、Ruff、Web 和 Android 构建
- [x] 更新 walkthrough.md

## 已确认根因

- 阅读器以章节作为 `PageView` 页面，没有章内分页模型。
- 翻页动画枚举未接入不同的渲染效果。
- 内置商业站点只有名称和网址，没有可执行适配器。
- 书城网络失败后固定回退到 8 本静态目录。
- 章节缓存散落在 `SharedPreferences`，下载管理页使用示例数据。

## 保护边界

- 保留 `apps/mobile/pubspec.lock` 当前未提交的镜像地址修改。
- 兼容现有书架、阅读进度、自定义来源和 `offline.chapter.*` 缓存。
- 只聚合公开、授权或用户自行配置的来源，不伪造在线可用性。

## 进行中：书城慢加载与阅读/听书卡死修复（2026-07-27）

- [x] 后端将 Gutenberg / Internet Archive 整本 TXT 切为有界章节
- [x] 后端增加正文缓存、并发请求合并和实际章节数契约
- [x] 后端首页聚合增加总时间预算和 last-good 缓存
- [x] Flutter 书城改为缓存优先、后台刷新和过期请求隔离
- [x] Flutter 阅读器接入动态章节数和超大正文防护
- [x] Flutter 听书增加安全分段、操作超时和播放代次控制
- [x] 补充后端、Flutter 单元与 Widget 回归测试
- [x] 执行 Analyze、Pytest、Flutter Test 和 Android 构建
- [x] 更新 `walkthrough.md`

## 已完成：授权私用站点内置源替换（2026-07-27）

- [x] Flutter 内置源替换为 b520.cc 与 xshuquge.net
- [x] unified_backend 默认聚合源替换为两个授权站点
- [x] 实现首页、搜索、详情、目录、正文和健康检查适配器
- [x] 增加专用 User-Agent、单域限速、超时、缓存与结构断言
- [x] 禁用旧内置源种子并保留自定义源、离线书籍和已有持久化内容
- [x] 为 b520.cc 当前无有效章节链接提供透明降级状态
- [x] 补充最小 HTML 夹具与目录顺序、正文清洗、结构异常测试
- [x] 执行后端测试/Ruff、Flutter Analyze/Test；APK 构建已执行但受机器内存不足阻塞
- [x] 更新 `implementation_plan.md` 与 `walkthrough.md`
