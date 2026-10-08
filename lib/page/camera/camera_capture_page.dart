import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:video_compress/video_compress.dart';

/// 拍摄产物：本地文件路径 + 媒体类型。文件在系统临时目录，所有权随
/// 返回值转移给调用方（上传完成后由调用方负责删除）。
class CameraCaptureResult {
  const CameraCaptureResult({required this.path, required this.isVideo});

  final String path;
  final bool isVideo;
}

/// 桌面相机拍摄页（macOS/Windows/Linux），基于官方 `package:camera` API。
///
/// 平台实现为 camera_desktop（实现 camera_platform_interface，AVFoundation
/// 后端）；本页只依赖官方接口，未来官方 macOS 支持落地或更换平台实现时
/// 本页零改动。
///
/// 仅由能力适配器层（WechatAssetsPickerAdapter）打开，业务页面不得直接
/// 导航到此页——维持「全局唯一相机拍摄入口」约束。
///
/// 模式：
///   - [videoOnly]：只录像；
///   - [dual]：照片/视频可切换（聊天「拍摄」入口）；
///   - 都为 false：只拍照（头像、朋友圈单图等）。
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({
    super.key,
    this.videoOnly = false,
    this.dual = false,
  });

  final bool videoOnly;
  final bool dual;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  bool _initialized = false;

  /// null=照片模式；false/true=录像待机/录像中。dual=false 时恒为照片或视频。
  bool? _recording;
  XFile? _captured;

  /// 产物已通过 _confirm 移交调用方（dispose 时不再删除）。
  bool _handedOff = false;
  final Stopwatch _recordWatch = Stopwatch();
  Timer? _recordTicker;

  @override
  void initState() {
    super.initState();
    _recording = widget.videoOnly ? false : null;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _abort(t.common.cameraNoDevice);
        return;
      }
      // 桌面多为前置/外接单摄：优先后置（有则用），否则取第一个。
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialized = true;
      });
    } on Object catch (e) {
      debugPrint('[camera_capture_page] init failed, errType=${e.runtimeType}');
      _abort(t.common.permissionAcquisitionFailed);
    }
  }

  /// 无设备/初始化失败：提示后带 null 出栈（调用方视为用户取消，不报错）。
  void _abort(String toast) {
    if (!mounted) return;
    AppLoading.showToast(toast);
    Navigator.of(context).pop();
  }

  Future<void> _takePhoto() async {
    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      setState(() => _captured = file);
    } on Object catch (e) {
      debugPrint('[camera_capture_page] takePicture error: $e');
      if (mounted) AppLoading.showToast(t.common.cameraShootFailed);
    }
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null) return;
    if (_recording != true) {
      try {
        _recordWatch
          ..reset()
          ..start();
        await controller.startVideoRecording();
        if (!mounted) return;
        setState(() => _recording = true);
        _recordTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
          if (mounted && _recording == true) setState(() {});
        });
      } on Object catch (e) {
        debugPrint('[camera_capture_page] startRecording error: $e');
        _recordWatch.stop();
        if (mounted) AppLoading.showToast(t.common.cameraShootFailed);
      }
      return;
    }
    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() {
        _captured = file;
        _recording = false;
      });
    } on Object catch (e) {
      debugPrint('[camera_capture_page] stopRecording error: $e');
      if (mounted) AppLoading.showToast(t.common.cameraShootFailed);
    } finally {
      _recordTicker?.cancel();
      _recordWatch.stop();
      if (mounted) setState(() => _recording = false);
    }
  }

  /// 重拍/取消预览：丢弃本次产物文件并回到取景。
  Future<void> _discardCapture() async {
    final file = _captured;
    if (file != null) {
      try {
        File(file.path).deleteSync();
      } on Object {
        // 临时目录文件删除失败不影响交互
      }
    }
    if (mounted) setState(() => _captured = null);
  }

  void _confirm() {
    final file = _captured;
    if (file == null) return;
    _handedOff = true;
    Navigator.of(context).pop(
      CameraCaptureResult(
        path: file.path,
        isVideo: widget.videoOnly || _recording != null,
      ),
    );
  }

  String get _recordElapsed {
    final s = _recordWatch.elapsed;
    final mm = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void dispose() {
    _recordTicker?.cancel();
    _recordWatch.stop();
    // 未移交的产物是临时文件，直接清理；已移交的所有权在调用方。
    final file = _captured;
    if (file != null && !_handedOff) {
      try {
        File(file.path).deleteSync();
      } on Object {
        // 临时目录文件删除失败不影响页面退出
      }
    }
    final controller = _controller;
    if (controller != null) {
      if (_recording == true) {
        // 页面在录像中被关闭：先停录再释放，避免原生层悬挂。
        unawaited(
          controller.stopVideoRecording().then((_) => controller.dispose()),
        );
      } else {
        unawaited(controller.dispose());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cameraBackdrop,
      body: !_initialized
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.cameraShutterRing,
              ),
            )
          : _captured != null
          ? _buildPreview(context)
          : _buildViewfinder(context),
    );
  }

  // ────────────────────────── 取景态 ──────────────────────────

  Widget _buildViewfinder(BuildContext context) {
    final controller = _controller!;
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
        _buildTopBar(context),
        if (_recording == true) _buildRecordingBadge(context),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpacing.small,
      left: AppSpacing.large,
      right: AppSpacing.large,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.cameraShutterRing),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            t.common.cameraCapture,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.cameraShutterRing,
            ),
          ),
          const Spacer(),
          // 与左侧关闭按钮对称的占位，保证标题居中。
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRecordingBadge(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpacing.xxLarge,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.medium,
            vertical: AppSpacing.tiny,
          ),
          decoration: BoxDecoration(
            color: AppColors.cameraBackdrop.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppSpacing.regular),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fiber_manual_record,
                color: AppColors.cameraRecordingRed,
                size: 12,
              ),
              SizedBox(width: AppSpacing.tiny),
              Text(
                _recordElapsed,
                style: context.textStyle(
                  FontSizeType.normal,
                  color: AppColors.cameraShutterRing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxLarge,
      left: AppSpacing.large,
      right: AppSpacing.large,
      child: Column(
        children: [
          if (widget.dual && _recording != true) _buildModeSwitch(context),
          SizedBox(height: AppSpacing.large),
          _buildShutter(context),
        ],
      ),
    );
  }

  Widget _buildModeSwitch(BuildContext context) {
    final isVideo = _recording != null;
    return Container(
      padding: EdgeInsets.all(AppSpacing.tiny),
      decoration: BoxDecoration(
        color: AppColors.cameraBackdrop.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.xLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(context, t.common.cameraModePhoto, !isVideo, () {
            setState(() => _recording = null);
          }),
          _buildModeChip(context, t.common.cameraModeVideo, isVideo, () {
            setState(() => _recording = false);
          }),
        ],
      ),
    );
  }

  Widget _buildModeChip(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        child: Text(
          label,
          style: context.textStyle(
            active ? FontSizeType.normal : FontSizeType.small,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active
                ? AppColors.cameraShutterRing
                : AppColors.cameraShutterRing.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildShutter(BuildContext context) {
    final isVideoMode = _recording != null;
    final isRecording = _recording == true;
    return GestureDetector(
      onTap: isVideoMode ? _toggleRecording : _takePhoto,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isRecording
              ? BorderRadius.circular(AppSpacing.medium)
              : null,
          border: Border.all(
            color: AppColors.cameraShutterRing,
            width: AppSpacing.tiny,
          ),
        ),
        padding: EdgeInsets.all(isRecording ? 0 : AppSpacing.small),
        child: Container(
          decoration: BoxDecoration(
            shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isRecording
                ? BorderRadius.circular(AppSpacing.small)
                : null,
            color: isVideoMode
                ? AppColors.cameraRecordingRed
                : AppColors.cameraShutterRing,
          ),
        ),
      ),
    );
  }

  // ────────────────────────── 预览态 ──────────────────────────

  Widget _buildPreview(BuildContext context) {
    final file = _captured!;
    final isVideo = widget.videoOnly || _recording != null;
    return Stack(
      children: [
        Center(
          child: isVideo
              ? FutureBuilder<File?>(
                  future: VideoCompress.getFileThumbnail(
                    file.path,
                    quality: 60,
                    position: -1,
                  ),
                  builder: (context, snap) {
                    final thumb = snap.data;
                    if (thumb == null) {
                      return const Icon(
                        Icons.videocam,
                        color: AppColors.cameraShutterRing,
                        size: 64,
                      );
                    }
                    return Image.file(thumb, fit: BoxFit.contain);
                  },
                )
              : Image.file(File(file.path), fit: BoxFit.contain),
        ),
        Positioned(
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxLarge,
          left: AppSpacing.large,
          right: AppSpacing.large,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _discardCapture,
                child: Text(
                  t.common.cameraRetake,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.cameraShutterRing,
                  ),
                ),
              ),
              FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xLarge),
                ),
                child: Text(
                  t.common.cameraUse,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
