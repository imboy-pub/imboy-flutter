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
  /// 聊天等「拍照/拍摄二合一」场景走此方法，是全局唯一的相机拍摄实现。
  /// 返回 AssetEntity 而非 [PickedMedia]，因为消息上传/构造管线全程以
  /// AssetEntity 为媒体载体（见 AttachmentApi.upload*EntityViaPresign）。
  Future<AssetEntity?> pickCameraDual(BuildContext context);
}
