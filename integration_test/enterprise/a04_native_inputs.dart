import 'dart:io';

import 'package:integration_test/integration_test.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:imboy/modules/organization/presentation/human_directory_page.dart';

import 'a04_directory_fault_adapter.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';

const a04NativeInputs = bool.fromEnvironment('A04_NATIVE_INPUTS');

bool isA04OwnedBundle(String bundle) =>
    bundle == 'pub.imboy.app.v32qa' ||
    bundle.startsWith('pub.imboy.app.v32a04.');

Future<void> verifyA04Bundle() async {
  final bundle = const String.fromEnvironment('A04_OWNED_BUNDLE');
  expect(
    isA04OwnedBundle(bundle),
    isTrue,
    reason: 'owned test bundle required',
  );
  expect((await PackageInfo.fromPlatform()).packageName, bundle);
  if (Platform.isAndroid) {
    expect((await DeviceInfoPlugin().androidInfo).isPhysicalDevice, isTrue);
  }
  debugPrint('A04_OWNED_APP pid=$pid bundle=$bundle');
}

Future<void> _nativeWait(
  WidgetTester tester,
  String name,
  bool Function() satisfied,
) async {
  debugPrint('A04_NATIVE_INPUT_READY $name pid=$pid');
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (!satisfied() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(satisfied(), isTrue, reason: 'actual host input required: $name');
  expect(tester.takeException(), isNull);
  debugPrint('A04_NATIVE_INPUT_PASS $name');
}

Future<void> verifyA04Window(
  WidgetTester tester, {
  required bool narrow,
}) async {
  Size actual() {
    final view = tester.binding.platformDispatcher.views.single;
    return view.physicalSize / view.devicePixelRatio;
  }

  await _nativeWait(
    tester,
    narrow ? 'window_narrow_400' : 'window_wide_1200',
    () => narrow
        ? actual().width >= 380 && actual().width <= 440
        : actual().width >= 1100,
  );
  debugPrint('A04_NATIVE_WINDOW logical=${actual()}');
}

Future<void> verifyA04Viewport(WidgetTester tester) async {
  if (Platform.isMacOS) return verifyA04Window(tester, narrow: true);
  final view = tester.binding.platformDispatcher.views.single;
  final size = view.physicalSize / view.devicePixelRatio;
  expect(size.width, inInclusiveRange(300, 600));
  expect(size.height, greaterThan(size.width));
  debugPrint('A04_ANDROID_VIEWPORT logical=$size dpr=${view.devicePixelRatio}');
}

Future<void> verifyA04AndroidTouch(WidgetTester tester) async {
  final zoom = find.byKey(const ValueKey('org-chart-zoom-in'));
  var touches = 0;
  void observe(PointerEvent event) {
    if (event is PointerDownEvent && event.kind == PointerDeviceKind.touch) {
      touches++;
    }
  }

  final viewer = find.byKey(const ValueKey('org-chart-canvas'));
  double scale() => tester
      .widget<InteractiveViewer>(viewer)
      .transformationController!
      .value
      .getMaxScaleOnAxis();
  final before = scale();
  final point = tester.getCenter(zoom);
  final dpr = tester.binding.platformDispatcher.views.single.devicePixelRatio;
  final previous = tester.binding.shouldPropagateDevicePointerEvents;
  tester.binding.shouldPropagateDevicePointerEvents = true;
  GestureBinding.instance.pointerRouter.addGlobalRoute(observe);
  try {
    debugPrint(
      'A04_ANDROID_TOUCH_TARGET x=${point.dx * dpr} y=${point.dy * dpr}',
    );
    // No tester gesture is generated while this observer waits for OS input.
    await _nativeWait(
      tester,
      'android_touch_zoom',
      () => touches > 0 && scale() > before,
    );
    debugPrint(
      'A04_ANDROID_TOUCH_PASS events=$touches scale=$before→${scale()}',
    );
  } finally {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(observe);
    tester.binding.shouldPropagateDevicePointerEvents = previous;
  }
}

Future<void> verifyA04Keyboard(WidgetTester tester, Finder input) async {
  var keyDowns = 0;
  bool observe(KeyEvent event) {
    if (event is KeyDownEvent) keyDowns++;
    return false;
  }

  HardwareKeyboard.instance.addHandler(observe);
  try {
    await tester.tap(input);
    await _nativeWait(
      tester,
      'keyboard_type_a04',
      () =>
          keyDowns >= 3 &&
          tester
                  .widget<EditableText>(
                    find.descendant(
                      of: input,
                      matching: find.byType(EditableText),
                    ),
                  )
                  .controller
                  .text ==
              'a04',
    );
    debugPrint('A04_NATIVE_KEYBOARD key_downs=$keyDowns');
    await tester.enterText(input, '');
    await tester.pump(const Duration(milliseconds: 400));
  } finally {
    HardwareKeyboard.instance.removeHandler(observe);
  }
}

Future<void> verifyA04Trackpad(WidgetTester tester, Finder canvas) async {
  var signals = 0;
  String? eventType;
  void observe(PointerEvent event) {
    if (event is PointerScrollEvent || event is PointerPanZoomUpdateEvent) {
      signals++;
      eventType = '${event.runtimeType}/${event.kind.name}';
    }
  }

  double scale() => tester
      .widget<InteractiveViewer>(canvas)
      .transformationController!
      .value
      .getMaxScaleOnAxis();
  final before = scale();
  GestureBinding.instance.pointerRouter.addGlobalRoute(observe);
  try {
    debugPrint('A04_NATIVE_SCROLL_TARGET ${tester.getCenter(canvas)}');
    await _nativeWait(
      tester,
      'trackpad_scroll_on_chart',
      () => signals > 0 && (scale() - before).abs() > .00001,
    );
    debugPrint(
      'A04_NATIVE_SCROLL events=$signals type=$eventType scale=$before→${scale()}',
    );
  } finally {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(observe);
  }
}

Future<void> verifyA04Workspace(WidgetTester tester) async {
  const expected = String.fromEnvironment('NONOA_WORKSPACE_A');
  expect(expected, isNotEmpty);
  await _nativeWait(
    tester,
    'owned_default_workspace_restored',
    () =>
        ProviderScope.containerOf(navigatorKey.currentContext!)
            .read(currentWorkspaceProvider)
            ?.id ==
        expected,
  );
  expect(find.textContaining('V32 A04工作区A'), findsWidgets);
}

Future<A04ObservedDirectorySource> observeA04ChartSource(
  WidgetTester tester,
) async {
  final finder = find.byType(OrganizationChartPage);
  final page = tester.widget<OrganizationChartPage>(finder);
  final observed = A04ObservedDirectorySource(page.source);
  // Only replace the existing test-injectable data source, keeping the real route.
  final element = tester.element(finder);
  element.owner!.buildScope(
    element,
    () => element.update(
      OrganizationChartPage(
        key: page.key,
        accountKey: page.accountKey,
        organizationId: page.organizationId,
        organizationName: page.organizationName,
        source: observed,
        onAccessDenied: page.onAccessDenied,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return observed;
}

/// macOS 的 integration_test 平台未实现 captureScreenshot；取证截图由 host
/// 侧脚本监听 [AI_SCREENSHOT] 标记后经 VM 服务协议 ext.flutter.screenshot
/// 抓取真实渲染帧（与仓内 Android 采集脚本同一标记协议）。
bool _androidSurfaceConverted = false;

Future<void> markShot(WidgetTester tester, String name) async {
  debugPrint('[AI_SCREENSHOT] $name');
  if (Platform.isAndroid && !_androidSurfaceConverted) {
    await IntegrationTestWidgetsFlutterBinding.instance
        .convertFlutterSurfaceToImage();
    _androidSurfaceConverted = true;
    await tester.pump();
  }
  try {
    await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(name);
  } on Exception {
    // `flutter test` 模式 macOS 无 captureScreenshot 平台通道实现；
    // `flutter drive` 模式经 driver 响应回传，异常仅跳过取证不失败旅程。
  }
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
}
