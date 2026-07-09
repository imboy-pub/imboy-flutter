import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
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

  @override
  Future<PickedMedia?> pickCamera(
    BuildContext context, {
    bool enableRecording = false,
  }) async {
    // 全局统一走 wechat_camera_picker（原生相机取景界面），
    // 不再用 image_picker 的系统相机快捷方式——两者此前是两套不同实现，
    // 同一个「拍照」语义在不同页面表现不一致。
    //
    // 桌面平台(macOS/Windows/Linux)：wechat_camera_picker 依赖的 camera 插件
    // 无相机捕获委托，保留 image_picker 的相册兜底（原有行为不变）。
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      if (enableRecording) {
        final xfile = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
        );
        if (xfile == null) return null;
        return PickedMedia(path: xfile.path, type: MediaType.video);
      }
      final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (xfile == null) return null;
      return PickedMedia(path: xfile.path, type: MediaType.image);
    }

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
    // 桌面平台(macOS/Windows/Linux)无相机捕获委托：兜底走相册单选，
    // 与 pickCamera 桌面分支保持一致（原有行为不变）。
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(maxAssets: 1),
      );
      return (assets == null || assets.isEmpty) ? null : assets.first;
    }

    // 移动端：原生取景界面，点按拍照 / 长按录像（双模——不设
    // onlyEnableRecording，故拍照与录像共存于同一界面）。
    return CameraPicker.pickFromCamera(
      context,
      pickerConfig: const CameraPickerConfig(enableRecording: true),
    );
  }

  Future<PickedMedia?> _toPickedMedia(AssetEntity asset, MediaType type) async {
    final file = await asset.originFile;
    if (file == null) return null;
    return PickedMedia(path: file.path, type: type);
  }
}
