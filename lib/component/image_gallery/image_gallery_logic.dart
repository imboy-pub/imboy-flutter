import 'package:flutter/cupertino.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';

class ImageGalleryLogic extends GetxController {
  RxList<PreviewImage> gallery = RxList<PreviewImage>([]);
  PageController? galleryPageController;
  RxBool isImageViewVisible = false.obs;

  void onImagePressed(types.ImageMessage message) {
    final initialPage = gallery.indexWhere(
      (element) => element.id == message.id && element.uri == message.uri,
    );
    galleryPageController = PageController(initialPage: initialPage);
    // setState(() {
    isImageViewVisible.value = true;
    // });
  }

  void onCloseGalleryPressed() {
    // setState(() {
    isImageViewVisible.value = false;
    // });
    galleryPageController?.dispose();
    galleryPageController = null;
  }

  void pushToGallery(String msgId, String msgUri) {
    if (GetPlatform.isWeb) {
      if (msgUri.startsWith('http') || msgUri.startsWith('blob')) {
        gallery.insert(0, PreviewImage(id: msgId, uri: msgUri));
      }
    } else {
      gallery.insert(0, PreviewImage(id: msgId, uri: msgUri));
    }
  }
}
