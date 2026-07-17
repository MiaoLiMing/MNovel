# MNovel SDK 基线

## 固定版本

- Flutter：3.44.6 stable
- Dart：3.12.2
- Java：Microsoft OpenJDK 21.0.11 LTS
- Android Platform：API 36
- Android Build-Tools：36.0.0（同时保留 Flutter doctor 需要的 28.0.3）
- Gradle：9.1.0

项目根目录的 `.flutter-version`、VS Code 设置、Android `local.properties` 和 `scripts/flutter.ps1` 均指向此基线。

## 日常命令

```powershell
cd D:\work\project\AP\MNovel
.\scripts\flutter.ps1 doctor -v
.\scripts\verify-mobile.ps1
```

项目脚本会显式选择新版 SDK，不受系统级旧 PATH 影响。

`flutter doctor` 中 Android toolchain 已通过。Visual Studio 缺失只影响 Windows 桌面应用，不影响本项目的 Android、iOS 与 Web 目标；GitHub 网络检查失败是当前网络可达性问题，不影响已验证的本地构建链。

## 系统级旧 PATH

当前系统级 PATH 仍包含 Flutter 3.3.6。由于修改 HKLM 需要管理员权限，自动更新只完成了用户级 PATH。若希望所有新终端直接执行 `flutter` 时也统一使用新版，请在管理员 PowerShell 中运行：

```powershell
$old = 'D:\work\software\flutterFiles\flutter_windows_3.3.6-stable\flutter\bin'
$new = 'D:\work\software\flutterFiles\flutter_windows_3.44.6-stable\flutter\bin'
$path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$parts = $path -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $old.TrimEnd('\') }
[Environment]::SetEnvironmentVariable('Path', (@($new) + $parts | Select-Object -Unique) -join ';', 'Machine')
```

执行后重启终端和 IDE，再运行 `flutter --version`。
