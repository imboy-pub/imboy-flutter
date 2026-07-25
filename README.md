# IMBoy App

IMBoy 的 Flutter 客户端，支持 iOS、Android 和桌面端。主要功能包括单聊、群聊、联系人、频道、朋友圈、收藏、通知和端到端加密。

## 本地启动

### 1. 准备环境

- Flutter 3.41.x（项目要求 Dart 3.8+）
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
flutter pub get
```

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
flutter build apk --release             # 构建 Android APK
flutter build appbundle --release       # 构建 Google Play AAB
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
- [代码地图](./docs/codemaps/index.md)
- [模块地图](./docs/module-map.md)
- [自动化测试](./maestro/README.md)

## 许可证

[木兰宽松许可证，第 2 版](./LICENSE)
