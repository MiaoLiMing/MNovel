# MNovel 阶段验证记录

## 后端云迁移：项目端准备（2026-07-16）

### 已完成

- FastAPI 的数据库路径、CORS 来源和访问令牌改为 `MNOVEL_*` 环境变量。
- 收藏、进度、播放线路与内容源管理接口增加 Bearer Token；未配置令牌时安全关闭。
- 新增非 root、单 worker 的生产 Dockerfile，以及只监听 `127.0.0.1:18000` 的 Compose 配置。
- 新增宝塔 Nginx IP 站点示例、SQLite 在线备份、日志轮转、告警和恢复 Runbook。
- Android 正式清单增加联网权限，明文 HTTP 仅允许网络安全配置中列出的地址。

### 验证结果

- `py -3.13 -m pytest -q`：7 项通过。
- `py -3.13 -m ruff check app tests`：通过。
- Python wheel 构建：通过。
- 主应用冒烟测试：健康检查 200、无令牌访问受保护接口 401、有效令牌访问 200。
- `flutter analyze`：通过。
- `flutter test`：4 项通过。
- Android Release APK：构建成功，使用 `192.0.2.1` 占位 IP，仅用于验证构建链路。

### 尚待服务器验证

- 已确认服务器为 OpenCloudOS 9.6、x86_64、3.6 GiB 内存、40 GB 磁盘，资源满足要求。
- 服务器尚未安装 Docker/Nginx，因此镜像构建、Compose 启动和 Nginx 配置测试必须在服务器完成。
- Android 网络安全配置已切换为真实公网 IP `114.132.64.216`。
- 已重新构建真实 IP 联调 APK（SHA-256：`B39E01624140D88FD3BAC1E62A0AD6D4B20C0C86300E2A8EF801ECC92600488D`）。
- 服务器上线后仍需验证公网访问、容器/服务器重启、备份恢复和日志轮转。
- 发布包已在服务器通过 SHA-256 校验并解压，SQLite 与正文缓存已迁移；启动前需将 Windows 包带来的宽松权限收紧。
- FastAPI 容器已持续运行 18 小时并保持 `healthy`，本机健康检查返回 200，未授权内容源接口返回 401，数据权限已收紧为目录 750、文件 640。
- 宝塔 Nginx 已成功监听 IPv4/IPv6 的 80 端口并转发到回环地址；公网 IP 健康检查返回 200，公网未授权接口返回 401，容器端口未直接暴露。
- 通过专用 SSH 密钥完成服务器自动验收：带令牌接口 200，容器重启后临时进度记录仍存在且已清理，证明 SQLite 挂载持久化有效。
- 已生成 `mnovel-20260717T064101Z.db` 在线备份；`PRAGMA integrity_check` 为 `ok`，`favorites`、`progress`、`sources` 表齐全，文件权限为 640。
- Windows 外网复测健康检查 200、未授权接口 401，排除仅服务器 NAT 回环可访问的假阳性。
- 已配置 `/etc/cron.d/mnovel-backup`：北京时间每天 03:17 执行 SQLite 在线备份，使用 `flock` 防重入；日志每周轮转并保留 4 期。

## 本次交付结果

- 书城与分类改为直接请求 FastAPI 聚合目录，不再在断网或空结果时回退静态 Mock。
- 生产目录 `lib/` 已完全移除 `DemoRepository`；演示章节仅保留在 `test/fixtures/` 作为自动化测试夹具。
- 书架只展示用户真实收藏，并通过 `SharedPreferences` 本地持久化。
- 小说频道已接通 Project Gutenberg 官方 OPDS：实时书目、真实封面、详情、章节与正文。
- Project Gutenberg 封面经后端同源代理，正文按阅读段落分段并写入本地磁盘缓存。
- 短剧与视频频道只展示真实可用结果；公开源不可达或 TMDB / Pexels 未配置密钥时显示明确空态。
- 我的页面四个内容与存储入口均可进入明细。
- 阅读器已完成联动底栏、目录下滑关闭、左右分页、章节边界、仿真效果和完整设置持久化。
- 修复仿真模式首次挂载把当前页错误旋转产生黑边的问题。

## SDK 升级

- Flutter 官方发布清单确认并安装 3.44.6 stable。
- 官方压缩包 SHA-256 校验通过。
- Dart 3.12.2、DevTools 2.57.0 可用。
- Microsoft OpenJDK 21.0.11 LTS 官方 MSI SHA-256 校验通过。
- Android API 36、Build-Tools 28.0.3 / 36.0.0、Platform-Tools 与 CMake 3.22.1 已安装。
- Gradle 9.1.0 分发包按官方 SHA-256 校验通过。

## 项目迁移

- Dart SDK 约束升级为 `>=3.12.0 <4.0.0`。
- Android、iOS、Web 原生模板刷新到 Flutter 3.44.6。
- 清除旧 Groovy Gradle 文件，统一使用 Kotlin DSL。
- Material 2 旧文本 API 全部迁移到 Material 3。

## 已通过验证

- `flutter analyze`：0 问题。
- Flutter 组件测试：4 项全部通过。
- Web Release：构建成功。
- Android Debug APK：构建成功。
- `flutter doctor`：Android toolchain（SDK 36.0.0）通过。
- FastAPI 编译检查：通过。
- FastAPI API 单元测试：5 项通过。
- Ruff：全部通过。
- 390 × 844 移动端视觉 QA：通过；书城、真实正文、联动控制栏和阅读设置均已留存截图。

## 待验证

- macOS + Xcode 下的 iOS 编译、签名与真机运行。
- iPhone SE、iPhone Pro Max 与 Android 平板的补充多尺寸回归。
- Windows 桌面构建未纳入产品范围，因此未安装 Visual Studio C++ 工具链。
- 当前网络无法访问 GitHub；Flutter 与 Android 构建已通过国内镜像和本地校验缓存完成验证。
