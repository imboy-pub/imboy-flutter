import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ScannerLogic extends GetxController {
  Future showResult(result) {
    return Get.bottomSheet(
      InkWell(
        onTap: () {
          Get.close(2);
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
              result,
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
