/// FL-17 · 可选 SDK 消费者边界合同测试（零调用 / 失败降级 / 重试预算）。
///
/// 覆盖（对照卡内 PLANNED 断言）：
/// - A. 地图关闭（无授权）：AMap 插件通道零调用（含懒初始化）、POI REST /
///   静态图在 HTTP 之前被拒、picker 占位页且 WebView/POI 零流量；
/// - B. 授权撤回释放定位流：scope 变化 → stopLocation + destroy；
/// - C. 已授权路径：POI 单发无自动重试风暴、静态图传输失败降级 null、
///   geolocator fallback 遵守权限（denied/deniedForever/服务关闭零定位
///   调用）、失败降级 lastKnown、命中缓存零新调用；
/// - D. 推送：JPush 构建开关关（缺省无 IMBOY_JPUSH_ENABLED）零插件调用、
///   FCM 在未支持平台零网络、无同意零启动、撤歈权后停一次、RID 预热
///   预算有界（N 次封顶、撤回中止、同授权不重启）；
/// - E. RTC：feature registry fail-closed（远程 snapshot 不能重开未选入
///   组合的 rtc_group）、群通话入口零 joinRoom、C2C connect 并发收敛单次
///   joinRoom、拒绝后无自动重试、挂断后迟到信令/重连零调用；
/// - F. init 接线（源码合同）：会话切换同步 AMap scope 与推送同意、
///   dispose 释放；群通话入口 await 前后双重 feature 复查。
///
/// 覆盖差异（不冒充真机）：真实 AMap/Firebase/JPush/LiveKit 原生与供应商
/// 实网流量须授权真机/浏览器环境门，本文件只证本地调用边界。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_client.dart' as imboy_http;
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/location/widget.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';
import 'package:imboy/page/chat/widget/extra_item.dart';
import 'package:imboy/service/jpush_flutter_binding.dart';
import 'package:imboy/service/optional_sdk_consent.dart';
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/rtc_room_api.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';

import '../helper/fake_webview_platform.dart';

/// AMap 原生定位插件通道（amap_flutter_location_plus）。
const _amapMethodChannel = MethodChannel('amap_flutter_location');
const _amapStreamChannel = MethodChannel('amap_flutter_location_stream');

class _CountingPushChannel implements JPushPluginChannel {
  int setups = 0;
  int launches = 0;
  int reads = 0;
  Future<String> registration = Future.value('');

  /// 读钩子：把「撤回」精确挂在第一次真实读取上（微任务时序否则会早于
  /// initialize 的同意快照，把 reads 打成 0 而非验证撤回中止）。
  void Function()? onRead;

  @override
  void setup({required bool production, required String channel}) => setups++;

  @override
  void registerHandlers({
    Future<void> Function(Map<String, dynamic> event)? onOpenNotification,
    Future<void> Function(Map<String, dynamic> event)? onReceiveNotification,
    Future<void> Function(Map<String, dynamic> event)? onConnected,
  }) {}

  @override
  Future<String> fetchRegistrationId() {
    reads++;
    onRead?.call();
    return registration;
  }

  @override
  Future<Map<dynamic, dynamic>> fetchLaunchNotification() async {
    launches++;
    return {};
  }
}

class _CountingGeolocator extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int positionCalls = 0;
  int lastKnownCalls = 0;
  Object? positionError;
  Position? position;
  Position? lastKnown;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionCalls++;
    if (positionError != null) throw positionError!;
    return position!;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    lastKnownCalls++;
    return lastKnown;
  }
}

Position _position(double lat, double lng) => Position(
  longitude: lng,
  latitude: lat,
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// 记录后端 HTTP 出口（零外呼断言用）。
class _RecordingBackendAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString('{"code":0,"msg":"","payload":{}}', 200);
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingHttpOverrides extends HttpOverrides {
  int clients = 0;
  final onRequest = <Uri>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return _NeverConnectingClient(this);
  }
}

class _NeverConnectingClient implements HttpClient {
  _NeverConnectingClient(this.host);
  final _RecordingHttpOverrides host;

  /// Dio 的 IOHttpClientAdapter 会缓存首个 HttpClient 并跨请求复用，
  /// clients 计数只在首个触发其创建的测试内 +1（本文件串行共享 AMapApi
  /// 的静态 _dio）。以全局 openUrl 尝试计数为准（setUp 清零），才能断言
  /// 「每次调用恰好一次传输尝试、无重试风暴」。
  static int openUrlAttempts = 0;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    openUrlAttempts++;
    host.onRequest.add(url);
    throw const SocketException('blocked in test');
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 记录 joinRoom 调用的 RtcRoomApi 替身（同 p2p_call_livekit_test 惯用法）。
class _FakeRtcRoomApi extends RtcRoomApi {
  int joinCalls = 0;
  Map<String, String>? joinRoomResult = const {
    'wsUrl': 'wss://rtc.example.com/room',
    'token': 'fake-jwt',
    'roomName': 'c2c_117_52278',
  };

  @override
  Future<Map<String, String>?> joinRoom({
    required String kind,
    required String targetId,
    String? did,
  }) async {
    joinCalls++;
    return joinRoomResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final amapCalls = <String>[];
  final amapStreamCalls = <String>[];
  late GeolocatorPlatform originalGeolocator;
  final geolocator = _CountingGeolocator();
  final backend = _RecordingBackendAdapter();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    currentEnv = 'local';
    AMapHelper.grantOverrideForTest = null;
    amapCalls.clear();
    amapStreamCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_amapMethodChannel, (call) {
          amapCalls.add(call.method);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_amapStreamChannel, (call) {
          amapStreamCalls.add(call.method);
          return null;
        });
    originalGeolocator = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = geolocator;
    geolocator
      ..enabled = true
      ..permission = LocationPermission.whileInUse
      ..permissionRequests = 0
      ..positionCalls = 0
      ..lastKnownCalls = 0
      ..positionError = null
      ..position = _position(23, 113)
      ..lastKnown = null;
    backend.paths.clear();
    _NeverConnectingClient.openUrlAttempts = 0;
    imboy_http.HttpClient.adapterForTest = backend;
  });

  tearDown(() async {
    AMapHelper.grantOverrideForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_amapMethodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_amapStreamChannel, null);
    GeolocatorPlatform.instance = originalGeolocator;
    imboy_http.HttpClient.adapterForTest = null;
    AppFeatureRegistry.replaceSnapshotForTest({});
  });

  Future<void> loginWithPushConsent(int uid) async {
    await StorageService.to.setString(Keys.currentUid, uid.toString());
    await OptionalSdkConsent.instance.setGranted(OptionalSdkPurpose.push, true);
  }

  group('FL-17 A. 地图关闭（无授权）零调用', () {
    test('AMap 插件边界：无授权时工厂/隐私/API key/定位全部零原生调用', () async {
      expect(AMapHelper.grant, isNull, reason: 'host 平台守卫且无授权');
      // 工厂懒初始化路径：grant null → 惰性实例，不触发 init/setApiKey。
      final helper = AMapHelper();
      expect(await helper.startLocation(), isNull);
      AMapHelper.updatePrivacyShow(true, true);
      AMapHelper.updatePrivacyAgree(true);
      AMapHelper.setApiKey();
      AMapHelper.init();
      AMapHelper.stopForConsent();
      await pumpEventQueue();
      expect(amapCalls, isEmpty, reason: '插件方法通道必须零调用');
      expect(amapStreamCalls, isEmpty, reason: '定位流不得订阅');
    });

    test('POI REST 与静态图在 HTTP 之前被拒（零外联）', () async {
      final network = _RecordingHttpOverrides();
      await HttpOverrides.runZoned(() async {
        await expectLater(
          AMapApi.getAmapPoi('113.0,23.0', '020000', 10, 1),
          throwsStateError,
        );
        await expectLater(
          AMapApi.getMapByKeyword('kw', '020000', '440100', true, 10, 1),
          throwsStateError,
        );
        expect(
          await AMapApi.fetchStaticMapBytes(latitude: 23, longitude: 113),
          isNull,
        );
      }, createHttpClient: network.createHttpClient);
      expect(network.clients, 0, reason: '授权检查在任何 HTTP 之前');
    });

    testWidgets('地点选择器渲染占位页：WebView 脚本/桥/POI 全零', (tester) async {
      final network = _RecordingHttpOverrides();
      final webview = FakeWebViewPlatform();
      WebViewPlatform.instance = webview;
      await HttpOverrides.runZoned(
        () => tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: Material(
                child: MapLocationPicker(
                  arguments: {
                    'lat': 23.0,
                    'lng': 113.0,
                    'citycode': '440100',
                    'isMapImage': false,
                  },
                ),
              ),
            ),
          ),
        ),
        createHttpClient: network.createHttpClient,
      );
      await tester.pump();
      expect(
        find.text(t.common.buttonConfirm),
        findsOneWidget,
        reason: '无授权时返回明确占位确认页',
      );
      expect(network.clients, 0);
      expect(webview.html, isNull, reason: '不得加载 AMap JS HTML');
      expect(webview.channels, isEmpty, reason: '不得注册 JS 桥');
      expect(webview.scripts, isEmpty);
      expect(webview.requests, isEmpty);
    });
  });

  group('FL-17 B. 授权撤回释放定位流', () {
    test('scope 变化 → stopLocation + destroy 各一次且不再新增订阅', () async {
      final tokenA = Object();
      AMapHelper.grantOverrideForTest = tokenA;
      AMapHelper(); // 工厂建立 active 订阅（懒初始化路径）
      expect(amapStreamCalls, ['listen']);
      expect(amapCalls, isEmpty, reason: 'host 上 init/setApiKey 受 OS 守卫');

      // 撤回：授权对象更替（同一账号撤回后 grant 身份变化）。
      AMapHelper.grantOverrideForTest = Object();
      AMapHelper.clearIfScopeChanged();
      expect(amapCalls, containsAllInOrder(['stopLocation', 'destroy']));
      expect(
        amapCalls.where((m) => m == 'stopLocation'),
        hasLength(1),
        reason: '释放必须幂等：重复 scope 复查不重复 stop',
      );
      AMapHelper.clearIfScopeChanged();
      expect(amapCalls.where((m) => m == 'stopLocation'), hasLength(1));
      expect(amapStreamCalls, ['listen'], reason: '撤回后不得重新订阅');
    });
  });

  group('FL-17 C. 已授权路径：有界尝试与降级', () {
    test('POI 请求单发：一次传输失败即止，无自动重试风暴', () async {
      AMapHelper.grantOverrideForTest = Object();
      final network = _RecordingHttpOverrides();
      final pending = HttpOverrides.runZoned(
        () => AMapApi.getAmapPoi('113.0,23.0', '020000', 10, 1),
        createHttpClient: network.createHttpClient,
      );
      await expectLater(pending, throwsA(anything));
      await pumpEventQueue();
      expect(network.clients, 1, reason: 'dio 无重试拦截器：仅一次连接尝试');
    });

    test('静态图传输失败降级为 null（发送流程不中断）', () async {
      AMapHelper.grantOverrideForTest = Object();
      final network = _RecordingHttpOverrides();
      final bytes = await HttpOverrides.runZoned(
        () => AMapApi.fetchStaticMapBytes(latitude: 23, longitude: 113),
        createHttpClient: network.createHttpClient,
      );
      expect(bytes, isNull);
      // Dio 复用缓存 HttpClient（首见于此前的 POI 用例 zone），本 zone 的
      // clients 计数为 0 是预期；传输尝试以全局计数断言：恰好 1 次、无重试。
      expect(
        _NeverConnectingClient.openUrlAttempts,
        1,
        reason: '静态图传输失败单发即止，不自动重试',
      );
    });

    test('geolocator：权限 denied/deniedForever → 零定位调用', () async {
      for (final denied in [
        LocationPermission.denied,
        LocationPermission.deniedForever,
      ]) {
        geolocator.permission = denied;
        geolocator.positionCalls = 0;
        geolocator.permissionRequests = 0;
        geolocator.lastKnownCalls = 0;
        final result = await LocationService().getCurrentPosition();
        expect(result, isNull, reason: '$denied 不产生坐标');
        expect(geolocator.positionCalls, 0, reason: '$denied 零实时定位调用');
        expect(geolocator.lastKnownCalls, 0);
      }
    });

    test('geolocator：系统定位服务关闭 → 零定位调用', () async {
      geolocator.enabled = false;
      final result = await LocationService().getCurrentPosition();
      expect(result, isNull);
      expect(geolocator.positionCalls, 0);
    });

    test('geolocator：命中缓存时零新调用（preferLastKnown）', () async {
      geolocator.lastKnown = _position(22.8, 112.9);
      final result = await LocationService().getCurrentPosition(
        preferLastKnown: true,
      );
      expect(result, isNotNull);
      expect(result!.latitude, 22.8);
      expect(geolocator.positionCalls, 0, reason: '缓存命中不发起实时定位');
      expect(geolocator.lastKnownCalls, 1);
    });

    test('geolocator：实时定位失败降级 lastKnown，再失败返回 null 不崩溃', () async {
      geolocator.positionError = const SocketException('gps lost');
      expect(await LocationService().getCurrentPosition(), isNull);
      expect(geolocator.positionCalls, 1);
      expect(geolocator.lastKnownCalls, 1);

      geolocator.lastKnown = _position(22.5, 112.5);
      final recovered = await LocationService().getCurrentPosition();
      expect(recovered, isNotNull, reason: 'lastKnown 可用时不虚报失败');
      expect(recovered!.latitude, 22.5);
      expect(geolocator.positionCalls, 2);
    });

    test('geolocator：正常授权下单次定位成功', () async {
      final result = await LocationService().getCurrentPosition();
      expect(result, isNotNull);
      expect(geolocator.positionCalls, 1);
    });
  });

  group('FL-17 D. 推送消费者：零调用与重试预算', () {
    test('JPush 构建开关关（缺省无 IMBOY_JPUSH_ENABLED）：同意存在也零插件调用', () async {
      final channel = _CountingPushChannel();
      // plugin 注入 → readConsent 缺省 () => true：只有 enabledCheck（默认
      // 构建开关）能把调用挡在边界外。
      final wiring = JPushSdkWiring.withDefaults(plugin: channel);
      await wiring.initialize();
      await pumpEventQueue();
      expect((channel.setups, channel.launches, channel.reads), (0, 0, 0));
    });

    test('FCM：未支持平台（host）零网络、零 Firebase 调用', () async {
      PushNotificationService.instance.resetForTest();
      await PushNotificationService.instance.initialize();
      expect(PushNotificationService.instance.fcmEnabled, isFalse);
      expect(backend.paths, isEmpty, reason: '未支持平台不得触网');
    });

    test('无同意时 synchronizeConsent 零启动；授权后启动一次；撤回停一次', () async {
      var starts = 0;
      var stops = 0;
      final service = PushNotificationService.forLifecycleTest(
        start: () async => starts++,
        stop: () async => stops++,
      );
      await service.synchronizeConsent();
      expect(starts, 0, reason: '无同意/未登录：零原生启动');

      await loginWithPushConsent(1001);
      await service.synchronizeConsent();
      expect(starts, 1);

      final withdrawal = service.updateConsent(false);
      await expectLater(withdrawal, completes);
      expect(stops, 1, reason: '撤回：停一次');
      await service.synchronizeConsent();
      expect(starts, 1, reason: '撤回后不得自行重启');
    });

    test('RID 预热预算：至多 N 次拉取，时间延续不扩预算（不风暴）', () {
      fakeAsync((async) {
        final channel = _CountingPushChannel();
        final grant = Object();
        final wiring = JPushSdkWiring.withDefaults(
          plugin: channel,
          enabledCheck: () => true,
          readConsent: () => grant,
          registrationIdPollAttempts: 3,
        );
        wiring.initialize();
        async.flushTimers();
        expect(channel.reads, 3, reason: '预算 3 次封顶（rid 恒空场景）');
        async.elapse(const Duration(seconds: 120));
        expect(channel.reads, 3, reason: '预算耗尽后不再产生新轮询');
      });
    });

    test('RID 预热：撤回（同意消失）中止轮询', () {
      fakeAsync((async) {
        final channel = _CountingPushChannel();
        Object? grant = Object();
        channel.onRead = () => grant = null; // 第一次真实读取即撤回
        final wiring = JPushSdkWiring.withDefaults(
          plugin: channel,
          enabledCheck: () => true,
          readConsent: () => grant,
          registrationIdPollAttempts: 3,
        );
        wiring.initialize();
        async.flushTimers();
        expect(channel.reads, 1, reason: '撤回后剩余预算立即失效');
        async.elapse(const Duration(seconds: 120));
        expect(channel.reads, 1);
      });
    });

    test('RID 预算不因重复 initialize（同授权）重置', () {
      fakeAsync((async) {
        final channel = _CountingPushChannel();
        final grant = Object();
        final wiring = JPushSdkWiring.withDefaults(
          plugin: channel,
          enabledCheck: () => true,
          readConsent: () => grant,
          registrationIdPollAttempts: 3,
        );
        wiring.initialize();
        async.flushTimers();
        expect(channel.reads, 3);
        // 页面重建/重复回调触发 initialize：同授权幂等，不重启预热。
        wiring.initialize();
        async.flushTimers();
        async.elapse(const Duration(seconds: 120));
        expect(channel.reads, 3);
      });
    });
  });

  group('FL-17 E. RTC fail-closed 与 join 预算', () {
    test('feature registry：rtc 缺省 fail-closed，远程不能重开未选入的 rtc_group', () {
      AppFeatureRegistry.replaceSnapshotForTest({});
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.rtc),
        isFalse,
        reason: '空 snapshot：默认关闭',
      );
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: false});
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.rtc), isFalse);
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: true});
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.rtc), isTrue);

      expect(
        compiledProductFeatures.contains(FeatureKeys.rtcGroup),
        isFalse,
        reason: '本构建组合清单未选入群通话域',
      );
      AppFeatureRegistry.replaceSnapshotForTest({
        FeatureKeys.rtc: true,
        FeatureKeys.rtcGroup: true,
      });
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.rtcGroup),
        isFalse,
        reason: '远程 snapshot 不得重开组合外能力',
      );
    });

    testWidgets('群通话入口在远程重开尝试下保持不可达（零 joinRoom 路径）', (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest({
        FeatureKeys.rtc: true,
        FeatureKeys.rtcGroup: true,
      });
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            child: MaterialApp(
              home: Material(
                child: ExtraItems(type: 'C2G', options: const {'to': '3001'}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // 惯用法对齐 extra_items_feature_gate_test：按 ExtraItem 类型取 title
      // 集合断言（文本 finder 受分页/布局影响）。
      final titles = tester
          .widgetList<ExtraItem>(find.byType(ExtraItem))
          .map((item) => item.title)
          .toSet();
      expect(
        titles.contains(t.common.groupCall),
        isFalse,
        reason: '组合清单 fail-closed：入口不渲染即零 joinRoom',
      );
      expect(titles.contains(t.main.album), isTrue, reason: '无关基础能力不受影响');
    });

    test('C2C connect：并发调用收敛为单次 joinRoom + 单次 Room 接入', () async {
      const peerId = '52278';
      final api = _FakeRtcRoomApi();
      var roomConnects = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(p2pCallScreenProvider.notifier);
      notifier
        ..rtcApiOverride = api
        ..roomConnectOverride = (wsUrl, token) async {
          roomConnects++;
          return true;
        }
        ..initSession(
          newSession: WebRTCSession(peerId: peerId, sid: '117-$peerId'),
          newMedia: 'video',
          isCaller: true,
          newMsgId: 'mid-fl17-1',
        );

      final results = await Future.wait([
        for (var i = 0; i < 5; i++) notifier.connect(peerId: peerId),
      ]);
      expect(results.every((ok) => ok), isTrue);
      expect(api.joinCalls, 1, reason: 'in-flight 闩：重复点击零新增签票');
      expect(roomConnects, 1);
    });

    test('C2C joinRoom 拒绝：降级 false，无自动重试', () async {
      const peerId = '52278';
      final api = _FakeRtcRoomApi()..joinRoomResult = null;
      var roomConnects = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(p2pCallScreenProvider.notifier);
      notifier
        ..rtcApiOverride = api
        ..roomConnectOverride = (wsUrl, token) async {
          roomConnects++;
          return true;
        }
        ..initSession(
          newSession: WebRTCSession(peerId: peerId, sid: '117-$peerId'),
          newMedia: 'video',
          isCaller: false,
          newMsgId: 'mid-fl17-2',
        );

      expect(await notifier.connect(peerId: peerId), isFalse);
      expect(roomConnects, 0, reason: '签票失败不得假接通');
      await pumpEventQueue();
      expect(api.joinCalls, 1, reason: '失败后无自动重试（用户显式重试才计一次）');
    });

    test('C2C 挂断后：迟到信令被忽略，connect 零 joinRoom/零接入', () async {
      const peerId = '52278';
      final api = _FakeRtcRoomApi();
      var roomConnects = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(p2pCallScreenProvider.notifier);
      notifier
        ..rtcApiOverride = api
        ..roomConnectOverride = (wsUrl, token) async {
          roomConnects++;
          return true;
        }
        ..initSession(
          newSession: WebRTCSession(peerId: peerId, sid: '117-$peerId'),
          newMedia: 'video',
          isCaller: true,
          newMsgId: 'mid-fl17-3',
        );
      final states = <String>[];
      notifier.onCallStateChange = (s, state) => states.add(state.name);

      await notifier.cleanUpP2P();
      final late = WebRTCSignalingModel(
        msgId: 'mid-fl17-3',
        type: 'WEBRTC_ANSWER',
        from: peerId,
        to: '117',
        payload: const {},
      );
      await notifier.onMessageP2P(
        WebRTCSession(peerId: peerId, sid: '117-$peerId'),
        late,
      );
      expect(states, isEmpty, reason: '关闭中迟到 answer 不得广播接通');
      expect(await notifier.connect(peerId: peerId), isFalse);
      expect(api.joinCalls, 0, reason: '挂断后零签票请求');
      expect(roomConnects, 0, reason: '挂断后零 Room.connect');
    });
  });

  group('FL-17 F. 接线源码合同（readAsStringSync 惯用法）', () {
    final initSrc = File('lib/config/init.dart').readAsStringSync();
    final extraItemSrc = File('lib/page/chat/widget/extra_item.dart')
        .readAsStringSync();

    test('会话切换同步 AMap scope 与推送同意；dispose 双释放', () {
      final refreshIdx = initSrc.indexOf('static void _refreshOptionalPush()');
      expect(refreshIdx, greaterThan(0));
      final refreshBody = initSrc.substring(refreshIdx, refreshIdx + 500);
      expect(refreshBody.contains('AMapHelper.clearIfScopeChanged()'), isTrue);
      expect(refreshBody.contains('synchronizeConsent'), isTrue);
      expect(
        initSrc.contains('authSessionReader.addListener(_refreshOptionalPush)'),
        isTrue,
        reason: '_initializeServices 必须挂会话监听（native）',
      );
      expect(
        initSrc.contains(
          'authSessionReader.removeListener(_refreshOptionalPush)',
        ),
        isTrue,
        reason: 'dispose 必须摘除监听',
      );
      expect(
        initSrc.contains('PushNotificationService.instance.dispose()'),
        isTrue,
        reason: 'dispose 必须释放推送服务',
      );
    });

    test('群通话入口 await 前后双重复查 rtcGroup（迟到回调不复活连接）', () {
      final joinIdx = extraItemSrc.indexOf('Future<void> _joinGroupCall');
      expect(joinIdx, greaterThan(0));
      final body = extraItemSrc.substring(
        joinIdx,
        extraItemSrc.indexOf('Navigator.of(context).push', joinIdx),
      );
      final checks = 'AppFeatureRegistry.isEnabled(FeatureKeys.rtcGroup)'
          .allMatches(body)
          .length;
      expect(
        checks,
        greaterThanOrEqualTo(2),
        reason: 'joinRoom 前后都要复查 feature 门',
      );
      expect(body.indexOf('joinRoom'), greaterThan(0));
    });
  });
}
