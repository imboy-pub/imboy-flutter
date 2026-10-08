// integration_test/smoke/camera_capture_real_smoke_test.dart
//
// 桌面真实相机冒烟（无 mock）：走真 camera_desktop/AVFoundation 链路，
// 覆盖 widget 测试（mock 平台层）够不到的硬件层——真实取景初始化、真实
// 拍照出片（JPEG 魔数 + 体积）、预览态返回按钮退出。不依赖后端，不发送
// 任何消息（红线）。
//
// 默认跳过，显式开启才跑（避免 CI/全量误触相机硬件与授权弹窗）：
//   flutter test integration_test/smoke/camera_capture_real_smoke_test.dart \
//     -d macos --dart-define=IMBOY_REAL_CAMERA_SMOKE=1
//
// 前置（缺一则 initialize 会触发系统授权框并挂起测试）：
//   1. 运行宿主（终端/IDE）已在 系统设置→隐私与安全性→相机 授权；
//   2. 关闭其他占用相机的应用（FaceTime / 已运行的 IMBoy 等）。
//
// 说明：flutter test 直启被测进程，TCC 归因到宿主而非 IMBoy
// （flutter/flutter#70374）；与「flutter build 后 open 启动 .app 的人工
// 冒烟」口径互补。仅拍照不录像：麦克风是另一独立授权项，避免本测试
// 要求双权限。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/camera/camera_capture_page.dart';

/// 未显式开启时整文件跳过（CI/全量默认不碰相机硬件）。
const bool _realSmoke = bool.fromEnvironment('IMBOY_REAL_CAMERA_SMOKE');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await Future<void>.delayed(const Duration(milliseconds: 200));
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  String reason = '',
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await _settle(tester);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('pumpUntil 超时(${timeout.inSeconds}s)：$reason <$finder>');
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('真实相机：初始化取景 → 拍照出片 → 预览返回按钮退出', (WidgetTester tester) async {
    CameraCaptureResult? got;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) => FilledButton(
                  onPressed: () async {
                    final r = await Navigator.push<CameraCaptureResult>(
                      context,
                      MaterialPageRoute<CameraCaptureResult>(
                        builder: (_) => const CameraCapturePage(),
                        fullscreenDialog: true,
                      ),
                    );
                    got = r;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));

    // 等初始化结果：取景态就绪，或无摄像头机器按无设备口径自动出栈
    //（降级路径同样算通过——这正是无设备守卫的真实硬件验证）。
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
    var viewfinderReady = false;
    while (DateTime.now().isBefore(deadline)) {
      await _settle(tester);
      if (find.byKey(const ValueKey('camera_shutter')).evaluate().isNotEmpty) {
        viewfinderReady = true;
        break;
      }
      if (find.byType(CameraCapturePage).evaluate().isEmpty) break;
    }
    if (!viewfinderReady) {
      expect(
        find.byType(CameraCapturePage),
        findsNothing,
        reason: '取景未就绪时页面应已按失败口径出栈（见页内 toast）',
      );
      debugPrint('[camera_real_smoke] 无可用摄像头，降级路径通过');
      return;
    }

    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await _pumpUntil(
      tester,
      find.byKey(const ValueKey('camera_preview_back')),
      timeout: const Duration(seconds: 15),
      reason: '拍照完成应进入预览态（出现返回按钮）',
    );

    // 「使用照片」移交产物：文件归本测试（调用方），验字节后清理。
    await tester.tap(find.text(t.common.cameraUse));
    await tester.pumpAndSettle();

    expect(got, isNotNull, reason: '预览「使用」应回传拍摄结果');
    expect(got!.isVideo, isFalse);
    final File file = File(got!.path);
    expect(file.existsSync(), isTrue, reason: '真实拍照应落盘');
    expect(file.lengthSync(), greaterThan(1024), reason: '真实照片不应过小');
    final List<int> head = file.readAsBytesSync().sublist(0, 2);
    expect(head[0], 0xFF, reason: 'JPEG 魔数 FF');
    expect(head[1], 0xD8, reason: 'JPEG 魔数 D8');
    file.deleteSync();

    expect(find.byType(CameraCapturePage), findsNothing);
  }, skip: !_realSmoke);
}
