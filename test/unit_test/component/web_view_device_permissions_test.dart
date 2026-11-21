import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/web_view.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helper/fake_webview_platform.dart';

class _Request extends PlatformWebViewPermissionRequest {
  _Request({Set<WebViewPermissionResourceType>? resourceTypes})
    : super(types: resourceTypes ?? {WebViewPermissionResourceType.camera});
  final events = <String>[];
  int get granted => events.where((event) => event == 'grant').length;
  int get denied => events.where((event) => event == 'deny').length;
  @override
  Future<void> grant() async => events.add('grant');
  @override
  Future<void> deny() async => events.add('deny');
}

/// 可编程系统相机权限：记录触发次数，按脚本返回授予/拒绝。
class _CameraPermissionPlatform extends PermissionHandlerPlatform
    with MockPlatformInterfaceMixin {
  _CameraPermissionPlatform(this.granted);
  final bool granted;
  int systemRequests = 0;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      granted ? PermissionStatus.granted : PermissionStatus.denied;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    systemRequests++;
    return {
      for (final permission in permissions)
        permission: granted
            ? PermissionStatus.granted
            : PermissionStatus.denied,
    };
  }
}

void main() {
  test('OA 设备能力必须显式启用且初始、当前、请求来源均匹配', () {
    bool allowed({
      bool enabled = true,
      String initial = 'https://imboy.pub/test_oa.html',
      String? current = 'https://imboy.pub/test_oa.html',
      String? origin,
    }) => WebViewPageState.allowsOaDevicePermissions(
      enabled: enabled,
      initialUrl: initial,
      currentUrl: current,
      requestOrigin: origin,
    );
    expect(allowed(origin: 'https://imboy.pub/'), isTrue);
    expect(allowed(enabled: false), isFalse);
    expect(allowed(current: null), isFalse);
    for (final value in [
      'https://thirdparty.test',
      'https://sub.imboy.pub',
      'http://imboy.pub',
      'https://imboy.pub:8443',
      'https://user@imboy.pub',
    ]) {
      expect(allowed(initial: value), isFalse);
      expect(allowed(current: value), isFalse);
      expect(allowed(origin: value), isFalse);
    }
  });

  testWidgets('普通网页相机请求明确拒绝，且不触发系统权限或 grant', (tester) async {
    final previous = WebViewPlatform.instance;
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) WebViewPlatform.instance = previous;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewPage('https://thirdparty.test', 'synthetic page'),
      ),
    );
    final request = _Request();
    platform.permission(request);
    await tester.pump();
    expect(request.denied, 1);
    expect(request.granted, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // P-01:LOCAL:01（Web 侧）—— OA 入口的相机请求按触发申请系统权限，
  // 系统授权且来源复核通过后才 grant。
  testWidgets('OA 相机请求在系统授权后 grant，且系统权限按触发申请', (tester) async {
    final previous = WebViewPlatform.instance;
    final previousPermissions = PermissionHandlerPlatform.instance;
    final platform = FakeWebViewPlatform();
    final permissions = _CameraPermissionPlatform(true);
    WebViewPlatform.instance = platform;
    PermissionHandlerPlatform.instance = permissions;
    addTearDown(() {
      if (previous != null) WebViewPlatform.instance = previous;
      PermissionHandlerPlatform.instance = previousPermissions;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewPage(
          'https://imboy.pub/test_oa.html',
          'synthetic OA',
          allowOaDevicePermissions: true,
        ),
      ),
    );
    await tester.pump();
    final request = _Request();
    platform.permission(request);
    await tester.pump();
    await tester.pump();
    expect(permissions.systemRequests, 1, reason: '权限按触发申请一次');
    expect(request.granted, 1);
    expect(request.denied, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // P-01:LOCAL:01（Web 侧）—— 系统层拒绝时不 grant：拒绝没有绕过路径。
  testWidgets('OA 相机请求在系统拒绝后明确 deny，不 grant', (tester) async {
    final previous = WebViewPlatform.instance;
    final previousPermissions = PermissionHandlerPlatform.instance;
    final platform = FakeWebViewPlatform();
    final permissions = _CameraPermissionPlatform(false);
    WebViewPlatform.instance = platform;
    PermissionHandlerPlatform.instance = permissions;
    addTearDown(() {
      if (previous != null) WebViewPlatform.instance = previous;
      PermissionHandlerPlatform.instance = previousPermissions;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewPage(
          'https://imboy.pub/test_oa.html',
          'synthetic OA',
          allowOaDevicePermissions: true,
        ),
      ),
    );
    await tester.pump();
    final request = _Request();
    platform.permission(request);
    await tester.pump();
    await tester.pump();
    expect(permissions.systemRequests, 1);
    expect(request.denied, 1);
    expect(request.granted, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // P-01:LOCAL:01/02（Web 侧）—— WebView 侧只按需放行相机这一种启用：
  // 麦克风或相机+麦克风混合请求即使在 OA 入口也一律拒绝。
  testWidgets('OA 页麦克风或混合类型设备请求一律拒绝', (tester) async {
    final previous = WebViewPlatform.instance;
    final previousPermissions = PermissionHandlerPlatform.instance;
    final platform = FakeWebViewPlatform();
    final permissions = _CameraPermissionPlatform(true);
    WebViewPlatform.instance = platform;
    PermissionHandlerPlatform.instance = permissions;
    addTearDown(() {
      if (previous != null) WebViewPlatform.instance = previous;
      PermissionHandlerPlatform.instance = previousPermissions;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewPage(
          'https://imboy.pub/test_oa.html',
          'synthetic OA',
          allowOaDevicePermissions: true,
        ),
      ),
    );
    await tester.pump();
    final microphone = _Request(
      resourceTypes: {WebViewPermissionResourceType.microphone},
    );
    final mixed = _Request(
      resourceTypes: {
        WebViewPermissionResourceType.camera,
        WebViewPermissionResourceType.microphone,
      },
    );
    platform.permission(microphone);
    await tester.pump();
    platform.permission(mixed);
    await tester.pump();
    expect(microphone.denied, 1);
    expect(microphone.granted, 0);
    expect(mixed.denied, 1);
    expect(mixed.granted, 0);
    expect(permissions.systemRequests, 0, reason: '类型不匹配不触发系统权限');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // P-01:LOCAL:01（Web 侧）—— OA 能力未启用时拒绝且完全不触发系统权限
  // 弹窗（不先申请后问，也不因域名恰好是 imboy.pub 而放行）。
  testWidgets('OA 能力未启用时相机请求拒绝且不触发系统权限', (tester) async {
    final previous = WebViewPlatform.instance;
    final previousPermissions = PermissionHandlerPlatform.instance;
    final platform = FakeWebViewPlatform();
    final permissions = _CameraPermissionPlatform(true);
    WebViewPlatform.instance = platform;
    PermissionHandlerPlatform.instance = permissions;
    addTearDown(() {
      if (previous != null) WebViewPlatform.instance = previous;
      PermissionHandlerPlatform.instance = previousPermissions;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewPage('https://imboy.pub/test_oa.html', 'synthetic OA'),
      ),
    );
    await tester.pump();
    final request = _Request();
    platform.permission(request);
    await tester.pump();
    expect(request.denied, 1);
    expect(request.granted, 0);
    expect(permissions.systemRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
// Tests exercise the already resolved WebView permission callback interface.
// ignore_for_file: depend_on_referenced_packages
