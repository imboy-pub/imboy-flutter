import 'package:flutter/widgets.dart';

abstract interface class ImageLoaderCapability {
  ImageProvider loadNetwork(String url, {int? width, int? height});
  ImageProvider loadAsset(String assetPath);
  Future<void> preload(BuildContext context, String url);
  Future<void> clearCache();
}
