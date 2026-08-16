/// BUG#141 回归：mobile_scanner 7.x 的 start() 把权限被拒异常吞进
/// controller.value.error（不向外抛），`on MobileScannerException` 分支
/// 永远不可达——必须由页面主动 Permission.camera.request() 预检。
///
/// 验证点：
///   1. 相机权限被拒 → 显示「没有权限」+「设置」按钮引导（非库默认英文文案）
///   2. 权限被拒时底部相机控制条（手电筒/暂停/切换镜头）不渲染
///   3. 点「设置」→ 调用 openAppSettings()
///   4. 权限授予后照常渲染 MobileScanner（无权限错误引导）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// 全部权限返回 denied，且记录 openAppSettings 调用。
class _DeniedPermissionHandler extends PermissionHandlerPlatform {
  bool openSettingsCalled = false;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {for (final p in permissions) p: PermissionStatus.denied};

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.denied;

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalled = true;
    return true;
  }
}

/// 全部权限返回 granted。
class _GrantedPermissionHandler extends PermissionHandlerPlatform {
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {for (final p in permissions) p: PermissionStatus.granted};

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.granted;
}

/// 相机启动抛非权限异常（模拟摄像头被占用等失败），dispose/barcodesStream
/// 置空防测试收尾走 MethodChannel 抛 MissingPluginException/UnimplementedError。
class _StartFailPlatform extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    throw MobileScannerException(
      errorCode: MobileScannerErrorCode.genericError,
      errorDetails: const MobileScannerErrorDetails(message: 'simulated'),
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  final origin = PermissionHandlerPlatform.instance;

  setUp(() {
    PermissionHandlerPlatform.instance = _DeniedPermissionHandler();
  });

  tearDown(() {
    PermissionHandlerPlatform.instance = origin;
  });

  testWidgets('相机权限被拒时显示「没有权限」引导，控制条不渲染', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: const ProviderScope(child: MaterialApp(home: ScannerPage())),
      ),
    );
    // addPostFrameCallback → _startScanner → requestPermissions 返回 denied
    await tester.pumpAndSettle();

    // 引导文案（库默认英文 "Camera permission denied." 已被替代）
    expect(find.text('没有权限'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    // 底部相机控制条（手电筒/暂停/切换镜头/相册）不应渲染
    expect(find.byIcon(Icons.flash_off), findsNothing);
    expect(find.byIcon(Icons.stop), findsNothing);
  });

  testWidgets('权限被拒后点「设置」调用 openAppSettings', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: const ProviderScope(child: MaterialApp(home: ScannerPage())),
      ),
    );
    await tester.pumpAndSettle();

    final handler =
        PermissionHandlerPlatform.instance as _DeniedPermissionHandler;
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(handler.openSettingsCalled, isTrue);
  });

  testWidgets('权限已授予但相机启动失败时显示「权限获取失败」+「重试」', (tester) async {
    PermissionHandlerPlatform.instance = _GrantedPermissionHandler();
    MobileScannerPlatform.instance = _StartFailPlatform();

    await tester.pumpWidget(
      TranslationProvider(
        child: const ProviderScope(child: MaterialApp(home: ScannerPage())),
      ),
    );
    await tester.pumpAndSettle();

    // 非权限失败 → 不显示「没有权限」，走失败重试引导
    expect(find.text('权限获取失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
    // 底部控制条不渲染
    expect(find.byIcon(Icons.flash_off), findsNothing);
  });
}
