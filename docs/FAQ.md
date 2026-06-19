# IMBoy 常见问题

本文档保留给设置页“帮助文档”入口使用，只放和 IMBoy 直接相关的常见问题，不再堆放零散外链和个人排障笔记。

```agsl
flutter build apk --release \
  --obfuscate \
  --split-debug-info=debugInfo \
  --target-platform=android-arm,android-arm64,android-x64 \
  --split-per-abi \
  -t lib/main.dart --dart-define=APP_ENV=pro

```

```iphone16e leeyi
flutter run \
    --release \
    --device-id 00008140-000E30561E32801C \
    --dart-define=APP_ENV=pro \
    -t lib/main.dart
```


## 使用问题

### 1. 登录失败怎么办？

- 先确认当前环境是否正确，例如 `local_home`、`local_office`、`dev`、`pro`。
- 确认账号、密码、验证码或登录方式与当前环境一致。
- 如果提示 token 失效或登录状态异常，退出后重新登录一次。
- 如果是开发环境，请同时确认后端 API 和 WebSocket 服务可用。

### 2. 收不到消息或消息延迟很高怎么办？

- 先检查网络是否稳定，弱网下消息和 ACK 都可能延迟。
- 确认应用没有被系统挂起，尤其是移动端切到后台较久之后。
- 打开应用后观察 WebSocket 连接状态是否恢复正常。
- 如果消息长时间停留在发送中，可重新进入会话触发状态同步。

### 3. 会话未读数和实际消息不一致怎么办？

- 先返回会话列表，再重新进入对应会话，触发本地状态刷新。
- 如果切换账号、切换设备或异常退出过，建议重新登录一次。
- 开发联调时，优先检查会话表、本地草稿和 ACK 回执是否一致。

### 4. 图片、视频、语音发送失败怎么办？

- 先检查网络和文件大小。
- 确认系统已经授予相册、相机、麦克风权限。
- 大文件上传慢时，优先在稳定网络下重试。
- 如果是开发环境，需同时确认文件上传接口和存储服务正常。

### 5. 推送或消息提醒不生效怎么办？

- 检查系统通知权限是否开启。
- 检查应用内是否开启提醒、会话是否设置了免打扰。
- iOS 设备需要确认系统通知样式、后台刷新和网络权限。
- Android 设备需要确认系统通知渠道没有被手动关闭。

## 隐私与安全

### 6. IMBoy 是否支持端到端加密？

IMBoy 已实现端到端加密相关能力，客户端会处理密钥、分片和消息解密流程。实际效果仍依赖当前环境配置、密钥状态以及消息链路是否完整。

### 7. 聊天记录保存在什么位置？

- 会话和消息会保存在本地数据库中，用于列表展示、搜索和离线恢复。
- 媒体文件会缓存到本地目录，便于重复查看和重试发送。
- 具体表结构和服务实现请以代码为准，不以本 FAQ 作为技术规范。

## 开发排障

### 8. Flutter 项目拉起失败怎么办？

推荐按下面顺序排查：

```bash
flutter clean
flutter pub get
flutter analyze
flutter run --dart-define=APP_ENV=local_home
```

如果是 iOS 依赖问题，再进入 `ios/` 执行 `pod install`。

### 9. 集成测试怎么执行？

IMBoy 当前统一使用 `test_automation/scripts/run_yaml_mapped_suite.sh` 作为 10 条功能线的可恢复执行入口。

常用命令：

```bash
bash test_automation/scripts/run_yaml_mapped_suite.sh --dry-run
bash test_automation/scripts/run_yaml_mapped_suite.sh --run-id yaml_manual_20260301
bash test_automation/scripts/run_yaml_mapped_suite.sh --resume --run-id yaml_manual_20260301
```

执行状态会写入 `test_automation/.state_yaml/<RUN_ID>/`，适合终端被打断后继续跑。

### 10. 反馈问题时应提供什么信息？

建议至少附上以下信息：

- 平台和设备信息
- 应用版本
- 当前环境
- 问题发生时间
- 复现步骤
- 截图或日志

这样更容易区分是 UI 问题、数据问题、接口问题还是 WebSocket 链路问题。
