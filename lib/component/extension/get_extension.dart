import 'package:get/get.dart';
import 'package:imboy/component/loading_dialog.dart';

extension GetExtension on GetInterface {
  dismiss() {
    if (Get.isDialogOpen ?? false) {
      Get.closeAllDialogs();
    } else if (Get.isOverlaysOpen) {
      Get.closeAllOverlays();
    } else if (Get.isBottomSheetOpen ?? false) {
      Get.closeAllBottomSheets();
    }
  }

  loading() {
    if (Get.isDialogOpen ?? false) {
      Get.closeAllDialogs();
    } else if (Get.isOverlaysOpen) {
      Get.closeAllOverlays();
    } else if (Get.isBottomSheetOpen ?? false) {
      Get.closeAllBottomSheets();
    }
    Get.dialog(const LoadingDialog());
  }
}
