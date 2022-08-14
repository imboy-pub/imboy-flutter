import 'package:flutter/cupertino.dart';
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

  void pushToGallery(types.ImageMessage msg) {
    if (GetPlatform.isWeb) {
      if (msg.uri.startsWith('http') || msg.uri.startsWith('blob')) {
        gallery.insert(0, PreviewImage(id: msg.id, uri: msg.uri));
      }
    } else {
      gallery.insert(0, PreviewImage(id: msg.id, uri: msg.uri));
    }
  }
}
