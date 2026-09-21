/// 极光推送 jpush_flutter 接线桥（EPGZ-06 W3 / plan §7.4）。
///
/// 职责边界（对齐 A7 checkpoint EPGZ-07-IMPL「给 A6」清单）：
/// 1. **setup**：Android AppKey 经 `android/app/build.gradle.kts`
///    manifestPlaceholders（local.properties `jpush.appKey`）注入原生清单，
///    Dart 侧 setup **不传 appKey**——密钥只存在于原生层，不进 Dart 常量、
///    不进日志（秘密红线）；
/// 2. **RegistrationID 注入**：`setToken(rid)` 走
///    [PushNotificationService.instance]（A7 内置守卫：未登录只存 token、
///    loginAfter 兜底注册；W4 合并 A7 分支后自动携带
///    device_type/platform=jpush 字段合同——旧服务签名兼容，无需适配）；
/// 3. **通知点击路由**：onOpenNotification / 冷启动 getLaunchAppNotification
///    → [extractJPushRoutingPayload]（纯函数）→ [parseNotificationPayload]
///    → 登录守卫 + go_router 路由（语义镜像 A7 `_navigateByResult`：未登录
///    忽略、context 未挂载 500ms×5 次延迟重试）；
/// 4. **优雅降级**：构建未开启（`--dart-define IMBOY_JPUSH_ENABLED=true`，
///    缺省 false）或非 Android 平台 → setup/注册整体跳过，与 A7
///    「SDK 缺席静默跳过」一致（不 crash、不注册）。
///
/// 日志红线：RegistrationID / AppKey / MasterSecret 不落日志。
///
/// **W3 形态注**：本桥为独立新文件（未改 A7 的 push 模块源文件）；
/// 启动期调用点（AppInitializer，`lib/config/init.dart` 共享文件）归
/// A0 W4 集成波次接线——调用形态：在 `PushNotificationService.initialize()`
/// 之后 `unawaited(JPushSdkWiring().initialize())`。
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/service/notification_payload_rules.dart';
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
// jpush_flutter 3.5.8 主库无 export：JPush 在 jpush_flutter.dart，
// 接口类型在 jpush_interface.dart（需分别 import 才能拿到
// JPushFlutterInterface 静态类型）。
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';

/// 构建开关（W4 flavor 构建配方随 AppKey 一起下发；缺省 false 保证
/// standard 构建零行为变化——插件已进 pubspec 但不被 setup，原生侧
/// 空占位符初始化即静默无推送）。
const bool _jpushBuildEnabled = bool.fromEnvironment(
  'IMBOY_JPUSH_ENABLED',
  defaultValue: false,
);

/// JPush 渠道名（与 Gradle manifestPlaceholders JPUSH_CHANNEL 对齐的
/// Dart 侧上报值；仅日志/统计用途，非密钥）。
const String _jpushChannel = 'developer-default';

/// RegistrationID 预热轮询：次数 × 间隔（连接/注册是异步过程，rid 不会
/// 立即可得；onConnected 回调为主信号，轮询兜底）。
const int _registrationIdPollAttempts = 12;
const Duration _registrationIdPollInterval = Duration(seconds: 5);

/// jpush_flutter 插件通道抽象（测试注入 fake；生产 [JPushFlutterPluginChannel]）。
abstract interface class JPushPluginChannel {
  void setup({required bool production, required String channel});

  void registerHandlers({
    Future<void> Function(Map<String, dynamic> event)? onOpenNotification,
    Future<void> Function(Map<String, dynamic> event)? onReceiveNotification,
    Future<void> Function(Map<String, dynamic> event)? onConnected,
  });

  Future<String> fetchRegistrationId();

  Future<Map<dynamic, dynamic>> fetchLaunchNotification();
}

/// 生产通道：直连 jpush_flutter 3.5.8。
class JPushFlutterPluginChannel implements JPushPluginChannel {
  JPushFlutterPluginChannel() : _plugin = JPush.newJPush();

  final JPushFlutterInterface _plugin;

  @override
  void setup({required bool production, required String channel}) {
    // appKey 留空：Android 由 manifestPlaceholders 注入原生 SDK，
    // Dart 侧不触碰密钥（见库文档）。
    _plugin.setup(channel: channel, production: production);
  }

  @override
  void registerHandlers({
    Future<void> Function(Map<String, dynamic> event)? onOpenNotification,
    Future<void> Function(Map<String, dynamic> event)? onReceiveNotification,
    Future<void> Function(Map<String, dynamic> event)? onConnected,
  }) {
    _plugin.addEventHandler(
      onOpenNotification: onOpenNotification == null
          ? null
          : (Map<String, dynamic> event) async {
              await onOpenNotification(event);
            },
      onReceiveNotification: onReceiveNotification == null
          ? null
          : (Map<String, dynamic> event) async {
              await onReceiveNotification(event);
            },
      onConnected: onConnected == null
          ? null
          : (Map<String, dynamic> event) async {
              await onConnected(event);
            },
    );
  }

  @override
  Future<String> fetchRegistrationId() => _plugin.getRegistrationID();

  @override
  Future<Map<dynamic, dynamic>> fetchLaunchNotification() =>
      _plugin.getLaunchAppNotification();
}

/// JPush event → 路由 payload 提取（纯函数，测试直测）。
///
/// Android onOpenNotification 的路由键位于嵌套 `extras` Map（值经原生
/// 序列化，统一 toString 交由 [parseNotificationPayload] 的多键兼容矩阵
/// 容错）；`extras` 缺席时按扁平形态透传（iOS/自定义消息直传场景）。
Map<String, dynamic> extractJPushRoutingPayload(Map<dynamic, dynamic> event) {
  final dynamic extras = event['extras'];
  if (extras is Map) {
    return <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> e in extras.entries)
        e.key.toString(): e.value,
    };
  }
  return <String, dynamic>{
    for (final MapEntry<dynamic, dynamic> e in event.entries)
      e.key.toString(): e.value,
  };
}

/// 默认启用判定：构建开关 + Android 平台（JPush 一期仅 Android；
/// iOS/macos/桌面平台不 setup、不注册——平台枚举见 A7 合同）。
bool defaultJPushEnabledCheck() => _jpushBuildEnabled && Platform.isAndroid;

/// 默认 token 注入出口：A7 的 setToken（未登录只存、loginAfter 兜底；
/// W4 合并 A7 分支后自动携带 device_type/platform=jpush 字段合同）。
Future<void> _defaultJPushTokenInjector(String registrationId) =>
    PushNotificationService.instance.setToken(registrationId);

/// JPush SDK 接线（一次性 initialize；幂等，重复调用直接返回）。
class JPushSdkWiring {
  /// 生产形态（全部默认出口；测试用 [JPushSdkWiring.withDefaults] 注入）。
  JPushSdkWiring() : this.withDefaults();

  JPushSdkWiring.withDefaults({
    JPushPluginChannel? plugin,
    Future<void> Function(String registrationId)? tokenInjector,
    void Function(NotificationParseResult result)? tapRouter,
    bool Function()? enabledCheck,
    int registrationIdPollAttempts = _registrationIdPollAttempts,
  }) : _plugin = plugin ?? JPushFlutterPluginChannel(),
       _tokenInjector = tokenInjector ?? _defaultJPushTokenInjector,
       _tapRouter = tapRouter ?? routeNotificationTapLikePushService,
       _enabledCheck = enabledCheck ?? defaultJPushEnabledCheck,
       _pollAttempts = registrationIdPollAttempts;

  final JPushPluginChannel _plugin;
  final Future<void> Function(String registrationId) _tokenInjector;
  final void Function(NotificationParseResult result) _tapRouter;
  final bool Function() _enabledCheck;
  final int _pollAttempts;

  bool _initialized = false;
  bool _registrationIdInjected = false;

  /// 初始化：setup + 事件挂接 + RegistrationID 预热 + 冷启动点击补投。
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!_enabledCheck()) {
      iPrint('[JPush] 未启用（构建开关关闭或非 Android），跳过初始化');
      return;
    }

    try {
      _plugin.setup(production: !kDebugMode, channel: _jpushChannel);
      _plugin.registerHandlers(
        onOpenNotification: handleOpenNotification,
        onReceiveNotification: (Map<String, dynamic> event) async {
          // 前台到达：JPush 原生自行决定展示（厂商通道默认行为），
          // Flutter 侧仅观测，不重建本地通知。
          iPrint('[JPush] 前台通知到达（不路由）');
        },
        onConnected: (Map<String, dynamic> event) async {
          await _tryInjectRegistrationId();
        },
      );

      // 冷启动点击补投：通知拉起 App 时 onOpenNotification 不会再来。
      await _replayColdStartTap();

      // RegistrationID 预热（先立即取一次，再延迟轮询；onConnected 回调
      // 为主信号，轮询兜底）。
      unawaited(_warmUpRegistrationId());
    } on Exception catch (e) {
      // 原生层异常不拖垮启动（降级语义：无推送，不影响其余功能）。
      iPrint('[JPush] 初始化异常降级: $e');
    }
  }

  /// 通知点击（后台/前台）→ 解析 → 登录守卫路由。
  Future<void> handleOpenNotification(Map<String, dynamic> event) async {
    iPrint('[JPush] 通知点击');
    final Map<String, dynamic> payload = extractJPushRoutingPayload(event);
    _tapRouter(parseNotificationPayload(payload));
  }

  /// 冷启动通知补投（getLaunchAppNotification；非通知拉起时为空 map）。
  Future<void> _replayColdStartTap() async {
    try {
      final Map<dynamic, dynamic> launch = await _plugin
          .fetchLaunchNotification();
      if (launch.isNotEmpty) {
        iPrint('[JPush] 冷启动通知点击补投');
        final Map<String, dynamic> payload = extractJPushRoutingPayload(launch);
        _tapRouter(parseNotificationPayload(payload));
      }
    } on Exception catch (e) {
      iPrint('[JPush] 冷启动通知查询失败: $e');
    }
  }

  Future<void> _warmUpRegistrationId() async {
    for (int i = 0; i < _pollAttempts; i++) {
      if (_registrationIdInjected) return;
      await _tryInjectRegistrationId();
      if (_registrationIdInjected || i == _pollAttempts - 1) return;
      await Future<void>.delayed(_registrationIdPollInterval);
    }
  }

  /// 拉取并注入 RegistrationID（rid 为空 = 尚未注册成功，静默等待下轮）。
  ///
  /// 日志只打布尔结论，不落 rid 明文（秘密红线）。
  Future<void> _tryInjectRegistrationId() async {
    if (_registrationIdInjected) return;
    try {
      final String rid = await _plugin.fetchRegistrationId();
      if (rid.isEmpty) return;
      await _tokenInjector(rid);
      _registrationIdInjected = true;
      iPrint('[JPush] RegistrationID 已注入推送服务');
    } on Exception catch (e) {
      iPrint('[JPush] RegistrationID 获取失败: $e');
    }
  }
}

/// 通知点击默认路由（语义镜像 A7 `PushNotificationService._navigateByResult`：
/// 未登录忽略；context 未挂载 500ms×5 次延迟重试——冷启动时 go_router
/// 尚未就绪）。
///
/// W4 集成注：A0 可将其与 A7 的私有实现合并为 PushNotificationService
/// 公开方法（`handleNotificationPayload`），消除镜像重复——本波不改
/// A7 源文件（纪律边界），先以等价语义落桥内。
void routeNotificationTapLikePushService(
  NotificationParseResult result, [
  int retry = 0,
]) {
  if (tapNavigationGuardSkip()) {
    iPrint('[JPush] 用户未登录，忽略通知点击导航');
    return;
  }
  final BuildContext? context = navigatorKey.currentContext;
  if (context == null || !context.mounted) {
    if (retry < 5) {
      Future<dynamic>.delayed(const Duration(milliseconds: 500), () {
        routeNotificationTapLikePushService(result, retry + 1);
      });
      return;
    }
    iPrint('[JPush] 导航失败: context 在 $retry 次重试后仍不可用');
    return;
  }
  switch (result) {
    case NotificationMessageRoute(:final peerId, :final chatType):
      iPrint('[JPush] 导航到会话: peerId=$peerId chatType=$chatType');
      context.go(result.toRoutePath());
    case NotificationFriendRequestRoute():
      iPrint('[JPush] 导航到新朋友页');
      context.go(result.toRoutePath());
    case NotificationGroupInviteRoute(:final groupId):
      iPrint('[JPush] 导航到群详情: groupId=$groupId');
      context.go(result.toRoutePath());
    case NotificationParseSkip(:final reason):
      iPrint('[JPush] 跳过路由: reason=$reason');
  }
}

/// 登录守卫（EPGZ-07 §7.4「登出后不导航」：通知点击只对已登录会话生效）。
/// 顶层可替换字段：生产默认接 UserRepoLocal 登录态；单测替换为固定布尔，
/// 避免拉起 GetX/Storage 服务。
bool Function() tapNavigationGuardSkip = () => !UserRepoLocal.to.isLoggedIn;

/// 测试/定制守卫安装点（生产代码不得调用）。
@visibleForTesting
void setTapNavigationGuardForTest(bool Function() guard) {
  tapNavigationGuardSkip = guard;
}
