import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

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
  Future<PickedMedia?> pickCamera(BuildContext context) async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (xfile == null) return null;
    return PickedMedia(path: xfile.path, type: MediaType.image);
  }

  Future<PickedMedia?> _toPickedMedia(AssetEntity asset, MediaType type) async {
    final file = await asset.originFile;
    if (file == null) return null;
    return PickedMedia(path: file.path, type: type);
  }
}
