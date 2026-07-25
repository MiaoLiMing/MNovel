# MNovel 第二版重构任务

## 已完成

- [x] 统一小说领域模型、来源模型、章节模型和媒体线路模型
- [x] 完成 FastAPI 小说首页、分类、筛选、搜索、详情、章节接口
- [x] 完成收藏、阅读进度、历史、统计和书源 CRUD 接口
- [x] Flutter 完成四栏导航和书架、书城、分类、搜索、详情页面
- [x] Flutter 完成阅读器、章节目录、阅读设置、书源管理和我的页面
- [x] 完成加载、空态、错误、重试、选中和持久化状态
- [x] 自定义 JSON/JS 书源保留；移动端 JS 改用系统 WebView 平台通道
- [x] 收藏与阅读进度本地即时保存，并异步同步 FastAPI
- [x] 补充后端小说契约测试、代理 mock 测试和 Flutter Widget 测试
- [x] 更新设计 QA 和交付 walkthrough

## 验证状态

- [x] Python Pytest：10 passed
- [x] Python Ruff：通过（项目配置限定 E4/E7/E9/F/I）
- [x] Flutter Widget Test：14 passed
- [x] Dart Analyze：无问题
- [x] Flutter Web release：构建成功
- [ ] Android Debug APK：被本机 Gradle `No buffer space available` 阻塞，未进入源码编译

## 保护边界

- 不回退已有本地书架、阅读进度、缓存、备份恢复和自定义书源能力。
- 网络失败时保留本地状态，前端展示可阅读的缓存或明确错误/重试入口。
- 不伪造公网来源成功结果；代理与视频测试使用受控 mock，真实网络验证需在可联网环境执行。
