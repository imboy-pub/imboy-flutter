# JPush 客户端集成

本页说明当前 Flutter 接线与验证边界，不保存一次执行成绩。依赖约束及实际锁定版本分别见 `pubspec.yaml` 与 `pubspec.lock`；SDK 版本变化时重新验证通道、包名、签名和事件合同。

## 配置与初始化

当前 JPush 接线仅在 Android 且 `IMBOY_JPUSH_ENABLED=true` 时初始化，缺省关闭。`lib/config/init.dart` 调用 `JPushSdkWiring.initialize`；实现见 `lib/service/jpush_flutter_binding.dart`。

Android AppKey 从 ignored `android/local.properties` 的 `jpush.appKey` 注入 manifest placeholder。最终包名必须与 provider 应用一致；白标包后缀会改变最终身份。实际签名、AppKey 和渠道由环境提供，构建日志只应记录配置有无，不能输出 token 或凭据。

**MasterSecret 只放服务端**，不写入客户端配置、构建参数、安装包或日志。AppKey 配置与 Dart 启用开关都不能单独证明 SDK 获得了 RegistrationID，也不能证明手机收到推送。

## Token 生命周期

SDK 的连接事件、预热轮询和 RegistrationID 更新交给 `PushNotificationService.setToken`；实际后端注册 body 为 `{device_id, device_type, platform, token}`。JPush Android 使用 `device_type=android`、`platform=jpush`，不能用设备类型代替 provider。body 实现见 `lib/store/api/push_api.dart`。

登录流程触发注册，登出流程调用注销；token 与已注册状态处理见 `lib/service/push_notification_service.dart` 和 `lib/store/repository/user_repo_local.dart`。FCM 与 JPush 的实际选择取决于初始化及取得的 token，不是仅靠默认 provider 名字判断可用性。

后端需支持该 provider、token 注册合同与数据库通道约束。后端维护合同位于 imboy 仓的 `docs/reference/jpush-provider-contract.md`。缺少后端凭据时适配器不外发；这属于未具备真实渠道发送前提，不是手机到达成功。

## 通知与路由

前台到达不重新创建同一条本地通知；打开通知及冷启动事件经 `extractJPushRoutingPayload` 与 `parseNotificationPayload` 解析后导航。入口检查登录状态，未知 payload 不导航，交付功能入口由路由守卫控制。通知点击入口没有逐对象成员权限复验；撤权后的内容访问仍须由目标页与后端授权拒绝，并在实际验收中验证，不能把页面可打开解释为内容仍有权限。

通知数据只应包含固定路由标识，不携带消息正文、密文片段、发送者身份或密钥。解析支持格式兼容不表示任意业务内容可以写入推送。调用与日志均需保持该边界。

## 维护验证

```bash
flutter test test/unit_test/service/jpush_flutter_binding_test.dart test/unit_test/service/push_token_lifecycle_test.dart test/unit_test/service/notification_payload_rules_test.dart
```

替身测试验证初始化守卫、token 更新、注册字段及点击路由，不证明真实后台到达。实际渠道验收必须分别覆盖前台、后台、杀进程、重复事件、账号切换与撤权后的通知和导航，绑定实际包、配置、设备及候选提交。

真实发送会影响设备和第三方通道，须在已授权的测试范围内执行；仅连接本地替身或关闭 SDK 的测试包不能替代真实 provider 验收。没有匹配的配置或渠道条件时记录未执行，不把它算作通过。
