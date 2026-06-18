<!-- Generated: 2026-06-18 | Files scanned: pubspec.yaml + lock files | Token estimate: ~650 -->

# 依赖管理 | Dependency Management

**最后更新 / Last Updated:** 2026-06-18 CST

---

## 外部服务 | External Services

| 服务 / Service | 技术 / Technology | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **后端** / Backend | Erlang/OTP 28+ (../imboy/) | WebSocket + REST API + 许可网关 | ✅ Active |
| **错误追踪** / Error Tracking | sentry_flutter 8.12+ | 崩溃上报 & APM | ✅ Active |
| **推送通知** / Push Notifications | firebase_messaging 15.2+ | FCM (Android) / APNS (iOS) | ✅ Active |
| **地图** / Maps | amap_flutter_* | 高德地图（中国）| ✅ Active (位置分享) |
| **手机验证** / Phone Verification | plugin/jverify/ | 极光验证 SDK | ✅ Active |

---

## 核心依赖 | Core Dependencies

### 状态管理 | State Management

| 包 / Package | 版本 / Version | 用途 / Purpose | 迁移 / Status |
|-----------|---------|---------|---------|
| **riverpod** | 3.3.1+ | 状态管理框架 | ✅ 100% 迁移 (2026-01) |
| **hooks_riverpod** | 3.3.1+ | Riverpod hooks (use/ref) | ✅ Active |
| **riverpod_generator** | 3.3.1+ | @riverpod 代码生成 | ✅ Active |
| **flutter_riverpod** | 3.3.1+ | Flutter 集成 | ✅ Active |
| get | 4.6.0+ | GetIt 单例容器 | ⚠️ 逐步弃用 (Q3 2026) |
| get_storage | 2.1.0+ | GetX 存储 | ❌ 已替换 |

### 路由 & 导航 | Routing & Navigation

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **go_router** | 17.0.1+ | 声明式路由 | ✅ Active |
| **go_router_builder** | 2.5.0+ | 类型安全路由生成 | ⚠️ Optional |

### 数据库 & 存储 | Database & Storage

| 包 / Package | 版本 / Version | 用途 / Purpose | 注释 / Notes |
|-----------|---------|---------|---------|
| **sqflite_sqlcipher** | 2.4.2+ | SQLite + AES-256 加密 | 所有数据强制加密 (v21) |
| **shared_preferences** | 2.5.4+ | 普通 KV 存储 | 非敏感数据 |
| **flutter_secure_storage** | 10.0.0+ | 安全 KV (Keychain/EncryptedSharedPreferences) | 敏感数据（JWT, RSA Key, License Key） |
| **drift** | 2.0.0+ | 类型安全 ORM | 部分新 Repo 使用（Optional） |
| **sqflite** | 2.4.0+ | 原生 SQLite（不加密） | 仅配置/缓存库 |

### 网络通讯 | Networking

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **dio** | 5.9.0+ | HTTP 客户端 (REST API) | ✅ Active (33 个 API 客户端) |
| **web_socket_channel** | 3.0.0+ | WebSocket 长连接 | ✅ Active (实时消息、许可检查) |
| **connectivity_plus** | 7.0.0+ | 网络状态监控 | ✅ Active |
| **webrtc_flutter** | 0.15.0+ | WebRTC 语音/视频 | ✅ Active |

### 加密与安全 | Cryptography & Security

| 包 / Package | 版本 / Version | 用途 / Purpose | 用例 / Use Case |
|-----------|---------|---------|---------|
| **pointycastle** | 4.0.0+ | RSA, AES, ECDH 加密 | E2EE 核心库 (RSA-2048-OAEP) |
| **crypto** | 3.0.0+ | SHA, MD5, 哈希函数 | 消息签名验证、KDF (PBKDF2) |
| **jose** | 0.3.5+ | JWT/JWE 处理 | Token 验证 (RS256) |
| **sharmir_secret_sharing** | 0.2.0+ | Shamir 秘密共享 | 密钥碎片重构 (5-of-3) |

### 多媒体 & 文件 | Media & File

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **wechat_camera_picker** | 4.5.0+ | 相机（微信风格） | ✅ Active |
| **wechat_assets_picker** | 10.1.1+ | 相册选择器 | ✅ Active |
| **image_picker** | 1.2.0+ | 系统相机/相册 | ✅ Active |
| **video_player** | 2.11.0+ | 视频播放 | ✅ Active |
| **video_compress** | 3.1.4+ | 视频压缩 | ✅ Active (频道视频优化) |
| **just_audio** | 0.9.0+ | 音频播放（语音消息） | ✅ Active (VoicePlaybackService) |
| **record** | 5.0.0+ | 音频录制 | ✅ Active (ChatInputHandler) |
| **file_picker** | 8.0.0+ | 文件选择器 | ⚠️ win32 override 债务 (Critical) |
| **path_provider** | 2.2.0+ | 文件系统路径 | ✅ Active |
| **octo_image** | 2.0.0+ | 缓存图片加载 | ✅ Active |
| **cached_network_image** | 3.4.0+ | 网络图片缓存 | ⚠️ 应改用 cachedImageProvider (High) |

### 国际化 | Internationalization

| 包 / Package | 版本 / Version | 用途 / Purpose | 语言 / Languages |
|-----------|---------|---------|---------|
| **slang** | 4.14.0+ | i18n 代码生成 | 10 languages (ja-JP 新增 2026-06) |
| **intl** | 0.20.0+ | i18n 基础库 | 日期、数字格式化 |

### UI & 设计系统 | UI & Design System

| 包 / Package | 版本 / Version | 用途 / Purpose | 状态 / Status |
|-----------|---------|---------|---------|
| **flutter_local_notifications** | 17.2.0+ | 系统通知 | ✅ Active (NotificationGateway) |
| **lottie** | 2.8.0+ | 动画 (Lottie JSON) | ✅ Active |
| **photo_view** | 0.14.0+ | 图片查看器（缩放） | ✅ Active |
| **map_launcher** | 2.0.0+ | 地图应用启动 | ✅ Active |
| **amap_flutter_base** | 3.9.0+ | 高德地图 (中国) | ✅ Active (位置分享) |
| **flutter_screenutil** | 5.9.0+ | 屏幕适配 | ✅ Active |
| **flutter_animate** | 4.5.0+ | 动画框架 | ✅ Active (UI 过渡) |
| **emoji_picker_flutter** | 4.4.0+ | 表情选择器 | ✅ Active (ChatReactionHandler) |
| **flutter_easyloading** | 3.0.0+ | 加载/提示弹窗 | ⚠️ 74 处用法待重构 (High) |

### 测试框架 | Testing Frameworks

| 包 / Package | 版本 / Version | 用途 / Purpose | 覆盖 / Coverage |
|-----------|---------|---------|---------|
| **flutter_test** | — | Widget/单元测试 | 204 files |
| **mockito** | 3.1.0+ | Mock 框架 | Repository / Service 单测 |
| **fake_async** | 1.3.0+ | 异步时间控制 | Timer / Future 单测 |
| **integration_test** | — | E2E 测试 | 关键用户流 |

---

## 平台特定依赖 | Platform-Specific Dependencies

### iOS

```
Podfile (custom pods):
  ├── pod 'YYModel'           JSON 序列化加速
  ├── pod 'SDWebImage'        图片加载优化
  └── pod 'Keychain'          密钥存储 (flutter_secure_storage)

iOS Keychain:
  • 用于存储 RSA 私钥、JWT token、License Key
  • 同步到 iCloud Keychain (可选)
```

### Android

```
build.gradle:
  ├── minSdkVersion: 21
  ├── targetSdkVersion: 34
  └── androidx.security:security-crypto  EncryptedSharedPreferences

EncryptedSharedPreferences:
  • 用于存储 RSA 私钥、JWT token、License Key
  • 密钥由 Android Keystore 管理
```

### macOS

```
podspec (custom):
  ├── pod 'Keychain'  (同 iOS)
  └── pod 'SQLCipher' (同 iOS/Android)

Entitlements:
  • com.apple.security.temporary-exception.shared-web-credential
```

---

## 技术债清单 | Technical Debt Inventory

### Critical Issues (须尽快修复)

| 债务 / Debt | 影响 / Impact | 优先级 / Priority | 修复方案 / Fix |
|-----------|---------|---------|---------|
| **file_picker win32 override** | file_picker 升级被阻塞，导致安全补丁延迟 | 🔴 Critical | 升级 win32 至 6.x；或改用 cross_file |
| **flutter_easyloading 74 处用法** | 依赖不稳定，应改用 flutter_local_notifications | 🔴 Critical | 重构 74 处调用 → 标准化通知 API |

### High Priority (Q2-Q3 2026)

| 债务 / Debt | 影响 / Impact | 优先级 / Priority | 修复方案 / Fix |
|-----------|---------|---------|---------|
| **GetX 遗留迁移** | 30% 代码仍用 Get.to()、GetIt 单例 | 🟡 High | 完全迁移至 go_router + Riverpod |
| **cached_network_image 弃用** | 应改用 cachedImageProvider（已包装） | 🟡 High | 替换 100+ 处调用 |
| **dart analyze 警告** | 58 个 dead_code/unused_field 警告 | 🟡 High | 死代码清理 (CLEANUP_PLAN T12) |

### Medium Priority (Q3 2026)

| 债务 / Debt | 影响 / Impact | 优先级 / Priority | 修复方案 / Fix |
|-----------|---------|---------|---------|
| **Model 序列化方案** | 混用 json_serializable + 手工 fromJson | 🟡 Medium | 统一改用 drift 或 freezed |
| **Widget 测试覆盖** | <30% 覆盖，易产生回归 | 🟡 Medium | 补全关键页面单测（200+ 页面） |
| **package override** | pubspec.yaml 有 2 个 override (pointycastle, …) | 🟡 Medium | 定期审视、更新依赖版本 |

---

## 升级路线图 | Upgrade Roadmap

### Phase 1: Critical Fixes (2026-07)

```
1. win32 upgrade (5.x → 6.x) + file_picker 升级
2. flutter_easyloading → flutter_local_notifications (标准 API)
3. 验证 Android 28+ 兼容性
```

### Phase 2: GetX Migration (2026-Q3)

```
1. 审计所有 GetIt 单例依赖
2. 迁移至 Riverpod Provider
3. 替换 Get.to() / Get.back() → go_router
4. 删除 get 依赖
```

### Phase 3: Code Quality (2026-Q3)

```
1. 死代码清理 (dart analyze → 0 warnings)
2. Widget 测试覆盖提升 (30% → 50%)
3. 性能审计 & hot path 优化
```

---

## 依赖版本约束策略 | Versioning Strategy

| 类型 / Type | 约束 / Constraint | 理由 / Rationale | 示例 / Example |
|-----------|---------|---------|---------|
| 关键库 / Critical | 锁定 major.minor | 防止破坏性升级 | `riverpod: ^3.3.1` |
| 稳定库 / Stable | 浮动 patch | 自动获得安全补丁 | `dio: ^5.9.0` |
| 新库 / New | 锁定 major | 等待成熟度 | `sharmir_secret_sharing: ^0.2.0` |
| dev_dependencies | 最新可用 | 开发工具常更新 | `build_runner: any` |

---

## 安全审计 | Security Audit

### 已知漏洞检查 | Known Vulnerabilities

运行定期检查：

```bash
flutter pub global activate flutter_analyzer
flutter pub audit
# 或：flutter packages pub publish --dry-run
```

### 敏感依赖 | Sensitive Dependencies

| 依赖 / Dependency | 安全考量 / Security Considerations |
|-----------|---------|
| **pointycastle** | RSA-2048 密钥生成使用了 /dev/urandom；确保随机性 |
| **crypto** | PBKDF2 轮数应 ≥64000；本项目使用 64000 ✅ |
| **flutter_secure_storage** | 密钥由系统管理；须启用 ProGuard/R8 (Android) |
| **sqflite_sqlcipher** | AES-256-CBC；验证密钥导出无泄露 ✅ |

---

## 依赖更新检查清单 | Dependency Update Checklist

```
□ flutter pub upgrade --dry-run（查看可升级项）
□ 检查 CHANGELOG（breaking changes）
□ 针对新版本运行 `dart analyze lib`
□ 运行 `flutter test` （全套单测）
□ 本地 Android 构建测试
□ 本地 iOS 构建测试（≥ Xcode 15.2）
□ 检查 gradle 兼容性（Android）
□ 更新本文档的版本记录
□ 创建 git commit (type: chore)
```

---

## 相关文档 | Related Documentation

| 文档 | 位置 |
|------|------|
| 项目 CLAUDE.md | `./CLAUDE.md` § 技术栈 |
| 架构文档 | `./docs/CODEMAPS/architecture.md` |
| 数据库架构 | `./docs/CODEMAPS/data.md` |

---

**更新者 / Updated by:** Claude Code  
**更新周期 / Update Cycle:** Quarterly (版本检查), Monthly (债务审视)  
**下次审计：** 2026-09-18
