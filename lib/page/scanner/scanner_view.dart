import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/config/const.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_logic.dart';
import 'scanner_result_view.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({Key? key}) : super(key: key);

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  String? barcode;

  MobileScannerController controller = MobileScannerController(
    torchEnabled: false,
    formats: [BarcodeFormat.all],
    // facing: CameraFacing.front,
  );

  final logic = Get.put(ScannerLogic());
  bool isStarted = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 0,
                  top: 20,
                ),
                child: MaterialButton(
                  minWidth: 20,
                  height: 18,
                  onPressed: () {
                    Get.back();
                  },
                  color: Colors.white,
                  textColor: Colors.black54,
                  child: const Icon(
                    Icons.arrow_left,
                    size: 16,
                  ),
                  shape: const CircleBorder(),
                ),
              ),
              MobileScanner(
                controller: controller,
                fit: BoxFit.contain,
                allowDuplicates: true,
                onDetect: (barcode, args) async {
                  if (this.barcode != barcode.rawValue) {
                    // New barcode found !!
                    setState(() {
                      this.barcode = barcode.rawValue;
                    });
                    if (isUrl(this.barcode!) &&
                        this.barcode!.endsWith(uqrcodeDataSuffix)) {
                      IMBoyHttpResponse resp =
                          await HttpClient.client.get(this.barcode!);
                      if (!resp.ok) {
                        return;
                      }
                      Map payload = resp.payload;
                      String result = payload['result'] ?? '';
                      if (result == '') {
                        Get.off(
                          ScannerResultPage(
                            id: payload['id'] ?? '',
                            nickname: payload['nickname'] ?? '',
                            avatar: payload['avatar'] ?? defAvatar,
                            sign: payload['sign'] ?? '',
                            region: payload['region'] ?? '',
                            gender: payload['gender'] ?? 0,
                            is_friend: payload['is_friend'] ?? false,
                          ),
                        );
                      } else if (result == 'user_not_exist') {
                        // EasyLoading.showToast("用户不存在".tr);
                        await logic.showResult("用户不存在".tr);
                      } else if (result == 'user_is_disabled_or_deleted') {
                        // EasyLoading.showToast("用户被禁用或已删除".tr);
                        await logic.showResult("用户被禁用或已删除".tr);
                      }
                    } else if (isUrl(this.barcode!)) {
                      Get.off(WebViewPage(
                        this.barcode!,
                        '',
                        errorCallback: (String url) {
                          logic.showResult("无法打开网页： ${url}");
                        },
                      ));
                    } else {
                      logic.showResult(this.barcode!);
                    }
                  }
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  height: 100,
                  color: Colors.black.withOpacity(0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: ValueListenableBuilder(
                          valueListenable: controller.torchState,
                          builder: (context, state, child) {
                            if (state == null) {
                              return const Icon(
                                Icons.flash_off,
                                color: Colors.grey,
                              );
                            }
                            switch (state as TorchState) {
                              case TorchState.off:
                                return const Icon(
                                  Icons.flash_off,
                                  color: Colors.grey,
                                );
                              case TorchState.on:
                                return const Icon(
                                  Icons.flash_on,
                                  color: Colors.yellow,
                                );
                            }
                          },
                        ),
                        iconSize: 32.0,
                        onPressed: () => controller.toggleTorch(),
                      ),
                      IconButton(
                        color: Colors.white,
                        icon: isStarted
                            ? const Icon(Icons.stop)
                            : const Icon(Icons.play_arrow),
                        iconSize: 32.0,
                        onPressed: () => setState(() {
                          isStarted ? controller.stop() : controller.start();
                          isStarted = !isStarted;
                        }),
                      ),
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 200,
                          height: 20,
                          child: FittedBox(
                            child: Text(
                              // barcode ?? '扫一扫'.tr,
                              '扫一扫'.tr,
                              // overflow: TextOverflow.fade,
                              style: const TextStyle(
                                color: Colors.white,
                                // fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        color: Colors.white,
                        icon: ValueListenableBuilder(
                          valueListenable: controller.cameraFacingState,
                          builder: (context, state, child) {
                            if (state == null) {
                              return const Icon(Icons.camera_front);
                            }
                            switch (state as CameraFacing) {
                              case CameraFacing.front:
                                return const Icon(Icons.camera_front);
                              case CameraFacing.back:
                                return const Icon(Icons.camera_rear);
                            }
                          },
                        ),
                        iconSize: 32.0,
                        onPressed: () => controller.switchCamera(),
                      ),
                      // IconButton(
                      //   color: Colors.white,
                      //   icon: const Icon(Icons.image),
                      //   iconSize: 32.0,
                      //   onPressed: () async {
                      //     final ImagePicker _picker = ImagePicker();
                      //     // Pick an image
                      //     final XFile? image = await _picker.pickImage(
                      //       source: ImageSource.gallery,
                      //     );
                      //     if (image != null) {
                      //       if (await controller.analyzeImage(image.path)) {
                      //         if (!mounted) return;
                      //         ScaffoldMessenger.of(context).showSnackBar(
                      //           const SnackBar(
                      //             content: Text('Barcode found!'),
                      //             backgroundColor: Colors.green,
                      //           ),
                      //         );
                      //       } else {
                      //         if (!mounted) return;
                      //         ScaffoldMessenger.of(context).showSnackBar(
                      //           const SnackBar(
                      //             content: Text('No barcode found!'),
                      //             backgroundColor: Colors.red,
                      //           ),
                      //         );
                      //       }
                      //     }
                      //   },
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
