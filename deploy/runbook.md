# MNovel 宝塔部署 Runbook

## 服务概览

```text
自用 App → 公网 IP:80 → 宝塔 Nginx → 127.0.0.1:18000
                                      → Docker: FastAPI 单 worker
                                      → /opt/mnovel/data/mnovel.db
```

- FastAPI 容器端口不直接暴露公网。
- 公网 IP 阶段使用 HTTP，仅作自用过渡；不要复用任何高价值密码作为访问令牌。
- 域名到位后切换 HTTPS，并删除 Android 明文网络例外。

## 服务器准备

服务器基线已于 2026-07-16 确认：OpenCloudOS 9.6、x86_64、3.6 GiB 内存、1 GiB Swap、40 GB 系统盘（剩余 35 GB），公网 IP 为 `114.132.64.216`。

复查命令：

```bash
uname -m
cat /etc/opencloudos-release
free -h
df -h /
docker --version
docker compose version
/www/server/nginx/sbin/nginx -v
```

目标目录：

```bash
sudo install -d -m 0755 /opt/mnovel/app
sudo install -d -o 10001 -g 10001 -m 0750 /opt/mnovel/data /opt/mnovel/backup
```

宝塔和云厂商安全组仅开放：

| 端口 | 用途 | 来源 |
|---|---|---|
| 22/TCP | SSH | 尽量限制为自己的 IP |
| 80/TCP | 临时 API HTTP | 公网，自用阶段 |
| 443/TCP | 后续 HTTPS | 域名上线后开放 |
| 宝塔面板端口 | 面板管理 | 仅自己的 IP |

不要开放 8000、18000、数据库端口。

## 首次发布

将项目放到 `/opt/mnovel/app` 后：

```bash
cd /opt/mnovel/app/deploy
cp .env.example .env
chmod 600 .env
openssl rand -hex 32
```

把最后一条命令生成的值写入 `.env` 的 `MNOVEL_ACCESS_TOKEN`，不要发送或提交该文件。

迁移现有数据前先停止本地写入，将 `apps/api/data/` 内容上传到服务器的 `/opt/mnovel/data/`，然后：

```bash
sudo chown -R 10001:10001 /opt/mnovel/data /opt/mnovel/backup
find /opt/mnovel/data /opt/mnovel/backup -type d -exec chmod 0750 {} +
find /opt/mnovel/data /opt/mnovel/backup -type f -exec chmod 0640 {} +
docker compose config --quiet
docker compose up -d --build
docker compose ps
curl --fail http://127.0.0.1:18000/api/v1/health
```

## 宝塔 Nginx

1. 在 Nginx 主配置的 `http {}` 中增加：

```nginx
limit_req_zone $binary_remote_addr zone=mnovel_api:10m rate=10r/s;
```

2. 按 `deploy/nginx/mnovel-ip.conf` 创建 IP 站点或合并到宝塔生成的站点配置。
3. 在宝塔中测试 Nginx 配置后再重载。
4. 公网验证：`http://114.132.64.216/api/v1/health`。

## Android IP 构建

Android 网络安全配置当前只对白名单地址 `114.132.64.216` 放行明文 HTTP：

```text
apps/mobile/android/app/src/main/res/xml/network_security_config.xml
```

构建：

```powershell
.\scripts\flutter.ps1 build apk --release --dart-define=API_BASE_URL=http://114.132.64.216/api/v1
```

## 日常操作

```bash
cd /opt/mnovel/app/deploy
docker compose ps
docker compose logs --tail=200 api
docker compose restart api
docker compose up -d --build
bash scripts/backup-sqlite.sh
```

服务器已配置 `/etc/cron.d/mnovel-backup`，按北京时间每天 03:17 执行：

```cron
17 3 * * * root /usr/bin/flock -n /run/mnovel-backup.lock /usr/bin/bash /opt/mnovel/app/deploy/scripts/backup-sqlite.sh >> /var/log/mnovel-backup.log 2>&1
```

备份日志由 `/etc/logrotate.d/mnovel-backup` 每周轮转，保留 4 期。

检查受保护接口：

```bash
curl -H "Authorization: Bearer $MNOVEL_ACCESS_TOKEN" \
  http://127.0.0.1:18000/api/v1/sources
```

不要把真实令牌直接写入 shell 历史；上面的环境变量应在当前终端临时、安全地设置。

## 告警建议

| 级别 | 条件 | 处理 |
|---|---|---|
| P1 | 健康检查连续 3 次失败 | 检查容器、Nginx、磁盘，必要时回滚 |
| P1 | 根分区使用率超过 90% | 清理异常日志，检查备份与 Docker 占用 |
| P2 | 根分区使用率超过 80% | 提前扩容或清理 |
| P2 | 5xx 比例连续 5 分钟超过 5% | 检查上游内容源和应用日志 |
| P2 | 备份连续 2 天未生成 | 手工执行备份并检查计划任务 |

## 故障处置与恢复

```bash
cd /opt/mnovel/app/deploy
docker compose ps
docker compose logs --tail=200 api
curl -v http://127.0.0.1:18000/api/v1/health
nginx -t
df -h /
```

恢复数据库前停止容器并保留当前文件：

```bash
cd /opt/mnovel/app/deploy
docker compose stop api
cp /opt/mnovel/data/mnovel.db /opt/mnovel/backup/mnovel-before-restore.db
cp /opt/mnovel/backup/要恢复的备份.db /opt/mnovel/data/mnovel.db
chown 10001:10001 /opt/mnovel/data/mnovel.db
docker compose start api
curl --fail http://127.0.0.1:18000/api/v1/health
```

恢复后验证健康检查、内容源、收藏和阅读进度；验证失败则立即停服务并还原 `mnovel-before-restore.db`。
