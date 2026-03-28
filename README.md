# macOS 状态栏网速监控

一个基于 Swift + AppKit 的轻量状态栏工具，每秒刷新一次实时网速。

## 功能

- 在 macOS 状态栏显示 `↑上传速度 / ↓下载速度`
- 自动统计所有已启用且非回环网卡流量
- 点击状态栏可看到菜单并退出程序

## 运行

```bash
swift run
```

首次运行后，顶部状态栏会出现类似 `↑12KB/s ↓1.2MB/s` 的实时速度显示。

## 构建

```bash
swift build
```

## 打包 DMG

先准备签名和公证环境变量：

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export TEAM_ID="YOUR_TEAM_ID"

# 二选一：
# 1) 推荐：使用 notarytool keychain profile
export NOTARYTOOL_PROFILE="AC_NOTARY_PROFILE"

# 2) 或使用 Apple ID + app 专用密码
# export APPLE_ID="your_apple_id@example.com"
# export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

你可以按需执行 `swift build`、`codesign`、`notarytool`、`stapler` 完成发布。

生成文件：
- `dist/NetworkMonitorMenuBar-1.0.2.dmg`

DMG 内包含：
- `NetworkMonitorMenuBar.app`
- `Applications` 快捷方式（可直接拖拽安装）
