import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:imboy/page/camera/camera_capture_page.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import 'package:imboy/capabilities/contracts/media_picker_capability.dart';

final class WechatAssetsPickerAdapter implements MediaPickerCapability {
  const WechatAssetsPickerAdapter();

  @override
  Future<List<PickedMedia>> pickImages(
    BuildContext context, {
    int maxCount = 9,
    bool allowCamera = true,
  }) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxCount,
        requestType: RequestType.image,
      ),
    );
    if (assets == null) return const [];
    return _toPickedList(assets, MediaType.image);
  }

  @override
  Future<PickedMedia?> pickVideo(
    BuildContext context, {
    Duration? maxDuration,
  }) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.video,
      ),
    );
    if (assets == null || assets.isEmpty) return null;
    return _toPickedMedia(assets.first, MediaType.video);
  }

  @override
  Future<PickedMedia?> pickSingle(BuildContext context, MediaType type) async {
    final requestType = switch (type) {
      MediaType.image => RequestType.image,
      MediaType.video => RequestType.video,
      MediaType.audio => RequestType.audio,
      MediaType.any => RequestType.common,
    };
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(maxAssets: 1, requestType: requestType),
    );
    if (assets == null || assets.isEmpty) return null;
    return _toPickedMedia(assets.first, type);
  }

  @override
  Future<PickedMedia?> pickCamera(
    BuildContext context, {
    bool enableRecording = false,
  }) async {
    // 桌面平台(macOS/Windows/Linux)：camera_desktop 拍摄页真拍摄，
    // 产物只落临时目录、不碰照片库授权。
    if (_isDesktop) {
      return pickCameraCapture(context, enableRecording: enableRecording);
    }

    // 移动端：全局统一走 wechat_camera_picker（原生相机取景界面），
    // 不再用 image_picker 的系统相机快捷方式——两者此前是两套不同实现，
    // 同一个「拍照」语义在不同页面表现不一致。
    final entity = await CameraPicker.pickFromCamera(
      context,
      pickerConfig: CameraPickerConfig(
        // 沿用契约既有语义：enableRecording=true 时只录像，不拍照
        enableRecording: enableRecording,
        onlyEnableRecording: enableRecording,
      ),
    );
    if (entity == null) return null;
    return _toPickedMedia(
      entity,
      enableRecording ? MediaType.video : MediaType.image,
    );
  }

  @override
  Future<AssetEntity?> pickCameraDual(BuildContext context) async {
    // 移动端专用：原生取景界面，点按拍照 / 长按录像（双模——不设
    // onlyEnableRecording，故拍照与录像共存于同一界面）。桌面拍摄已由
    // pickCameraCapture（文件语义）承接，不再降级相册。
    return CameraPicker.pickFromCamera(
      context,
      pickerConfig: const CameraPickerConfig(enableRecording: true),
    );
  }

  @override
  Future<PickedMedia?> pickCameraCapture(
    BuildContext context, {
    bool enableRecording = false,
    bool dual = false,
  }) async {
    if (!kIsWeb && _isDesktop) {
      final result = await Navigator.of(context).push<CameraCaptureResult>(
        MaterialPageRoute<CameraCaptureResult>(
          builder: (_) => CameraCapturePage(
            videoOnly: enableRecording && !dual,
            dual: dual,
          ),
          fullscreenDialog: true,
        ),
      );
      if (result == null) return null;
      return PickedMedia(
        path: result.path,
        type: result.isVideo ? MediaType.video : MediaType.image,
      );
    }

    // 移动端：CameraPicker 拍摄（产物会经相册合成为 AssetEntity），转文件路径。
    final entity = await CameraPicker.pickFromCamera(
      context,
      pickerConfig: CameraPickerConfig(
        enableRecording: enableRecording || dual,
        onlyEnableRecording: enableRecording && !dual,
      ),
    );
    if (entity == null) return null;
    return _toPickedMedia(
      entity,
      entity.type == AssetType.video ? MediaType.video : MediaType.image,
    );
  }

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  Future<List<PickedMedia>> _toPickedList(
    List<AssetEntity> assets,
    MediaType type,
  ) async {
    final results = <PickedMedia>[];
    for (final asset in assets) {
      final media = await _toPickedMedia(asset, type);
      if (media != null) results.add(media);
    }
    return results;
  }

  Future<PickedMedia?> _toPickedMedia(AssetEntity asset, MediaType type) async {
    final file = await asset.originFile;
    if (file == null) return null;
    return PickedMedia(path: file.path, type: type);
  }
}
