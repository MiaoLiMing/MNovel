# 在 Windows 上构建并安装 MNovel iOS 版

本方案不发布 App Store，也不需要付费 Apple Developer 会员：GitHub Actions 使用云端 macOS 编译未签名 IPA，Windows 使用 Sideloadly 和免费 Apple ID 临时签名并安装到自己的 iPhone。

当前 Flutter 版本支持 iOS 13 及以上版本，目标 iPhone 需要运行 iOS 13 或更新系统。

> 免费 Apple Personal Team 签名有效期为 7 天。到期前需要刷新，无法获得永久有效的免费签名。

## 一、生成未签名 IPA

1. 将当前项目推送到 GitHub。建议使用私有仓库。
2. 打开仓库的 **Actions** 页面。
3. 在左侧选择 **Build unsigned iOS IPA**。
4. 点击 **Run workflow**。
5. 保持默认版本号，点击绿色的 **Run workflow**。
6. 等待 Analyze、Test、Build 和 Package 全部通过。
7. 打开该次运行，在 **Artifacts** 下载 `MNovel-unsigned-ios-数字`。
8. 解压 Artifact，得到：
   - `MNovel-unsigned.ipa`
   - `MNovel-unsigned.ipa.sha256`

这个 IPA 尚未签名，不能直接点击安装，也不包含 Apple ID、证书或其他签名秘密。

## 二、在 Windows 安装

1. 从 [Sideloadly 官网](https://sideloadly.io/) 下载 Windows 版本。
2. 按 Sideloadly 的说明安装 Apple 官网版本的 iTunes 和 iCloud。不要使用来源不明的修改版。
3. 建议注册一个单独的 Apple ID 专门用于自用侧载，不要使用保存支付资料和重要数据的主账号。
4. 使用数据线连接 iPhone，在手机上选择“信任此电脑”。
5. 打开 Sideloadly，把 `MNovel-unsigned.ipa` 拖入窗口。
6. 选择已连接的 iPhone，输入侧载用 Apple ID，开始安装。
7. 安装成功后，在 iPhone 中开启：

   ```text
   设置 → 隐私与安全性 → 开发者模式
   ```

8. 若系统要求信任开发者，再检查：

   ```text
   设置 → 通用 → VPN 与设备管理
   ```

不要把 Apple ID 密码、验证码或会话 Cookie 上传到 GitHub，也不要把它们写入 Actions Secrets。本工作流完全不需要 Apple 凭据。

## 三、每 7 天刷新

- 免费签名的 Provisioning Profile 在 7 天后失效。
- 可以启用 Sideloadly 的自动刷新，让 Windows 电脑和 iPhone 保持在同一局域网。
- 自动刷新失败时，用同一个 Apple ID、同一个 IPA 和相同 Bundle ID 重新安装。
- 覆盖安装通常会保留本地数据，但重要书架和来源配置仍建议单独备份。

## 四、更新 App

代码更新后：

1. 将修改推送到 GitHub。
2. 再次运行 **Build unsigned iOS IPA**。
3. 下载新的 IPA。
4. 使用相同 Apple ID 和 Bundle ID 在 Sideloadly 中覆盖安装。

构建号必须是正整数；同一次本地侧载通常可以继续使用默认值，排查缓存问题时可递增构建号。

## 常见问题

### Actions 中找不到 Run workflow

工作流文件必须已存在于 GitHub 默认分支，并且仓库已启用 Actions。

### iPhone 显示完整性无法验证

确认手机能访问互联网、签名没有超过 7 天，并重新通过 Sideloadly 安装。不要使用网上共享的企业证书。

### 构建成功但 IPA 无法直接安装

这是预期行为。GitHub 生成的是未签名 IPA，必须先由 Sideloadly 使用你的免费 Apple ID 重新签名。

### App 七天后打不开

这是 Apple 免费 Personal Team 的限制，不是 MNovel 故障。连接 Sideloadly 刷新或重新安装即可。
