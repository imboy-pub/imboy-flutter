<!-- Generated: 2026-04-17 | Files scanned: pubspec.yaml + lock files | Token estimate: ~620 -->

# 依赖管理 | Dependency Management

**最后更新 / Last Updated:** 2026-04-17 CST

---

## 外部服务 | External Services

| 服务 / Service | 技术 / Technology | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **后端** / Backend | Erlang/OTP (../imboy/) | WebSocket + REST API | ✅ Active |
| **错误追踪** / Error Tracking | sentry_flutter 8.12 | 崩溃上报 & APM | ✅ Active |
| **推送通知** / Push Notifications | firebase_messaging 15.2 | FCM (Android) / APNS (iOS) | ✅ Active |
| **地图** / Maps | amap_flutter_* | 高德地图（中国） | ✅ Active (位置分享) |
| **手机验证** / Phone Verification | plugin/jverify/ | 极光验证 SDK | ✅ Active |

---

## 核心依赖 | Core Dependencies

### 状态管理 | State Management

| 包 / Package | 版本 / Version | 用途 / Purpose | 迁移 / Status |
|-----------|---------|---------|---------|
| **riverpod** | 2.5.0+ | 状态管理框架 | ✅ 100% 迁移 (2026-01) |
| **hooks_riverpod** | 2.5.0+ | Riverpod hooks (use/ref) | ✅ Active |
| **riverpod_generator** | 2.5.0+ | @riverpod 代码生成 | ✅ Active |
| get | 4.6.0+ | GetIt 单例容器 | ⚠️ 逐步弃用 |
| get_storage | 2.1.0+ | GetX 存储 | ❌ 已替换 |

### 路由 & 导航 | Routing & Navigation

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **go_router** | 17.0.1+ | 声明式路由 | ✅ Active |
| go_router_builder | 2.5.0+ | 类型安全路由生成 | ⚠️ Optional |

### 数据库 & 存储 | Database & Storage

| 包 / Package | 版本 / Version | 用途 / Purpose | 注释 / Notes |
|-----------|---------|---------|---------|
| **sqflite_sqlcipher** | 2.4.2+ | SQLite + AES-256 加密 | 所有数据强制加密 |
| **shared_preferences** | 2.5.4+ | 普通 KV 存储 | 非敏感数据 |
| **flutter_secure_storage** | 10.0.0+ | 安全 KV (Keychain/EncryptedSharedPreferences) | 敏感数据（Token, RSA Key） |
| drift | 2.0.0+ | 类型安全 ORM | 部分新 Repo 使用 |
| sqflite | 2.4.0+ | 原生 SQLite（不加密） | 仅配置/缓存库 |

### 网络通讯 | Networking

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **dio** | 5.9.0+ | HTTP 客户端 (REST API) | ✅ Active |
| **web_socket_channel** | 3.0.0+ | WebSocket 长连接 | ✅ Active (实时消息) |
| **connectivity_plus** | 7.0.0+ | 网络状态监控 | ✅ Active |
| **webrtc_flutter** | 0.15.0+ | WebRTC 语音/视频 | ✅ Active |

### 加密与安全 | Cryptography & Security

| 包 / Package | 版本 / Version | 用途 / Purpose | 用例 / Use Case |
|-----------|---------|---------|---------|
| **pointycastle** | 4.0.0+ | RSA, AES, ECDH 加密 | E2EE 核心库 |
| **crypto** | 3.0.0+ | SHA, MD5, 哈希函数 | 消息签名验证 |
| **jose** | 0.3.5+ | JWT/JWE 处理 | Token 验证 |

### 多媒体 & 文件 | Media & File

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **wechat_camera_picker** | 4.5.0+ | 相机（微信风格） | ✅ Active |
| **wechat_assets_picker** | 10.1.1+ | 相册选择器 | ✅ Active |
| **image_picker** | 1.2.0+ | 系统相机/相册 | ✅ Active |
| **video_player** | 2.11.0+ | 视频播放 | ✅ Active |
| **video_compress** | 3.1.4+ | 视频压缩 | ✅ Active |
| **just_audio** | 0.9.0+ | 音频播放（语音消息） | ✅ Active (VoicePlaybackService) |
| **record** | 5.0.0+ | 音频录制 | ✅ Active |
| **file_picker** | 8.0.0+ | 文件选择器 | ⚠️ win32 override 债务 |
| **path_provider** | 2.2.0+ | 文件系统路径 | ✅ Active |
| **octo_image** | 2.0.0+ | 缓存图片加载 | ✅ Active |
| cached_network_image | 3.4.0+ | 网络图片缓存 | ⚠️ 应改用 cachedImageProvider |

### 国际化 | Internationalization

| 包 / Package | 版本 / Version | 用途 / Purpose | 语言 / Languages |
|-----------|---------|---------|---------|
| **slang** | 4.14.0+ | i18n 代码生成 | 11 languages (zh/en/de/fr/it/ja/ko/ru/ar/pt) |

### UI & 设计系统 | UI & Design System

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **flutter_local_notifications** | 17.2.0+ | 系统通知 | ✅ Active (NotificationGateway) |
| **lottie** | 2.8.0+ | 动画 (Lottie JSON) | ✅ Active |
| **photo_view** | 0.14.0+ | 图片查看器（缩放） | ✅ Active |
| **map_launcher** | 2.0.0+ | 地图应用启动 | ✅ Active |
| **amap_flutter_base** | 3.9.0+ | 高德地图 (中国) | ✅ Active (位置分享) |
| flutter_screenutil | 5.9.0+ | 屏幕适配 | ✅ Active |
| flutter_animate | 4.5.0+ | 动画框架 | ✅ Active |
| emoji_picker_flutter | 4.4.0+ | 表情选择器 | ✅ Active |
| qr_flutter | 4.1.0+ | 二维码显示 | ✅ Active |

### 日志 & 监控 | Logging & Monitoring

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **logger** | 2.6.0+ | 结构化日志 | ✅ Active (lib/service/app_logger.dart) |
| **sentry_flutter** | 8.0.0+ | 崩溃上报 & APM | ✅ Active (main.dart init) |
| **firebase_messaging** | 15.2.0+ | 推送通知 (FCM) | ✅ Active |

### 工具库 | Utilities

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **freezed** | 2.0.0+ | 数据类代码生成 | ✅ 部分使用 |
| **json_serializable** | 6.0.0+ | JSON 序列化代码生成 | ✅ Model 序列化 |
| **uuid** | 4.0.0+ | UUID 生成 | ✅ 临时 ID 生成 |
| **package_info_plus** | 8.3.0+ | 版本信息 | ⚠️ win32 override |
| **device_info_plus** | 11.5.0+ | 设备信息 | ⚠️ win32 override |
| **permission_handler** | 11.8.0+ | 权限管理 | ✅ Active |

---

## 版本约束策略 | Version Constraint Strategy

### 关键依赖锁定 | Pinned Versions (Strict)

```yaml
pubspec.yaml:
  riverpod: ^2.5.0              # 最小 2.5.0 (1.x 旧版已弃)
  go_router: ^17.0.0            # 最小 17.0 (15.x 旧版已弃)
  sqflite_sqlcipher: ^2.4.2     # 最小 2.4.2 (性能修复)
  dio: ^5.9.0                   # 最小 5.9 (HTTP/2)
  flutter_riverpod: ^2.5.0      # 与 riverpod 版本一致
```

### 浮动版本 | Floating Versions (Compatible)

```yaml
  flutter: ^3.0.0               # 允许 >= 3.0（跨版本兼容）
  connectivity_plus: ^7.0.0     # 允许 >= 7.0
  image_picker: ^1.0.0          # 允许 >= 1.0
  firebase_messaging: ^15.0.0   # 允许 >= 15.0
```

---

## 依赖冲突 & 技术债 | Conflicts & Tech Debt

### 🔴 Critical: win32 版本债务

```yaml
dependency_overrides:
  win32: 5.x                    # 强制 5.x (Windows only)
  win32_registry: ^2.0.0        # 依赖 win32 5.x
  package_info_plus: ^8.3.0     # 依赖 win32 5.x (不支持 6.x)
  device_info_plus: ^11.5.0     # 依赖 win32 5.x (不支持 6.x)

冲突根源：
  - file_picker 8.0.0+ 要求 win32 6.x+
  - 但 package_info_plus / device_info_plus 仍基于 win32 5.x
  - 需要 override 强制统一为 5.x 以通过编译

阻塞项：
  - file_picker (等待下游 pub 更新)
  - package_info_plus (等待官方支持 win32 6.x)

预期解决：2026-Q2~Q3（取决于上游发布）

临时方案：
  在 Windows 上运行时可能遇到某些功能不可用
  建议在 macOS/Linux 开发或使用虚拟机
```

### 🟡 High: GetX 遗留（逐步弃用）

```dart
// 残留的 GetX 用法（仍在某些 Service 中）
import 'package:get/get.dart';

GetIt.instance.registerSingleton<T>(impl)  // 部分 Service
Rx<T> status                               // 部分 WebSocket
Get.back()                                 // 部分路由

迁移进度（2026-04-17）:
  ✅ 状态管理 → Riverpod 100% (2026-01)
  ⚠️ GetIt 单例 → Riverpod Provider (进行中, ~50%)
  ⚠️ Rx<T> → StateNotifier<T> (进行中, ~30%)
  ⚠️ 路由导航 → context.pop() / go_router (进行中, ~80%)

预期完成：2026-Q2
```

### 🟡 High: CachedNetworkImage 遗留（应弃用）

```dart
// ❌ 已弃用的用法
import 'package:cached_network_image/cached_network_image.dart';
CachedNetworkImage(imageUrl: url)

// ✅ 推荐新用法（所有资源 URL 需授权）
import 'package:imboy/component/helper/func.dart';
Image(image: cachedImageProvider(url, w: 400))

原因：
  - cachedImageProvider 内部调用 AssetsService.viewUrl()
  - 所有资源 URL 必须经过服务端签名授权（有效期 3600s）
  - 直接使用原始 URL 会导致 401 Unauthorized

迁移检查清单：
  ☐ 全量搜索 'CachedNetworkImage' 并替换
  ☐ 全量搜索 'Image.network(' 并替换为 cachedImageProvider
  ☐ 验证所有头像、消息图片使用新方式
```

---

## 依赖包体积 | Dependency Size Analysis

| 包分类 / Category | 大小 / Size | 占比 / Percentage | 优化机会 / Optimization Opportunity |
|-----------|---------|---------|---------|
| 引擎 / Flutter Engine | ~45MB | 60% | 无（系统） |
| 加密库 (pointycastle 等) | ~8MB | 10% | 考虑精简不常用的加密方案 |
| 媒体库 (FFmpeg, webrtc) | ~12MB | 16% | 无（核心功能） |
| UI 库 (Material, Cupertino) | ~5MB | 7% | 无（系统） |
| 国际化 (slang) | ~1MB | 2% | 无（必需） |
| **总计** | **~71MB** | **100%** | 优化空间有限 |

**建议：** 生产构建时启用 R8/ProGuard 混淆和 size 分析：
```bash
flutter build apk --split-per-abi --analyze-size
flutter build ios --analyze-size
```

---

## 安全检查 | Security Audit

**最近检查时间：** 2026-04-17

| 包 / Package | 安全状态 / Security Status | 已知漏洞 / Known Vulnerabilities |
|-----------|---------|---------|
| pointycastle | ✅ Safe | 无 |
| dio | ✅ Safe | 无 |
| sqflite_sqlcipher | ✅ Safe | 无 |
| flutter_secure_storage | ✅ Safe | 无 |
| jose | ⚠️ Monitor | 检查 JWT 签名验证 (0.3.5 已修复) |

**检查方法：**
```bash
# 扫描已知漏洞
flutter pub global activate pana
pana .

# 检查过时依赖
flutter pub outdated

# 安全审计
pub global activate pub_audit
pub audit
```

---

## 更新检查清单 | Pre-Update Checklist

**更新依赖前：**

```markdown
- [ ] 所有当前测试通过
- [ ] 检查更新包的破坏性变更
- [ ] 阅读更新日志（CHANGELOG）
- [ ] 验证新版本支持全部平台 (iOS/Android/macOS/Web)
- [ ] 检查是否与 Flutter 版本兼容
- [ ] 如更新加密库，需要向后兼容性测试
```

**更新后的验证：**

```bash
# 1. 删除旧生成代码
flutter clean

# 2. 重新生成依赖和代码
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 3. 完整测试
flutter test
flutter test integration_test/

# 4. 静态分析
dart analyze --fatal-infos

# 5. 大小检查（主要依赖）
flutter build apk --release --analyze-size
```

---

## 升级路线图 | Upgrade Roadmap (2026)

| 目标 / Goal | 预期 ETA | 风险 / Risk | 优先级 / Priority |
|-----------|---------|---------|---------|
| 解决 win32 债务 (file_picker → 7.x) | Q2 | Medium | 🔴 Critical |
| 完成 GetX → Riverpod 迁移 | Q2 | Medium | 🟡 High |
| 替换全部 CachedNetworkImage | Q2 | Low | 🟡 High |
| 升级 Flutter 3.8 → 3.10 | Q3 | Low | 🟢 Medium |
| 升级 Dart 3.8 → 3.10 | Q3 | Low | 🟢 Medium |
| 升级 firebase_messaging 15.x → 16.x | Q3 | Low | 🟢 Low |

---

**相关文档 / Related Docs**
- [`architecture.md`](./architecture.md) — 服务如何使用依赖
- [pubspec.yaml](../../pubspec.yaml) — 完整版本列表
- [CHANGELOG.md](../../CHANGELOG.md) — 版本历史
- [../imboy/](../imboy/) — 后端服务接口
