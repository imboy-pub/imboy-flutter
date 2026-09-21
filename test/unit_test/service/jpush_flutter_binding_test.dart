/// EPGZ-06 W3 — jpush_flutter 接线桥测试（fake 插件通道，零原生依赖）
///
/// 覆盖 [JPushSdkWiring]：
/// - 未启用（构建开关/平台）→ setup/注册整体跳过（优雅降级）；
/// - 启用 → setup(production/channel) + RegistrationID → tokenInjector
///   （即 A7 setToken 注入路径）+ 空 rid 静默等待；
/// - onOpenNotification → extras 提取 → parseNotificationPayload →
///   tapRouter（登录守卫/路由由注入 router 断言，不拉起 GetX）；
/// - 冷启动 getLaunchAppNotification 补投（空 map 不路由）；
/// - 原生异常不外抛（降级语义）。
///
/// 纯函数 [extractJPushRoutingPayload] 矩阵直测。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/jpush_flutter_binding.dart';
import 'package:imboy/service/notification_payload_rules.dart';

class _FakeJPushPlugin implements JPushPluginChannel {
  _FakeJPushPlugin({this.registrationIds = const <String>[]});

  /// 每次 fetchRegistrationId 依次弹出的值（不足重复最后一个）。
  final List<String> registrationIds;
  int _ridIndex = 0;

  Map<dynamic, dynamic>? launchNotification;

  bool setupCalled = false;
  bool? setupProduction;
  String? setupChannel;

  /// registerHandlers 捕获的回调。
  Future<void> Function(Map<String, dynamic>)? onOpenNotification;
  Future<void> Function(Map<String, dynamic>)? onConnected;

  int registrationIdFetchCount = 0;
  Object? fetchError;

  @override
  void setup({required bool production, required String channel}) {
    setupCalled = true;
    setupProduction = production;
    setupChannel = channel;
  }

  @override
  void registerHandlers({
    Future<void> Function(Map<String, dynamic> event)? onOpenNotification,
    Future<void> Function(Map<String, dynamic> event)? onReceiveNotification,
    Future<void> Function(Map<String, dynamic> event)? onConnected,
  }) {
    this.onOpenNotification = onOpenNotification;
    this.onConnected = onConnected;
  }

  @override
  Future<String> fetchRegistrationId() async {
    if (fetchError != null) throw fetchError!;
    registrationIdFetchCount++;
    if (registrationIds.isEmpty) return '';
    return _ridIndex < registrationIds.length
        ? registrationIds[_ridIndex++]
        : registrationIds.last;
  }

  @override
  Future<Map<dynamic, dynamic>> fetchLaunchNotification() async {
    if (fetchError != null) throw fetchError!;
    return launchNotification ?? <dynamic, dynamic>{};
  }
}

JPushSdkWiring _wiringWith(
  _FakeJPushPlugin plugin, {
  List<String> injectedTokens = const [],
  List<NotificationParseResult> routedResults = const [],
  bool enabled = true,
  int pollAttempts = 1,
}) {
  return JPushSdkWiring.withDefaults(
    plugin: plugin,
    tokenInjector: (String rid) async => injectedTokens.add(rid),
    tapRouter: routedResults.add,
    enabledCheck: () => enabled,
    registrationIdPollAttempts: pollAttempts,
  );
}

void main() {
  group('initialize — 优雅降级', () {
    test('未启用 → setup/注册/冷启动查询全部跳过', () async {
      final plugin = _FakeJPushPlugin(registrationIds: <String>['rid-1']);
      final tokens = <String>[];
      final wiring = JPushSdkWiring.withDefaults(
        plugin: plugin,
        tokenInjector: (String rid) async => tokens.add(rid),
        tapRouter: (_) {},
        enabledCheck: () => false,
      );
      await wiring.initialize();
      expect(plugin.setupCalled, isFalse);
      expect(tokens, isEmpty);
      expect(plugin.registrationIdFetchCount, 0);
    });

    test('默认平台判定在 macos 测试环境为 false（iOS 一期不接）', () {
      // 测试宿主是 macOS：defaultJPushEnabledCheck 必为 false
      // （JPush 一期仅 Android）。构建开关本身是编译期常量，此处
      // 以平台分支断言语义。
      expect(defaultJPushEnabledCheck(), isFalse);
    });
  });

  group('initialize — 启用链路', () {
    test('setup 参数形态 + RegistrationID 注入 A7 setToken 路径', () async {
      final plugin = _FakeJPushPlugin(registrationIds: <String>['rid-abc']);
      final tokens = <String>[];
      final wiring = _wiringWith(plugin, injectedTokens: tokens);
      await wiring.initialize();
      // 预热轮询为 unawaited 后台任务：冲刷微任务队列再断言注入结果。
      await pumpEventQueue();

      expect(plugin.setupCalled, isTrue);
      expect(plugin.setupChannel, 'developer-default');
      expect(tokens, <String>['rid-abc']);
    });

    test('rid 为空 → 静默等待，不注入空 token', () async {
      final plugin = _FakeJPushPlugin(); // fetch 恒空
      final tokens = <String>[];
      await _wiringWith(plugin, injectedTokens: tokens).initialize();
      await pumpEventQueue();
      expect(tokens, isEmpty);
    });

    test('fetch 异常 → 不外抛（降级语义）', () async {
      final plugin = _FakeJPushPlugin()
        ..fetchError = Exception('channel not ready');
      final tokens = <String>[];
      await _wiringWith(plugin, injectedTokens: tokens).initialize();
      await pumpEventQueue();
      expect(tokens, isEmpty);
    });

    test('幂等：重复 initialize 不再 setup', () async {
      final plugin = _FakeJPushPlugin(registrationIds: <String>['rid-1']);
      final tokens = <String>[];
      final wiring = _wiringWith(plugin, injectedTokens: tokens);
      await wiring.initialize();
      await wiring.initialize();
      await pumpEventQueue();
      expect(plugin.setupCalled, isTrue);
      expect(tokens, hasLength(1), reason: '重复 initialize 不重复注入');
    });

    test('onConnected 回调已挂接且可安全触发（连接后注入幂等）', () async {
      final plugin = _FakeJPushPlugin(registrationIds: <String>['rid-1']);
      final tokens = <String>[];
      final wiring = _wiringWith(plugin, injectedTokens: tokens);
      await wiring.initialize();
      await pumpEventQueue();
      expect(tokens, <String>['rid-1']);
      // 连接回调再触发：已注入 → 幂等跳过（不重复 setToken）。
      await plugin.onConnected!(<String, dynamic>{'result': true});
      expect(tokens, <String>['rid-1']);
    });
  });

  group('handleOpenNotification — 点击路由', () {
    test('extras 嵌套路由键 → parse → tapRouter 收到 message 路由', () async {
      final routed = <NotificationParseResult>[];
      final plugin = _FakeJPushPlugin();
      final wiring = _wiringWith(plugin, routedResults: routed);
      await wiring.initialize();

      await plugin.onOpenNotification!(<String, dynamic>{
        'title': '新消息',
        'alert': '你有一条新消息',
        'extras': <dynamic, dynamic>{
          'notify_type': 'message',
          'peer_id': '123456789',
          'chat_type': 'C2C',
        },
      });

      expect(routed, hasLength(1));
      final result = routed.single;
      expect(result, isA<NotificationMessageRoute>());
      expect((result as NotificationMessageRoute).peerId, '123456789');
      expect(result.chatType, 'C2C');
    });

    test('flat 形态（无 extras）→ 直接透传', () async {
      final routed = <NotificationParseResult>[];
      final wiring = _wiringWith(_FakeJPushPlugin(), routedResults: routed);
      await wiring.handleOpenNotification(<String, dynamic>{
        'notify_type': 'friend_request',
      });
      expect(routed.single, isA<NotificationFriendRequestRoute>());
    });

    test('空 payload → skip 结果（不路由）', () async {
      final routed = <NotificationParseResult>[];
      final wiring = _wiringWith(_FakeJPushPlugin(), routedResults: routed);
      await wiring.handleOpenNotification(<String, dynamic>{
        'title': 't',
        'extras': <dynamic, dynamic>{},
      });
      expect(routed.single, isA<NotificationParseSkip>());
      expect((routed.single as NotificationParseSkip).reason, 'empty_payload');
    });
  });

  group('冷启动点击补投 — getLaunchAppNotification', () {
    test('通知拉起 App → 补投路由', () async {
      final routed = <NotificationParseResult>[];
      final plugin = _FakeJPushPlugin()
        ..launchNotification = <dynamic, dynamic>{
          'extras': <dynamic, dynamic>{
            'notify_type': 'group_invite',
            'group_id': '987654321',
          },
        };
      await _wiringWith(plugin, routedResults: routed).initialize();
      expect(routed, hasLength(1));
      expect(routed.single, isA<NotificationGroupInviteRoute>());
    });

    test('非通知拉起（空 map）→ 不路由', () async {
      final routed = <NotificationParseResult>[];
      await _wiringWith(_FakeJPushPlugin(), routedResults: routed).initialize();
      expect(routed, isEmpty);
    });
  });

  group('extractJPushRoutingPayload — 纯函数矩阵', () {
    test('extras Map → 键值字符串化透传', () {
      final payload = extractJPushRoutingPayload(<dynamic, dynamic>{
        'extras': <dynamic, dynamic>{
          'notify_type': 'message',
          'peer_id': 123456789,
        },
      });
      expect(payload['notify_type'], 'message');
      expect(payload['peer_id'], 123456789);
    });

    test('无 extras → 顶层透传', () {
      final payload = extractJPushRoutingPayload(<dynamic, dynamic>{
        'notify_type': 'message',
        'peer_id': '42',
      });
      expect(payload['peer_id'], '42');
    });

    test('extras 非 Map → 顶层透传', () {
      final payload = extractJPushRoutingPayload(<dynamic, dynamic>{
        'extras': 'garbage',
        'peer_id': '42',
      });
      expect(payload['peer_id'], '42');
    });
  });
}
