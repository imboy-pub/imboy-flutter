# ImBoy 跨平台应用方案与自动化测试策略

> 产出时间：2026-07-24 CST
> 范围：`imboyapp`（Flutter 客户端）
> 类型：现状评估 + 跨平台策略 + 自动化测试执行路径

---

## 1. 现状评估：这不是"从零开始"的项目

**关键发现**：ImBoy App 已经是一个成熟的 Flutter 跨平台项目，不是从零设计。本次"跨平台方案"实质是**对现有架构的梳理 + 测试自动化的落地路径**，而非技术选型决策。

### 1.1 平台覆盖现状

| 平台 | 支持度 | 说明 |
|------|--------|------|
| iOS | ✅ 真机生产可用 | `ios/` 为保留区，`SUPPORTED_PLATFORMS = iphoneos`（仅真机） |
| Android | ✅ 真机生产可用 | Kotlin / Gradle 构建链完整 |
| macOS | ✅ 可用 | macOS Desktop，integration_test 无设备兜底 |
| Web | ⚠ 部分支持 | `sqflite_common_ffi_web` + `sqlite3.wasm`，非发布目标 |

**单一 Dart 代码库覆盖四端**，加密 SQLite（SQLCipher）与 E2EE 在四端共用。

### 1.2 技术栈成熟度

| 层级 | 技术 | 版本 | 成熟度 |
|------|------|------|--------|
| 框架 | Flutter / Dart | 3.8+ | ✅ 稳定 |
| 状态管理 | Riverpod | 3.3.1（pin） | ✅ 100% 迁移完成，0 GetX |
| 路由 | go_router | 17.2.0 | ✅ 声明式 |
| 本地数据库 | sqflite + SQLCipher | schema v30 | ✅ 加密 + 迁移脚本 |
| 网络 | Dio + HTTP/2 | 5.10 | ✅ |
| 实时通讯 | WebSocket + protobuf + WebRTC | — | ✅ |
| 群通话 | LiveKit | 2.11.0 | ✅ 稳定版 |
| 国际化 | slang | 4.18.0（10 语言） | ✅ |
| 错误监控 | Sentry | 9.23.0 | ✅ |
| 推送 | Firebase Messaging | 16.4.1 | ✅ |

> **关键约束**：Riverpod / analyzer / mockito 存在传递依赖冲突，已通过 `dependency_overrides` 锁定兼容组合（analyzer ^9 + mockito 5.6.4 + dart_style 3.1.3）。升级时需整体评估，**不可单独 bump**。

---

## 2. 跨平台策略（基于现有架构）

### 2.1 架构五层（已落地）

```
L1  UI/页面层       lib/page · lib/component · lib/modules/*（DDD 充血）
L2  状态层          Riverpod 3.3.1 + riverpod_generator
L3  数据/服务层     lib/store (Repo/Api/Model) · lib/service (WS/消息/DB)
L4  本地存储        sqflite + SQLCipher · shared_prefs · secure_storage
L5  平台通道        WebRTC · LiveKit · FCM · 插件体系
```

### 2.2 DDD 功能模块（lib/modules/）

| 模块 | 职责 |
|------|------|
| `messaging` | 消息（充血领域 + 四层架构） |
| `social_graph` | 好友关系与社交图谱 |
| `group_collab` | 群组协作（任务/投票/日程） |
| `channel_content` | 频道内容订阅 |
| `moment_social` | 朋友圈与动态 |
| `identity` | 身份认证与账户 |
| `security_privacy` | 安全与隐私（E2EE/DND） |
| `ops_governance` | 运营治理（举报/审核） |

### 2.3 跨平台优化建议（可选）

1. **资源 URL 授权**：所有附件 URL 必须经 `AssetsService.viewUrl` 重授权（3600s 有效期）。禁止直接 `Image.network` / `CachedNetworkImage` / `Dio().get`，必须走 `cachedImageProvider` / `dynamicAvatar` / `IMBoyCacheManager().getSingleFile`。
2. **MessageModel.id** 为 `String`（Xid base32hex），**禁止 `int.tryParse`**。
3. **iOS 模拟器限制**：`ios/Runner.xcodeproj` 仅 `iphoneos`，模拟器不在目标列表。`ios/*` 是保留区禁止修改。
4. **Android 调试必须真机**，禁止用模拟器做功能验证。
5. **dart analyze lib** 当前基线（2026-06-22）：No issues found! 历史轨迹 353 → 60 → 0。**仍以实跑为准**。

---

## 3. 三层测试金字塔（已落地）

```
        ┌─────────┐
        │ Tier 3  │  UI 流程测试    integration_test/        真机回归（可选）
        │ ─────── │
      ┌─┴─────────┴─┐
      │   Tier 2    │  冒烟门控      integration_test/smoke/  合并前必须绿
      │ ─────────── │
    ┌─┴─────────────┴─┐
    │     Tier 1      │  API 契约测试  test/api/ (4279 行)    无设备，可 CI
    │ ─────────────── │
    └─────────────────┘
```

### Tier 1 — API 契约测试（无设备，CI 友好）

```bash
API_BASE_URL=http://127.0.0.1:9800 \
TEST_PHONE=+8613800138000 \
TEST_PASSWORD=<pwd> \
  dart test test/api/ --concurrency=1
```

- 覆盖：`auth_api_test` / `conversation_api_test` / `ws_api_test`
- 策略：**SQLite ffi in-memory 优先**，纯函数契约测试
- 跳过策略：后端不可达 → `markTestSkipped`（SKIP，不假绿）

### Tier 2 — 冒烟门控（合并前必须绿）

```bash
flutter test integration_test/smoke/smoke_test.dart \
  --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
  --dart-define=TEST_PHONE=+8613800138000 \
  --dart-define=TEST_PASSWORD=<pwd> \
  -d <real_device_id>
```

- 极简端到端：后端可达 → 登录 API 成功 → App 启动 → 主界面可见
- **前置失败一律 `fail()`，禁止跳过 / 裸 return**

### Tier 3 — UI 流程测试（真机回归）

```bash
flutter test integration_test/all_tests.dart \
  --dart-define=APP_ENV=local_office \
  --dart-define=TEST_PHONE=+8613800138000 \
  --dart-define=TEST_PASSWORD=<pwd> \
  -d <real_device_id>
```

- 模块：`auth/` `chat/` `contact/` `channel/` `mine/` + `e2e_chat_test` + `sqlcipher_migration_test`
- 单模块命令见 `integration_test/README.md`

### 跳过策略（CRITICAL）

| 场景 | 处理 | CI 结果 |
|------|------|---------|
| 后端不可达 | `markTestSkipped` | SKIP |
| 未配置凭证 | `markTestSkipped` | SKIP |
| 登录失败 | `markTestSkipped` | SKIP |
| 数据为空 | `markTestSkipped` | SKIP |
| **断言失败** | `fail` / `expect` | **FAIL** |

> **禁止**：`if (!ok) { return; }` 裸返回——使测试假绿，CI 无法发现问题。

---

## 4. 三种 E2E 自动化方案对比与执行路径

### 方案对比矩阵

| 维度 | A · mobile-mcp | C · flutter test ★ | D · Patrol（待接入） |
|------|---------------|---------------------|---------------------|
| 目标平台 | Android 真机（iOS 受阻） | **所有平台真机 + macOS** | Android 真机（iOS 撞保留区） |
| 当前状态 | ✅ 可用 | ✅ 生产可用 | 📋 待接入 |
| 依赖 | Claude Code MCP 配置 | Flutter SDK 自带 | `patrol` + androidTest 配置 |
| Driver 签名 | 不需要 | **app 自身证书** | app 自身证书 |
| 元素定位 | 视觉/语义推断（概率性） | `Key` 直接可用 | `Key` 直接可用 + 原生控件 |
| 原生弹窗 | ✅ | ❌ 碰不到 | ✅ 权限/通知/WebView |
| 推荐场景 | 探索、故障复现 | **CI 合并门控** | **主 E2E（原生场景）** |

> ~~B · Maestro YAML~~ 已于 2026-07-29 删除：Flutter 的 `Key()` 不接入 accessibility bridge，
> Maestro 只认 `Semantics(identifier:)`，而本仓 83 个字面量 `Key` / 0 个 `Semantics(identifier:)`
> ——那 51 个 flow 从设计上就找不到元素。

### 推荐执行路径

#### 场景 1：CI 自动化（合并门控）→ 方案 C

```bash
cd imboyapp

# 1. 冒烟门控（快，合并前必跑）
flutter test integration_test/smoke/smoke_test.dart \
  -d 00008140-000E30561E32801C \
  --dart-define=APP_ENV=pro \
  --dart-define=TEST_PHONE=+86手机号 \
  --dart-define=TEST_PASSWORD=密码

# 2. 全量 UI 流程（回归）
flutter test integration_test/all_tests.dart \
  -d 00008140-000E30561E32801C \
  --dart-define=APP_ENV=pro \
  --dart-define=TEST_PHONE=+86手机号 \
  --dart-define=TEST_PASSWORD=密码
```

#### 场景 2：日常开发快速验证 → 方案 A

```bash
# 启动 iOS 模拟器
xcrun simctl boot E2DB52F3-D627-401A-9DF7-D9433EE9C039

# 构建并安装
cd imboyapp
flutter build ios --simulator --dart-define=APP_ENV=pro -d E2DB52F3-D627-401A-9DF7-D9433EE9C039
xcrun simctl install E2DB52F3-D627-401A-9DF7-D9433EE9C039 build/ios/iphonesimulator/Runner.app
open -a Simulator

# 然后通过 Claude Code 的 mcp__mobile__* 工具操控
```

#### 场景 3：不接真机时 → macOS 桌面

```bash
cd imboyapp
flutter test integration_test/smoke/smoke_test.dart -d macos \
  --dart-define=APP_ENV=pro \
  --dart-define=API_BASE_URL=https://pro.imboy.pub \
  --dart-define=TEST_PHONE=账号 \
  --dart-define=TEST_PASSWORD=密码
```

> macOS 需显式传 `API_BASE_URL`。实测 2026-07-29：31s 通过。


---

## 5. Widget Key 索引（测试定位用）

优先用 `find.byKey(const Key('...'))`，图标/文本作降级回退。

| Key | Widget | 备注 |
|-----|--------|------|
| `login_phone_input` | 手机号输入框 | 登录页 |
| `login_password_input` | 密码输入框 | 登录页 |
| `login_submit_button` | 登录按钮 | 登录页 |
| `tab_conversations` | 消息 Tab | 索引 0 |
| `tab_contacts` | 联系人 Tab | 索引 1 |
| `tab_channel` | 频道 Tab | 索引 2，feature flag 控制 |
| `tab_mine` | 我的 Tab | 最后索引 |
| `chat_message_input` | 消息输入框 | 聊天页 |
| `send_button` | 发送按钮 | 聊天页 |
| `conversation_search_input` | 会话搜索框 | 会话列表 |
| `add_friend_button` | 添加好友按钮 | 联系人页 |

---

## 6. 共享工具库

`integration_test/flows/test_utils.dart` 提供：

| 函数 | 用途 |
|------|------|
| `settle(tester)` | 等待帧稳定 |
| `takeScreenshot(tester, name)` | 截图，不支持时静默跳过 |
| `ensureBackendAvailable()` | 后端探活，进程内缓存 |
| `checkPreconditions(tester)` | 后端 + 入口 + 自动登录组合检查 |
| `safeTap / tapAny` | 安全点击 |
| `drainKnownFrameworkExceptions` | 过滤良性框架异常，未知异常重抛 |
| `FlowConfig.*` | 从 `--dart-define` 读取配置 |

---

## 7. 风险与建议

### 7.1 已知风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| Riverpod 4.0.4 栈与 mockito 5.7.0 analyzer 冲突 | 升级阻塞 | 已 pin 3.3.1 + analyzer ^9 + mockito 5.6.4，待 riverpod 稳定后整体迁移 |
| `path_provider_foundation` 2.6.0 FFI 崩溃 | macOS 启动崩溃 | pin `<2.6.0`，待 Flutter 稳定 code_assets |
| win32 5.x 栈锁定（file_picker 等） | Windows 构建受限 | 待 file_picker 迁移 win32 6.x 后统一解锁 |
| iOS 模拟器 amap 无 arm64 slice | iOS 26+ 不可用 | 用 iOS ≤18.x 模拟器，或转方案 C |
| Patrol iOS 接入需改 `ios/*` | iOS E2E 阻塞 | 先落地 Android；待保留区解禁再接 iOS |

### 7.2 行动建议

1. ~~**立即落地 CI 门控**：在 PR 合并前强制跑 `smoke_test.dart`（方案 C），保证后端可达 + 登录 + App 启动三件套绿。~~ **→ 已部分落地：pre-push 门控接 Tier 1（见 §9）**
2. ~~**Tier 1 API 契约测试纳入 CI**：`dart test test/api/` 无需设备，可并行跑在每次提交。~~ **→ 已落地：pre-push 自动触发**
3. ~~**3 个 mockito 测试待迁移**到 mocktail~~ **→ 已完成：3 个文件实际未使用 mockito API，直接移除 import + Mock 类声明**
   - `test/service/ack_manager_enhanced_test.dart` ✅
   - `test/service/network_monitor_enhanced_test.dart` ✅
   - `test/service/websocket_heartbeat_test.dart` ✅
   - 验证：`dart analyze` No issues + `flutter test` 79/79 passed
   - 注：mockito 仍作为 riverpod_generator 传递依赖保留在 `dependency_overrides`（pin 5.6.4），需等 riverpod 升级后才能移除
4. **Widget Key 规范化**：新增页面必须为可交互元素注册 Key，并同步更新 `integration_test/README.md` 的索引表。
5. **跳过策略审计**：定期 grep `if (!ok) return;` 模式，确保没有假绿。
6. **iOS 26 兼容性预研**：amap 等 native 插件需评估 arm64 模拟器 slice，为未来 iOS 升级铺路。

---

## 8. 快速命令速查

```bash
# === 构建 ===
flutter pub run build_runner build     # 生成代码（Provider/JSON/envied）
flutter build apk                       # Android 发布
flutter build ios                       # iOS 发布

# === Tier 1（无设备，CI）===
dart test test/api/ --concurrency=1

# === Tier 2（真机冒烟）===
flutter test integration_test/smoke/smoke_test.dart \
  -d <device_id> \
  --dart-define=APP_ENV=pro \
  --dart-define=TEST_PHONE=+86... \
  --dart-define=TEST_PASSWORD=...

# === Tier 3（真机全量）===
flutter test integration_test/all_tests.dart -d <device_id> --dart-define=APP_ENV=pro

# === macOS 桌面（无真机兜底）===
flutter test integration_test/smoke/smoke_test.dart -d macos \
  --dart-define=APP_ENV=pro --dart-define=API_BASE_URL=https://pro.imboy.pub \
  --dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=...

# === 代码质量 ===
dart analyze lib                        # 当前基线：No issues found!
```

---

**结论**：项目跨平台架构已成熟（Flutter 单代码库 + Riverpod + go_router + SQLCipher + DDD 模块化），**测试基础设施完备**（三层金字塔 + 三种 E2E 方案）。下一步重点不是"设计跨平台方案"，而是**把已有的测试门控接入 CI 流水线**，让方案 C（真机 flutter test）成为合并阻塞门，方案 A/B 作为开发期辅助。

---

## 9. Pre-push 门控（已落地）

### 9.1 已接入的钩子

| 钩子 | 命令 | 触发时机 | 行为 |
|------|------|---------|------|
| `pre-commit` | dart format / dart analyze / gitleaks / design-tokens | commit 时 | 已有，未改动 |
| `commit-msg` | conventional commits 校验 | commit 时 | 已有，未改动 |
| **`pre-push`** ⭐ | `dart analyze lib` + `bash scripts/pre_push_gate.sh` | **push 时** | **本次新增** |

### 9.2 pre-push 门控逻辑

```
git push
  ├─ dart analyze lib          （总是跑，~10s，零依赖）
  └─ pre_push_gate.sh
       ├─ IMBOY_SKIP_PRE_PUSH=1？ → 跳过（紧急）
       ├─ 加载 scripts/test.env
       ├─ curl 后端 /api/v1/init（3s 超时）
       │    └─ 不可达 → 优雅跳过（exit 0，不阻塞 push）
       ├─ 检查 TEST_PHONE / TEST_PASSWORD
       │    └─ 未配置 → 优雅跳过（exit 0）
       └─ dart test test/api/ --concurrency=1 --timeout=60s
            ├─ 通过 → exit 0
            └─ 失败 → exit 1（阻塞 push）
```

### 9.3 文件清单

| 文件 | 作用 |
|------|------|
| `lefthook.yml` | 追加 `pre-push` 段（dart-analyze-full + api-contract-tests） |
| `scripts/pre_push_gate.sh` | 探活 + 跑 API 契约测试的包装脚本（可执行） |
| `scripts/test.env` | 测试环境配置（API_BASE_URL / TEST_PHONE / TEST_PASSWORD，已有） |

### 9.4 使用方式

**正常 push**（后端可达 + 凭证就绪时自动跑测试）：
```bash
git push origin main
```

**紧急跳过**（hotfix 等场景）：
```bash
IMBOY_SKIP_PRE_PUSH=1 git push origin main
```

**手动验证门控**：
```bash
# 单独跑脚本
bash scripts/pre_push_gate.sh

# 模拟 lefthook 触发
lefthook run pre-push
```

**本地启动后端后跑完整门控**：
```bash
source scripts/test.env
bash scripts/setup_test_data.sh    # 准备 Alice/Bob 测试数据
bash scripts/pre_push_gate.sh      # 跑 API 契约测试
```

### 9.5 验证结果（2026-07-24）

| 验证项 | 结果 |
|--------|------|
| `bash -n` 语法检查 | ✅ 通过 |
| 后端不可达 → 优雅跳过 | ✅ exit 0 |
| `IMBOY_SKIP_PRE_PUSH=1` → 强制跳过 | ✅ exit 0 |
| lefthook 识别 pre-push 段 + sync hooks | ✅ 成功 |
| `dart analyze lib` | ✅ No issues found! |

### 9.6 设计权衡

1. **为什么默认不跑 smoke 测试？** smoke 需要 iOS 真机（device id），CI 环境不一定有。pre-push 只跑无设备的 Tier 1，smoke 留给 PR 合并前的手动/CI 环节。
2. **为什么后端不可达时跳过而不是失败？** 避免开发者在离线环境下被阻塞。后端可达时才跑，保证测试有意义。
3. **为什么 `--concurrency=1`？** 避免并发登录导致 token 互踢（后端单设备 token 策略）。
4. **为什么 `--timeout=60s`？** 防止后端 hang 住阻塞 push 太久。

---

## 10. Mockito 迁移（已落地）

### 10.1 发现

3 个待迁移测试文件**实际从未使用 mockito API**——都声明了 `@GenerateMocks([])` + Mock 类，但全文从未实例化 Mock，也没有任何 `when/verify` 调用。属于"挂名 mockito"的代码卫生问题。

### 10.2 迁移操作

| 文件 | 删除内容 | 保留 |
|------|---------|------|
| `test/service/ack_manager_enhanced_test.dart` | `import mockito` ×2 + `MockTimer` | `dart:async` / `ack_manager` |
| `test/service/network_monitor_enhanced_test.dart` | `import mockito` ×2 + `MockConnectivity` | `connectivity_plus` / `network_monitor` |
| `test/service/websocket_heartbeat_test.dart` | `import mockito` ×2 + `MockWebSocketChannel` + `import web_socket_channel` | `dart:async` |

### 10.3 验证结果

| 验证项 | 结果 |
|--------|------|
| `grep -rln mockito test/ lib/` | ✅ 零引用（项目代码层面彻底清除） |
| `dart analyze` 三个文件 | ✅ No issues found! |
| `flutter test` 三个文件 | ✅ **79/79 passed**（9s） |

### 10.4 重要说明

mockito **仍保留**在 `pubspec.yaml` 的 `dependency_overrides`（pin 5.6.4），因为它是 `riverpod_generator` 的传递依赖，不是直接依赖。pin 5.6.4 是为了与 `analyzer ^9` 兼容（5.7.0 要求 analyzer ^13，会破坏 riverpod 代码生成链）。

**本次迁移的价值**：
1. 项目代码层面不再直接依赖 mockito API（代码卫生）
2. 为未来 riverpod_generator 升级到兼容版后彻底移除 mockito pin 铺路
3. 消除"假用 mockito"误导，让依赖关系真实可追踪

**彻底移除 mockito 的前置条件**：riverpod_generator 发布兼容 analyzer 12+ 或 13+ 的稳定版（当前 pin 4.0.3，待 4.0.4+ 的 mockito 传递依赖问题解决）。

---

## 11. Android 真机自动化测试实战（2026-07-24 ~ 07-25）

### 11.1 设备环境

| 项 | 值 |
|----|----|
| 设备 | 华为 MRD-AL00 / Android 9 (API 28) |
| ABI | `armeabi-v7a`（32 位 ARM） |
| 设备 ID | `XWE6R19916004085` |
| 测试账号 | `118@imboy.pub`（生产 uid=4），密码见 `scripts/test.env`，**勿写入文档** |
| 生产 API | `https://pro.imboy.pub`（标准路径 `/api/v1/xxx`） |

### 11.2 真机测试路径

| 维度 | `flutter test integration_test/` | Patrol（待接入） |
|------|----------------------------------|------------------|
| APK 构建 | 每个测试重新 build + install（~30s+40s） | 同左（同为进程内） |
| 测试方式 | Dart 代码驱动（`app.main()` + `find.byType`） | 同左 + 原生 automator |
| 原生弹窗 | ❌ | ✅ 权限/通知/WebView |
| 适用场景 | CI 合并门控、逻辑验证 | 主 E2E，覆盖原生场景 |
| 单测试耗时 | ~2-3min | ~2-3min |

> 原「不重装 APK 所以 Maestro 更快」的结论已随 Maestro 删除作废——那条路径在本仓从未真正生效。

### 11.3 已修复的真实 Bug

**Bug 1 — FlowApiClient API 路径缺 `/api` 前缀**（影响所有 integration_test）
- 症状：`smoke_test` setUpAll 登录返回 404 → 测试 fail，框架关闭 app（被误认为"app 自动退出"）
- 根因：`FlowApiClient` 用 `/v1/passport/login`，后端标准是 `/api/v1/passport/login`
- 修复：`integration_test/flows/api_test_client.dart` 2 处 + `smoke_test.dart` 1 处 → `/api/v1/...`
- 验证：用标准 `API_BASE_URL=https://pro.imboy.pub` 跑 smoke，**All tests passed!**（40s）

~~**Bug 2 — Maestro 6 个 flow 桌面图标点击失败**~~ —— 随 Maestro 方案删除，不再适用。

### 11.4 华为 Android 9 真机连接的坑（对 Patrol / mobile-mcp 仍适用）

1. **`adb reconnect` 后设备消失**：`adb kill-server` + `adb reconnect device` 时序不当，可能使设备从 USB 总线彻底掉线（`system_profiler` 也检测不到）。
   - **教训**：优先 `adb kill-server → adb start-server → adb devices` 等待枚举，慎用 `adb reconnect device`。
3. **USB 物理连接脆弱**：华为 Android 9 锁屏 / 线松动会导致 adb 断连，需人工重新插拔与授权。自动化测试前务必确认 `adb devices` 在线。

### 11.5 实用命令速查

```bash
# 确认设备在线（必须第一步）
adb devices -l

# 装上待测构建
flutter build apk --debug --dart-define=APP_ENV=pro
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 手动拉起（验证 app 本身是否正常）
adb shell am start -n imboy.chat/.MainActivity

# 抓崩溃
adb logcat -d | grep -E "FATAL|AndroidRuntime"

# 真机 smoke（flutter test 路径）
source scripts/test.env          # 凭据只从这里来，不写进文档/命令行
flutter test integration_test/smoke/smoke_test.dart \
  -d XWE6R19916004085 \
  --dart-define=API_BASE_URL=https://pro.imboy.pub \
  --dart-define=TEST_PHONE="$TEST_PHONE" \
  --dart-define=TEST_PASSWORD="$TEST_PASSWORD"
```

### 11.6 当前进度

| 任务 | 状态 |
|------|------|
| smoke 测试（flutter test） | ✅ 通过（证明 app 本身无崩溃） |
| Bug 1 FlowApiClient 路径 | ✅ 已修复并验证 |
| ~~Bug 2 Maestro 桌面图标~~ | ❌ 2026-07-29 方案整体删除 |
| Patrol Android 接入 | 📋 待执行 |
| pre-push 门控 / mockito 迁移 | ✅ 已完成 |

---
**Mobile App Builder**：WorkBuddy
**产出日期**：2026-07-24 ~ 07-25
**项目合规**：遵循 AGENTS.md / DESIGN.md 规范，平台保留区未触碰
**本次新增**：pre-push 门控 + mockito 迁移 + Android 真机测试实战（2 个 Bug 修复）
**2026-07-29 更新**：Maestro 方案整体删除，E2E 收敛为 integration_test（现役）+ Patrol（待接入）+ mobile-mcp（探索）
