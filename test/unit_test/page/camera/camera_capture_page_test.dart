// CameraCapturePage 桌面拍摄页 widget 测试：mock 官方 camera_platform_interface。
//
// 覆盖：无设备友好降级自动出栈、初始化渲染取景（含模式切换 chips）、
// 拍照→预览→使用（isVideo=false）、重拍删除临时文件回取景、
// dual 视频模式录像徽标→停止→使用（isVideo=true）、videoOnly 直录、
// 未移交产物在关闭页面时清理、退出时控制器释放。
//
// camera_platform_interface 目前是 camera/camera_desktop 的传递依赖；
// 待 pubspec.yaml 空闲时把下面的 import 升级为 dev_dependencies 声明
// （届时移除 ignore 注释）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/camera/camera_capture_page.dart';

/// 1x1 PNG 字节（占位照片，可被 Image.file 真实解码）。
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
    'hwGA60e6kgAAAABJRU5ErkJggg==';

class _FakeCameraPlatform extends CameraPlatform {
  _FakeCameraPlatform({this.cameras = const [_backCamera]});

  static const CameraDescription _backCamera = CameraDescription(
    name: 'back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 0,
  );

  final List<CameraDescription> cameras;
  int createCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  String? photoPath;
  String? videoPath;

  final StreamController<DeviceOrientationChangedEvent> _orientation =
      StreamController<DeviceOrientationChangedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();
  final Map<int, StreamController<CameraInitializedEvent>> _initialized =
      <int, StreamController<CameraInitializedEvent>>{};

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings mediaSettings,
  ) async {
    createCalls++;
    return 1;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    // 控制器先挂 onCameraInitialized 监听再 await 本方法，此处事件不丢。
    _initialized
        .putIfAbsent(
          cameraId,
          StreamController<CameraInitializedEvent>.broadcast,
        )
        .add(
          CameraInitializedEvent(
            cameraId,
            1920,
            1080,
            ExposureMode.auto,
            true,
            FocusMode.auto,
            true,
          ),
        );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized
          .putIfAbsent(
            cameraId,
            StreamController<CameraInitializedEvent>.broadcast,
          )
          .stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      _orientation.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<XFile> takePicture(int cameraId) async => XFile(photoPath!);

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {
    startCalls++;
  }

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    stopCalls++;
    return XFile(videoPath!);
  }

  @override
  Future<void> dispose(int cameraId) async => disposeCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 模拟 Windows/Linux：Dart 插件已注册但原生无相机委托，方法通道抛
/// MissingPluginException（camera_desktop 仅 Apple 实现）。
class _NoNativeCameraPlatform extends _FakeCameraPlatform {
  _NoNativeCameraPlatform() : super(cameras: const []);

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      throw MissingPluginException('camera_desktop: no native implementation');
}

class _Host extends StatelessWidget {
  const _Host({
    required this.dual,
    required this.videoOnly,
    required this.onResult,
  });

  final bool dual;
  final bool videoOnly;
  final ValueChanged<CameraCaptureResult?> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final r = await Navigator.push<CameraCaptureResult>(
              context,
              MaterialPageRoute<CameraCaptureResult>(
                builder: (_) =>
                    CameraCapturePage(dual: dual, videoOnly: videoOnly),
                fullscreenDialog: true,
              ),
            );
            onResult(r);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester, {
  bool dual = false,
  bool videoOnly = false,
  required ValueChanged<CameraCaptureResult?> onResult,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        builder: EasyLoading.init(),
        home: _Host(dual: dual, videoOnly: videoOnly, onResult: onResult),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // 入栈转场 + 相机初始化（微任务链一泵即达，预览加载动画无无限循环）。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

File _tempPhoto(String name) {
  final f = File(
    '${Directory.systemTemp.path}/cap_test_${DateTime.now().microsecondsSinceEpoch}_$name',
  );
  f.writeAsBytesSync(base64Decode(_pngBase64));
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('无可用摄像头：提示后自动出栈，调用方收到 null', (tester) async {
    CameraPlatform.instance = _FakeCameraPlatform(cameras: const []);
    CameraCaptureResult? got;
    await _open(tester, onResult: (r) => got = r);

    expect(got, isNull);
    expect(find.byType(CameraCapturePage), findsNothing);
    expect(find.text(t.common.cameraNoDevice), findsOneWidget);

    // EasyLoading toast 的自动消失定时器排空，避免用例结束残留 pending timer。
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('平台无相机原生委托（Windows/Linux）：按无设备口径提示', (tester) async {
    CameraPlatform.instance = _NoNativeCameraPlatform();
    CameraCaptureResult? got;
    await _open(tester, onResult: (r) => got = r);

    expect(got, isNull);
    expect(find.byType(CameraCapturePage), findsNothing);
    expect(
      find.text(t.common.cameraNoDevice),
      findsOneWidget,
      reason: 'MissingPluginException 不是权限问题，不应用权限失败文案',
    );
    expect(find.text(t.common.permissionAcquisitionFailed), findsNothing);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('初始化成功：渲染取景页，dual 模式有照片/视频切换', (tester) async {
    final fake = _FakeCameraPlatform();
    CameraPlatform.instance = fake;
    await _open(tester, dual: true, onResult: (_) {});

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.byKey(const ValueKey('camera_mode_photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera_mode_video')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera_shutter')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera_close')), findsOneWidget);
    expect(fake.createCalls, 1);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('拍照→预览→使用：返回 isVideo=false 与照片路径', (tester) async {
    final fake = _FakeCameraPlatform();
    final photo = _tempPhoto('a.jpg');
    fake.photoPath = photo.path;
    CameraPlatform.instance = fake;
    CameraCaptureResult? got;
    await _open(tester, onResult: (r) => got = r);

    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(t.common.cameraUse), findsOneWidget);
    expect(find.text(t.common.cameraRetake), findsOneWidget);

    await tester.tap(find.text(t.common.cameraUse));
    await tester.pumpAndSettle();

    expect(got, isNotNull);
    expect(got!.isVideo, isFalse);
    expect(got!.path, photo.path);
    expect(File(got!.path).existsSync(), isTrue, reason: '移交后文件归调用方');
    expect(fake.disposeCalls, 1, reason: '出栈时控制器已释放');
  });

  testWidgets('重拍：删除临时文件并回到取景态', (tester) async {
    final fake = _FakeCameraPlatform();
    final photo = _tempPhoto('b.jpg');
    fake.photoPath = photo.path;
    CameraPlatform.instance = fake;
    await _open(tester, onResult: (_) {});

    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(photo.existsSync(), isTrue);

    await tester.tap(find.text(t.common.cameraRetake));
    await tester.pumpAndSettle();

    expect(photo.existsSync(), isFalse, reason: '丢弃产物即删临时文件');
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.text(t.common.cameraUse), findsNothing);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('dual 视频模式：录像徽标→停止→使用返回 isVideo=true', (tester) async {
    final fake = _FakeCameraPlatform();
    final video = _tempPhoto('c.mp4');
    fake.videoPath = video.path;
    CameraPlatform.instance = fake;
    CameraCaptureResult? got;
    await _open(tester, dual: true, onResult: (r) => got = r);

    await tester.tap(find.byKey(const ValueKey('camera_mode_video')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('00:00'), findsOneWidget, reason: '录像中显示计时徽标');
    // 录像中只有周期 ticker，不用 pumpAndSettle。
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await tester.pumpAndSettle();

    expect(fake.startCalls, 1);
    expect(fake.stopCalls, 1);
    expect(
      find.byKey(const ValueKey('camera_shutter')),
      findsNothing,
      reason: '已进入视频预览态',
    );
    await tester.tap(find.text(t.common.cameraUse));
    await tester.pumpAndSettle();

    expect(got, isNotNull);
    expect(got!.isVideo, isTrue);
    expect(got!.path, video.path);
  });

  testWidgets('videoOnly：直接为视频模式，无模式切换，产物 isVideo=true', (tester) async {
    final fake = _FakeCameraPlatform();
    final video = _tempPhoto('d.mp4');
    fake.videoPath = video.path;
    CameraPlatform.instance = fake;
    CameraCaptureResult? got;
    await _open(tester, videoOnly: true, onResult: (r) => got = r);

    expect(find.byKey(const ValueKey('camera_mode_photo')), findsNothing);
    expect(find.byKey(const ValueKey('camera_mode_video')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.cameraUse));
    await tester.pumpAndSettle();

    expect(got!.isVideo, isTrue);
    expect(got!.path, video.path);
  });

  testWidgets('未移交产物：预览态路由返回退出时清理临时文件', (tester) async {
    final fake = _FakeCameraPlatform();
    final photo = _tempPhoto('e.jpg');
    fake.photoPath = photo.path;
    CameraPlatform.instance = fake;
    CameraCaptureResult? got;
    await _open(tester, onResult: (r) => got = r);

    await tester.tap(find.byKey(const ValueKey('camera_shutter')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(photo.existsSync(), isTrue);

    // 预览态无关闭按钮，系统返回（路由 pop）走 dispose 清理路径。
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    expect(got, isNull);
    expect(photo.existsSync(), isFalse, reason: '未移交的产物随页面退出清理');
    expect(fake.disposeCalls, 1);
  });
}
