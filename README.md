# CodexTokenWatch

An independently implemented macOS 13+ menu-bar app for inspecting local Codex usage. It reads `~/.codex/sessions` only and never uploads session content or usage data.

一款独立实现的 macOS 13+ 菜单栏应用，用于查看本机 Codex 用量。它只读取 `~/.codex/sessions`，绝不会上传会话内容或用量数据。

## Features

- Five-hour and weekly allowance cards when rate-limit data exists in local logs
  <br>当本地日志中存在速率限制数据时，显示五小时和每周额度卡片
- Green/yellow/red menu-bar status lights based on remaining allowance
  <br>根据剩余额度显示绿、黄、红三色菜单栏状态指示灯
- Today, this week, and all-local token totals
  <br>显示今日、本周及本机累计 Token 总量
- A 14-day activity chart
  <br>提供最近 14 天的用量趋势图
- Uncached input, cached input, and output composition
  <br>展示普通输入、缓存输入和输出 Token 的构成
- A local equivalent-credit estimate
  <br>估算本机累计用量对应的 Credits
- Manual refresh, five-minute background refresh, launch at login, and quit actions
  <br>支持手动刷新、每五分钟后台刷新、登录时启动及退出操作
- Duplicate usage-event detection for copied or forked session history
  <br>能够识别复制或分叉会话历史中的重复用量事件

## Build and run

Build and launch the app:

构建并启动应用：

```sh
swift run CodexTokenWatch
```

To build an optimized binary:

构建经过优化的二进制文件：

```sh
swift build -c release
```

Create a signed `.app` bundle and a compressed DMG:

创建已签名的 `.app` 应用包和压缩 DMG：

```sh
./scripts/build-app.sh
./scripts/build-dmg.sh
```

The default build uses an ad-hoc signature for local testing. Set `CODESIGN_IDENTITY` to a Developer ID Application identity when preparing a notarized public release.

默认构建使用临时签名，适合本地测试。准备经过 Apple 公证的公开版本时，请将 `CODESIGN_IDENTITY` 设置为 Developer ID Application 证书名称。

The scanner uses incremental `last_token_usage` events and rate-limit windows from Codex JSONL logs. Values are estimates: local files may be incomplete and Codex may change its log format. Official Codex usage remains authoritative.

扫描器使用 Codex JSONL 日志中的增量 `last_token_usage` 事件和速率限制窗口。统计结果仅供估算：本地文件可能不完整，Codex 也可能调整日志格式，请以 Codex 官方用量数据为准。

## Privacy

- No network calls
  <br>不发起网络请求
- No API keys
  <br>不需要 API Key
- No log contents leave the Mac
  <br>任何日志内容都不会离开你的 Mac
- Only token counters, timestamps, and rate-limit fields are aggregated in memory
  <br>仅在内存中汇总 Token 计数、时间戳和速率限制字段
