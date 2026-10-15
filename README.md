# IMBoy App

IMBoy 的 Flutter 客户端，支持 iOS、Android 和桌面端。一期交付能力：单聊、群聊、联系人、频道、朋友圈、收藏与通知。音视频通话（RTC）、直播（live_room）、Bot、AI 助手与端到端加密（E2EE）为二期保留能力，交付版默认关闭，开发态状态详见 [功能状态](./docs/reference/feature-status.md)。

首页只有两种模式：`personal`（个人）和 `workspace`（企业）。新登录或未选择企业时进入个人模式；从企业选择器明确选择企业后进入企业模式（消息 / 通讯录 / 工作台 / 我的）。模式偏好按账号保存在本机，服务端部署默认值不会代替用户选择企业。旧版“群聊 / 概览 / 频道 / 群组 / 项目”独立首页已移除。

## 本地启动

### 1. 准备环境

- Flutter 3.47.5 或更新的 stable（CI 固定 3.47.5 / Dart 3.13.4；项目 Dart SDK 约束 `^3.13.3`）
- 一台已连接电脑的真机
- 可访问的 IMBoy 后端

先检查环境和设备：

```bash
flutter doctor
flutter devices
```

项目规定功能调试使用真机，不用模拟器做验证。

### 2. 安装依赖

```bash
git submodule update --init --recursive
python3 scripts/check_sdk_compatibility.py
dart tool/bootstrap_local_config.dart
flutter pub get
dart run build_runner build
```

初始化工具仅补齐缺失的本地环境配置，保留已有文件；默认使用环回地址、公开测试签名值和空第三方凭据，不适用于部署。登录前须在被忽略的 `.env.<环境>` 中配置与后端一致的签名值，再重新生成。可运行 `dart tool/bootstrap_local_config.dart --check` 检查配置文件是否齐全；该检查不验证凭据有效性。

### 3. 运行

```bash
flutter run -d <设备ID> \
  --dart-define=APP_ENV=local_home \
  --dart-define=API_BASE_URL_OVERRIDE=http://<电脑局域网IP>:9800
```

`<设备ID>` 来自 `flutter devices`，局域网 IP 例如 `192.168.1.10`。手机上的 `127.0.0.1` 指向手机自身，不能用来连接电脑。

若当前环境配置已正确指向后端，可直接运行：

```bash
flutter run -d <设备ID> --dart-define=APP_ENV=local_home
```

## 常用命令

```bash
flutter analyze                         # 静态检查
flutter test                            # 单元和 Widget 测试
dart scripts/check_boundaries.dart      # 模块边界检查
dart run slang                          # 重新生成多语言代码
flutter build apk --release --flavor standard   # 构建 Android APK
./scripts/build_play_aab.sh <build_number>      # 构建 Google Play AAB（正式包）

```

需要运行真机集成测试时，先阅读 [集成测试说明](./integration_test/README.md)。

## 代码入口

```text
lib/page/          页面
lib/component/     通用组件
lib/modules/       按业务域拆分的功能模块
lib/service/       WebSocket、消息和数据库服务
lib/store/         API、模型与 Repository
lib/theme/         主题与 Design Token
lib/config/        环境配置和路由
assets/i18n/       多语言源文件
test/              单元和 Widget 测试
integration_test/  真机集成测试
```

## 开发前记住

- 写 UI 前先读 [设计规范](./DESIGN.md)。
- 颜色、间距和字号使用 `AppColors`、`AppSpacing`、`FontSizeType`，不要硬编码。
- 附件 URL 必须经过 `AssetsService.viewUrl` 授权。
- 翻译改 `assets/i18n/`，不要手改 `lib/i18n/*.g.dart`。
- 不修改 `ios/*`、`macos/*` 和 `plugin/r_upgrade`。

## 继续阅读

- [项目约定与架构](./CLAUDE.md)
- [贡献指南](./CONTRIBUTING.md)
- [命令参考](./docs/reference/commands.md) · [环境变量参考](./docs/reference/environment-variables.md)
- [代码地图](./docs/codemaps/index.md)
- [模块地图](./docs/module-map.md)
- [自动化测试](./integration_test/README.md)
- [构建与发布](./docs/build-and-release.md)

## 许可证

[木兰宽松许可证，第 2 版](./LICENSE)
