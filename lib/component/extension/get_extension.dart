import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

extension GetExtension on GetInterface {
  void dismiss() {
    if (Get.isDialogOpen ?? false) {
      Get.closeAllDialogs();
    } else if (Get.isOverlaysOpen) {
      Get.closeAllOverlays();
    } else if (Get.isBottomSheetOpen ?? false) {
      Get.closeAllBottomSheets();
    }
    EasyLoading.dismiss();
  }

  void loading() {
    if (Get.isDialogOpen ?? false) {
      Get.closeAllDialogs();
    } else if (Get.isOverlaysOpen) {
      Get.closeAllOverlays();
    } else if (Get.isBottomSheetOpen ?? false) {
      Get.closeAllBottomSheets();
    }
    EasyLoading.show();
  }
}
