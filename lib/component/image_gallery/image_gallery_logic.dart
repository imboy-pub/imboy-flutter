import 'package:flutter/cupertino.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';

class ImageGalleryLogic extends GetxController {
  RxList<PreviewImage> gallery = RxList<PreviewImage>([]);
  PageController? galleryPageController;
  RxBool isImageViewVisible = false.obs;

  void onImagePressed(types.ImageMessage msg) {
    final initialPage = gallery.indexWhere(
      (e) => e.id == msg.id && e.uri == msg.uri,
    );
    galleryPageController = PageController(initialPage: initialPage);
    isImageViewVisible.value = true;
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
    update([gallery]);
  }

  void pushToLast(String msgId, String msgUri) {
    gallery.add(PreviewImage(id: msgId, uri: msgUri));
    update([gallery]);
  }

  void remoteFromGallery(String msgId) {
    final index = gallery.indexWhere((e) => e.id == msgId);
    gallery.removeAt(index);
    update([gallery]);
  }
}
