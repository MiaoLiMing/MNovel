# MNovel 任务进度

## 进行中：后端迁移至宝塔 OpenCloudOS 9

- [x] 只读确认 FastAPI、SQLite、客户端 API 地址配置与数据规模
- [x] 确认当前只有服务器公网 IP，且用户接受自用 App 临时通过公网 IP 联调
- [x] 检查到 Android 正式清单缺少 `INTERNET` 权限和指定 IP 的明文放行配置
- [x] 修正宝塔环境目标架构：Nginx HTTPS → 本机回环端口 → Docker FastAPI
- [x] 在 `implementation_plan.md` 记录分阶段迁移、加固、备份和验收方案
- [x] 用户批准迁移计划
- [x] 完成环境变量、安全默认值和 Bearer Token 鉴权
- [x] 完成 Android `INTERNET` 权限和指定 IP 明文白名单
- [x] 完成 Dockerfile、Compose、Nginx、备份脚本和部署 Runbook
- [x] 通过 FastAPI 7 项测试、Ruff、Python 包构建和主应用冒烟测试
- [x] 通过 Flutter analyze、4 项组件测试和 Android Release APK 构建
- [x] 确认服务器规格、OpenCloudOS 版本、公网 IP 与软件安装状态
- [x] 将 Android HTTP 白名单切换为 `114.132.64.216`
- [x] 构建连接 `http://114.132.64.216/api/v1` 的 Release APK
- [ ] 收紧腾讯云安全组：删除 3389，限制宝塔面板端口与 SSH 来源
- [x] 在宝塔安装 Nginx 1.30.3、Docker 28.0.1 与 Docker Compose 2.32.1
- [x] 上传发布包并通过 SHA-256 校验，迁移 SQLite 与正文缓存
- [x] 修正服务器数据权限，生成生产 `.env` 并启动健康容器
- [x] 验证本机健康检查 200、未授权接口 401 与数据权限
- [x] 安装并验证宝塔 Nginx 公网 IP 反向代理
- [x] 验证公网健康检查 200、未授权接口 401、18000 仅监听回环地址
- [x] 验证容器重启持久化与 SQLite 在线备份完整性
- [x] 从 Windows 外网验证健康检查 200 与未授权接口 401
- [x] 配置北京时间每天 03:17 的每日备份任务、互斥锁和日志轮转
- [ ] 在腾讯云控制台确认 8888 与 22 的来源限制
- [ ] 使用真实 IP APK 完成手机端联调
- [ ] 在服务器执行部署并完成公网、重启和恢复验证

## 当前状态

- 项目阶段：核心体验实现与质量验证
- 实施计划：已批准
- 技术栈：Flutter 3.44.6 + FastAPI
- 视觉方向：方案 2（暖白底、鼠尾草绿、克制网格）
- 最后更新：2026-07-15

## 设计阶段

- [x] 底部导航：书架 / 书城 / 分类 / 我的
- [x] 书架与书城顶部频道：小说 / 短剧 / 视频
- [x] 检查用户参考截图
- [x] 生成三套视觉方向并确认方案 2
- [x] 固化基础色彩、字体、间距、圆角与图标风格
- [x] 完成最终跨页面视觉 QA

## 工程阶段

- [x] 初始化 Flutter Android / iOS / Web 工程
- [x] 初始化 FastAPI 服务端与 SQLite 数据层
- [x] 实现书架 / 书城 / 分类 / 我的
- [x] 实现聚合详情、阅读器、目录与换源交互
- [x] 实现短剧 / 视频详情、选集与播放线路交互
- [x] 升级 Flutter 3.44.6、Dart 3.12.2 与 Material 3 API
- [x] 配置 JDK 21、Android API 36、Build-Tools 36 与 Gradle 9.1
- [x] 通过 Flutter analyze、组件测试、Web Release 与 Android APK 构建
- [x] 通过 FastAPI 编译检查与 API 单元测试
- [ ] 接入生产级 Android Media3 与 iOS AVPlayer
- [x] 接通 Project Gutenberg 实时 OPDS、封面代理、正文分段与磁盘缓存
- [ ] 完成下载任务执行器与 WebDAV 实际传输（当前已完成页面与配置入口）
- [x] 完成最终视觉 QA、运行文档和交付总结

## 当前限制

- Windows 无法执行 Xcode/iOS 真机构建，iOS 工程已更新，仍需在 macOS + Xcode 上签名验证。
- 系统级 PATH 仍含 Flutter 3.3.6，因 HKLM 需要管理员权限；项目脚本、VS Code 与 Android 工程均已固定到 3.44.6。

## 已批准并完成：个人中心与阅读器

- [x] 我的：内容源、下载、WebDAV、缓存四个明细页
- [x] 合法公开数据源清单、内置源配置与导入适配器
- [x] 阅读器章节导航栏与底部 TabBar 联动吸附动画
- [x] 目录抽屉向下拖动关闭与当前章节定位
- [x] 左右分页引擎、章节边界与真实翻页动画
- [x] 完整阅读设置面板与本地持久化
- [x] Flutter / FastAPI 自动化测试、构建和视觉 QA
