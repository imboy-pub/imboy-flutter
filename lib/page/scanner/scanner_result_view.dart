import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/web_view.dart';

import 'scanner_logic.dart';

// ignore: must_be_immutable
class ScannerResultPage extends StatelessWidget {
  final String scanResult;

  const ScannerResultPage({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<ScannerLogic>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
          automaticallyImplyLeading: true,
          title: 'scanResult'.tr
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: SizedBox(
        width: Get.width,
        height: 64.0,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Space(width: 40),
                FloatingActionButton(
                  heroTag: "back",
                  tooltip: 'buttonBack'.tr,
                  onPressed: () {
                    Get.back();
                  },
                  child: const Icon(Icons.keyboard_arrow_left),
                ),

                // copy
                FloatingActionButton(
                  heroTag: 'copy',
                  tooltip: 'buttonCopy'.tr,
                  onPressed: () {
                    // 已复制
                    Clipboard.setData(ClipboardData(text: scanResult));
                    EasyLoading.showToast('copied'.tr);
                  },
                  child: const Icon(Icons.copy_all),
                ),
                // open in browser
                FloatingActionButton(
                  heroTag: "open_in_browser",
                  tooltip: 'openInBrowser'.tr,
                  backgroundColor: isUrl(scanResult) ? null : Colors.grey,
                  onPressed: () {
                    if (isUrl(scanResult)) {
                      Get.to(
                            () => WebViewPage(
                          scanResult,
                          '',
                          errorCallback: (String url) {
                            // EasyLoading.showError("无法打开网页： $url");
                            logic.showResult("无法打开网页： $url", 2);
                          },
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    }
                  },
                  child: const Icon(Icons.open_in_browser),
                ),
                const Space(width: 40),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(0.0),
        height: double.infinity,
        // Creates insets from offsets from the left, top, right, and bottom.
        padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
        alignment: Alignment.center,
        color: Colors.white,
        child: Center(
          child: Text(
            scanResult,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
  }
}