import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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
                padding: EdgeInsets.only(
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
                  child: Icon(
                    Icons.arrow_left,
                    size: 16,
                  ),
                  shape: CircleBorder(),
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
                    if (this.barcode!.endsWith(uqrcodeDataSuffix)) {
                      HttpResponse resp1 =
                          await HttpClient.client.get(this.barcode!);
                      if (!resp1.ok) {
                        return;
                      }
                      Map payload = resp1.payload;

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
                    } else if (isUrl(this.barcode!)) {
                      Get.off(WebViewPage(this.barcode!, ''));
                    } else {
                      Get.bottomSheet(
                        InkWell(
                          onTap: () {
                            Get.close(2);
                          },
                          child: Container(
                            width: double.infinity,
                            margin: EdgeInsets.all(0.0),
                            height: double.infinity,
                            // Creates insets from offsets from the left, top, right, and bottom.
                            padding: EdgeInsets.fromLTRB(16, 28, 0, 10),
                            alignment: Alignment.center,
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                this.barcode!,
                                textAlign: TextAlign.left,
                                style: TextStyle(
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
                              style: TextStyle(
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
                      IconButton(
                        color: Colors.white,
                        icon: const Icon(Icons.image),
                        iconSize: 32.0,
                        onPressed: () async {
                          final ImagePicker _picker = ImagePicker();
                          // Pick an image
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null) {
                            if (await controller.analyzeImage(image.path)) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Barcode found!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No barcode found!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
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
