import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ScannerLogic extends GetxController {
  Future showResult(String txt, int closeTimes) {
    return Get.bottomSheet(
      backgroundColor: Get.isDarkMode
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      InkWell(
        onTap: () {
          Get.closeAllBottomSheets();
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(0.0),
          height: double.infinity,
          // Creates insets from offsets from the left, top, right, and bottom.
          padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
          alignment: Alignment.center,
          color: Colors.white,
          child: Center(
            child: Text(
              txt,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ),
      // 是否支持全屏弹出，默认false
      isScrollControlled: true,
      enableDrag: false,
    );
  }
}
