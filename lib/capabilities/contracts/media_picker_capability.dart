import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart' show AssetEntity;

enum MediaType { image, video, audio, any }

final class PickedMedia {
  const PickedMedia({required this.path, required this.type, this.thumbnail});
  final String path;
  final MediaType type;
  final String? thumbnail;
}

// UI-triggering capabilities require BuildContext — callers hold the context.
abstract interface class MediaPickerCapability {
  Future<List<PickedMedia>> pickImages(
    BuildContext context, {
    int maxCount = 9,
    bool allowCamera = true,
  });
  Future<PickedMedia?> pickVideo(BuildContext context, {Duration? maxDuration});
  Future<PickedMedia?> pickSingle(BuildContext context, MediaType type);
  Future<PickedMedia?> pickCamera(
    BuildContext context, {
    bool enableRecording = false,
  });

  /// 双模相机：一个原生取景界面同时支持「点按拍照 + 长按录像」，
  /// 返回拍到的 [AssetEntity]（图片或视频由 `.type` 区分），未拍返回 null。
  ///
  /// 与单模 [pickCamera]（只拍照 或 只录像，通过 onlyEnableRecording）互补——
  /// 聊天等「拍照/拍摄二合一」场景走此方法，是移动端唯一的相机拍摄实现。
  /// 返回 AssetEntity 而非 [PickedMedia]，因为消息上传/构造管线全程以
  /// AssetEntity 为媒体载体（见 AttachmentApi.upload*EntityViaPresign）。
  Future<AssetEntity?> pickCameraDual(BuildContext context);

  /// 相机拍摄（本地文件语义）：拍摄产物只落临时目录，**不经照片库**，
  /// 因此不依赖照片库授权（桌面 App Sandbox 下的 TCC 痛点）。
  ///
  ///   - [enableRecording]=true：只录像；否则只拍照；
  ///   - [dual]=true：拍照/录像同界面可切换（聊天「拍摄」），与 [enableRecording]
  ///     互斥，dual 优先。
  ///
  /// 返回 [PickedMedia]（本地文件路径），未拍/无可用摄像头返回 null。
  /// 桌面端走独立拍摄页（camera_desktop 引擎）；移动端经 CameraPicker
  /// 转换为文件路径。产物文件所有权随返回值转移，调用方上传完成后负责删除。
  Future<PickedMedia?> pickCameraCapture(
    BuildContext context, {
    bool enableRecording = false,
    bool dual = false,
  });
}
