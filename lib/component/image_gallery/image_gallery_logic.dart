import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';

class ImageGalleryLogic extends GetxController {
  final RxList<PreviewImage> gallery = RxList<PreviewImage>([]);
  final RxBool isImageViewVisible = false.obs;
  PageController? galleryPageController;

  // 用于快速查找的索引映射
  final _imageIndexMap = <String, int>{};

  void onImagePressed(String imageId, String imageUri) {
    iPrint("onImagePressed: ${gallery.isEmpty}");
    pushToGallery(imageId, imageUri);

    final key = '$imageId-$imageUri';
    iPrint("onImagePressed: $key");
    final initialPage = _imageIndexMap[key] ?? 0;

    galleryPageController?.dispose();
    galleryPageController = PageController(
      initialPage: initialPage.clamp(0, gallery.length - 1),
    );
    isImageViewVisible.value = true;
  }

  void onCloseGalleryPressed() {
    isImageViewVisible.value = false;
    galleryPageController?.dispose();
    galleryPageController = null;
  }

  void pushToGallery(String msgId, String msgUri) {
    if (GetPlatform.isWeb &&
        !(msgUri.startsWith('http') || msgUri.startsWith('blob'))) {
      return;
    }

    final key = '$msgId-$msgUri';
    if (!_imageIndexMap.containsKey(key)) {
      gallery.insert(0, PreviewImage(id: msgId, uri: msgUri));
      _updateIndexMap();
      update();
    }
  }

  void pushToLast(String msgId, String msgUri) {
    final key = '$msgId-$msgUri';
    if (!_imageIndexMap.containsKey(key)) {
      gallery.add(PreviewImage(id: msgId, uri: msgUri));
      _updateIndexMap();
      update();
    }
  }

  void remoteFromGallery(String msgId) {
    final index = gallery.indexWhere((e) => e.id == msgId);
    if (index >= 0) {
      gallery.removeAt(index);
      _imageIndexMap.removeWhere((key, _) => key.startsWith('$msgId-'));
      _updateIndexMap(); // 重新计算索引
      update();
    }
  }

  // 更新索引映射
  void _updateIndexMap() {
    _imageIndexMap.clear();
    for (int i = 0; i < gallery.length; i++) {
      _imageIndexMap['${gallery[i].id}-${gallery[i].uri}'] = i;
    }
  }

  @override
  void onClose() {
    galleryPageController?.dispose();
    super.onClose();
  }
}
