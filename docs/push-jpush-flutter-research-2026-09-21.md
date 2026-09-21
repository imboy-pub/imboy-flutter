# Flutter Push Token 生命周期调研与 JPush SDK 选型（EPGZ-07 W1）

> 日期：2026-09-21 ｜ 基线：imboyapp `60bc4925`（branch run/epgz-07-app-20260921T043945Z）
>
> 范围：计划 §7.4 的 W1 部分——Flutter 端 push 现状梳理、字段错位（App 侧）、
> token 生命周期 RED 测试骨架、JPush SDK/plugin 选型建议与给 A6 的接线 handoff。
> **不修改 pubspec.yaml、不修改 android/ Gradle**（依赖接线由 A6 持 lease 统一处理）。
>
> 后端侧调研：imboy `docs/reference/push-provider-jpush-research-2026-09-21.md`

---

## 1. 现有 push 代码地图

| 文件 | 职责 | 现状 |
|---|---|---|
| `lib/store/api/push_api.dart` | `PushApi.register/unregister` HTTP 调用 | **body 字段错位**（见 §2） |
| `lib/service/push_notification_service.dart` | FCM 初始化、token 获取/刷新、前台/点击处理、注册/注销 | 仅 FCM；`registerToken/unregisterToken` **无调用方**；15s 超时降级本地通知（已考虑国内设备 FCM 不可达） |
| `lib/service/notification_payload_rules.dart` | 通知 payload 纯函数解析（camelCase/snake_case 多键兼容、sealed Result、notify_type 显式分支） | 纯 Dart 零依赖，JPush 点击导航可直接复用 |
| `lib/service/notification.dart` | 本地通知展示（flutter_local_notifications） | 不动 |
| `lib/config/init.dart:645` | `PushNotificationService.instance.initialize()` | 启动即初始化（含 FCM 检测） |
| `lib/config/init.dart:139,342-358` | 全局 `deviceId`（DeviceExt.did，失败回退 Xid） | register body 使用 |
| `lib/store/repository/user_repo_local.dart:177-234` | `loginAfter`：登录后状态建立 | **无 push token 注册**；残留历史 JPush 注释代码（jpush-flutter-plugin getRegistrationID/setAlias） |
| `lib/store/repository/user_repo_local.dart:236-309` | `quitLogin`：登出清理（storage/E2EE/secure token/WS/DB） | **不含 push token 注销** |

pubspec 现状：`firebase_core: 4.15.0`、`firebase_messaging: 16.7.0`、`flutter_local_notifications: ^22.3.1`；**无任何 jpush 依赖**。

## 2. 字段错位（App 侧，与后端调研 §2 对应）

后端合同：`POST /api/v1/push/register` body `{device_id, device_type, platform, token}`；
DB CHECK：`device_type ∈ {android, ios, web}`、`platform ∈ {fcm, apns, web_push}`（W1 起扩展 `jpush`）。

| # | 文件:行 | 问题 | 后果 |
|---|---|---|---|
| 错位 1 | `push_api.dart:24` + `push_notification_service.dart:197` | `platform` 传的是 `Platform.isIOS ? 'ios' : 'android'`——**device_type 的值** | 违反 `chk_push_token_platform` → insert 失败 → 注册 500 |
| 错位 2 | `push_api.dart:24` | body **完全没有 `device_type` 键** | 违反 `chk_push_token_device_type` → 即使错位 1 修复仍 500 |
| 错位 4a | 全 lib/ | `registerToken()`/`unregisterToken()` 零调用方 | 登录后不注册、登出不注销 |
| 错位 4b | `user_repo_local.dart quitLogin` | 清理链不含 push token | 登出后后端仍向该设备推 |

修复清单（W2 执行，见后端调研文档 §2「修复清单」F1-F4）。

## 3. RED 测试骨架

`test/unit_test/service/push_token_lifecycle_test.dart`（本提交新增）：

- 组 1「字段错位快照」：**可运行**（GREEN），白盒复现现状 body，断言缺 device_type、platform 值越界——把错位固化为可执行证据；W2 修复后必须翻转为合同断言并改调真实 API。
- 组 2-5：`skip: 'pending impl: EPGZ-07 W2 ...'` 占位（Dart 无法像 Erlang 以 undefined module 表达 RED，编译期即失败），断言体已按最终合同写好：注册字段合同（android+jpush / android+fcm / ios+apns 三组合）、生命周期（登录注册/刷新重注册/注销）、登出清理（quitLogin 注销 + **登出后不导航**守卫）、失效 token 策略。

运行：`flutter test test/unit_test/service/push_token_lifecycle_test.dart`

## 4. JPush SDK/plugin 选型建议（给 A6）

### 4.1 选型：官方 `jpush_flutter`（jpush-flutter-plugin）

| 项 | 说明 |
|---|---|
| 候选 | ① `jpush_flutter`（极光官方 Flutter plugin，github.com/jpush/jpush-flutter-plugin）② 自写 Android 原生 MethodChannel 嵌极光 Android SDK |
| **推荐** | **① 官方 plugin**：`loginAfter` 历史注释（user_repo_local.dart:222）证明项目曾用它集成过；覆盖 registrationID 获取、别名/标签、通知点击事件；国内网络友好；维护活跃 |
| ② 的问题 | 一期时间盒内自建 channel + 生命周期管理成本高，且 Android 原生层同样要接线，得不偿失 |
| 版本 | **以 A6 实施时 pub.dev 最新稳定版为准**（计划 §7.4 要求「实施时核验过的官方 SDK/plugin」）；建议在 pubspec 锁定 caret 约束并注明核验日期。不要在本调研写入未经核验的具体版本号 |

### 4.2 依赖接线 handoff（A6 持 lease 操作清单）

1. `pubspec.yaml`：`jpush_flutter: ^<实施时核验版本>`（dev 无需额外依赖；mocktail 已在 dev_dependencies，W2 服务层单测可直接用）。
2. `android/app/build.gradle`：
   - AppKey/Channel 通过 **manifestPlaceholders 注入**（如 `JPUSH_APPKEY`、`JPUSH_CHANNEL`），值来自白标 flavor 的本地/CI 环境变量——**严禁把真实 AppKey 提交进仓库**（计划 §7.3/§7.4；客户未提供前用占位符，真机门保持 `BLOCKED_EXTERNAL_JPUSH`）。
   - 检查 minSdkVersion 与 plugin 要求的兼容性；ProGuard 混淆规则按 plugin README 添加。
3. 事件桥：JPush 通知点击（前台 `onReceiveNotification` / 后台与冷启动 `openNotificationForLaunch` + `onOpenNotification`）→ 转成 Map data → 复用 `parseNotificationPayload`（`notification_payload_rules.dart`，纯函数、已支持 snake_case/camelCase）→ 复用 `_navigateByResult` 路由（push_notification_service.dart:243）+ **新增 isLoggedIn 守卫**（§3 组 4「登出后不导航」）。
4. token 生命周期映射：JPush `getRegistrationID()` = push token；注册 body 用 `device_type=android, platform=jpush`（修复 F1/F2）；初始化回调收到 registrationID 即等价"token 刷新"。
5. 日志红线：任何日志不得输出 registrationID token / AppKey / MasterSecret（计划 §7.4；现有 iPrint 已注意不打印 token 明文，保持）。

### 4.3 FCM 共存策略（W2 实现）

- 现有 15s 超时降级逻辑保留：FCM 可用（海外/有 google-services）→ `platform=fcm`；不可用/超时 → JPush（Android 一期客户场景）→ `platform=jpush`。二者由 `PushNotificationService` 内部按可用性择一，body 的 `device_type` 恒为 `android`。
- iOS 不在一期（计划 §1.8），`ios` 分支维持现状不动。

## 5. 安全红线

- 真实 AppKey/MasterSecret 一律环境注入，不入库不入日志；调研/合同文档只用占位符。
- 真机实际发送前必须人工确认（计划 §7.4 第 5 条）；缺 AppKey/资质/设备仅阻塞真机门，不阻塞本地实现。
