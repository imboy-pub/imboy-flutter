import 'package:imboy/component/webrtc/media_permission.dart';

import 'p2p_call_state_machine.dart';

/// P2P Call Screen 状态
class P2pCallScreenState {
  final bool cameraOff;
  final bool isFrontCamera;
  final bool micOff;
  final bool speakerOn;
  final bool connected;
  final bool showTool;
  final bool minimized;

  /// 通话阶段 + 结束原因（唯一真值源，见 [CallStatus]）。
  final CallStatus callStatus;
  final String callDuration;
  final double localX;
  final double localY;

  /// 悬浮窗位置（最小化后的小窗，left/top 像素坐标）。
  final double floatX;
  final double floatY;

  /// 网络重连中（LiveKit Room Reconnecting/Resuming）。用于顶部“网络不佳”横幅。
  final bool reconnecting;

  /// 对端连接质量持续下降（NET-06 轻度档，带进入/退出迟滞）。非遮挡
  /// “网络不稳定”提示；与 [reconnecting]（持续中断档）分级展示。
  final bool networkUnstable;

  /// 对端已关闭摄像头（track_state 信令同步）。用于主画面占位提示，
  /// 否则对端关摄像头后本端只看到黑屏、无从分辨。
  final bool remoteVideoOff;
  final String errorMessage;
  final MediaPermissionTarget? permissionTarget;

  /// 接通前本地预览是否已就绪（房外自视图轨已创建）。仅用于触发 UI
  /// 重建；真实轨道经 notifier.previewTrack 获取。
  final bool localPreviewReady;

  const P2pCallScreenState({
    this.cameraOff = false,
    this.isFrontCamera = true,
    this.micOff = false,
    this.speakerOn = true,
    this.connected = false,
    this.showTool = true,
    this.minimized = false,
    this.callStatus = const CallStatus(),
    this.callDuration = '00:00',
    this.localX = 0.0,
    this.localY = 0.0,
    this.floatX = 0.0,
    this.floatY = 0.0,
    this.reconnecting = false,
    this.networkUnstable = false,
    this.remoteVideoOff = false,
    this.errorMessage = '',
    this.permissionTarget,
    this.localPreviewReady = false,
  });

  P2pCallScreenState copyWith({
    bool? cameraOff,
    bool? isFrontCamera,
    bool? micOff,
    bool? speakerOn,
    bool? connected,
    bool? showTool,
    bool? minimized,
    CallStatus? callStatus,
    String? callDuration,
    double? localX,
    double? localY,
    double? floatX,
    double? floatY,
    bool? reconnecting,
    bool? networkUnstable,
    bool? remoteVideoOff,
    String? errorMessage,
    MediaPermissionTarget? permissionTarget,
    bool? localPreviewReady,
    bool clearPermissionTarget = false,
  }) {
    return P2pCallScreenState(
      cameraOff: cameraOff ?? this.cameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      micOff: micOff ?? this.micOff,
      speakerOn: speakerOn ?? this.speakerOn,
      connected: connected ?? this.connected,
      showTool: showTool ?? this.showTool,
      minimized: minimized ?? this.minimized,
      callStatus: callStatus ?? this.callStatus,
      callDuration: callDuration ?? this.callDuration,
      localX: localX ?? this.localX,
      localY: localY ?? this.localY,
      floatX: floatX ?? this.floatX,
      floatY: floatY ?? this.floatY,
      reconnecting: reconnecting ?? this.reconnecting,
      networkUnstable: networkUnstable ?? this.networkUnstable,
      remoteVideoOff: remoteVideoOff ?? this.remoteVideoOff,
      errorMessage: errorMessage ?? this.errorMessage,
      permissionTarget: clearPermissionTarget
          ? null
          : permissionTarget ?? this.permissionTarget,
      localPreviewReady: localPreviewReady ?? this.localPreviewReady,
    );
  }
}

/// 悬浮窗松手吸附：按当前窗口中心落在屏幕左/右半区，吸附到对应边缘（FaceTime PiP 同款）。
/// 返回吸附后的 left 像素值。
double snapFloatingLeft({
  required double currentLeft,
  required double windowWidth,
  required double screenWidth,
  double margin = 10,
}) {
  final center = currentLeft + windowWidth / 2;
  final rightEdge = screenWidth - windowWidth - margin;
  return center < screenWidth / 2 ? margin : rightEdge;
}

/// 主画面上下滑动交换本端/对端视频的最小速度阈值。
bool shouldSwapVideoLayout(double? verticalVelocity, {double threshold = 280}) {
  return (verticalVelocity ?? 0).abs() > threshold;
}

/// 通话时长格式化：<1h 显示 mm:ss，≥1h 显示 hh:mm:ss（FaceTime 同款）。
String formatCallDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
