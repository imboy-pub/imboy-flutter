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
  // ignore: library_private_types_in_public_api
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  String? barcodeStr;

  MobileScannerController controller = MobileScannerController(
    // torchEnabled: false, // 是否 打开灯
    formats: [BarcodeFormat.all],
    // formats: [BarcodeFormat.qrCode],
    // facing: CameraFacing.front,
  );
  final logic = Get.put(ScannerLogic());
  bool isStarted = true;

  Barcode? barcode;
  BarcodeCapture? capture;
  MobileScannerArguments? arguments;

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 320,
      height: 320,
    );
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
                  shape: const CircleBorder(),
                  child: const Icon(Icons.arrow_left, size: 16),
                ),
              ),
              MobileScanner(
                fit: BoxFit.contain,
                scanWindow: scanWindow,
                controller: controller,
                onScannerStarted: (arguments) {
                  debugPrint(
                      "> scanner onScannerStarted ${arguments.toString()}");
                  setState(() {
                    this.arguments = arguments;
                  });
                },
                onDetect: (BarcodeCapture barcodes) async {
                  debugPrint("> scanner onDetect ${barcodes.barcodes.length}");
                  capture = barcodes;
                  setState(() => barcode = barcodes.barcodes.first);
                  // return;
                  if (barcodeStr == barcodes.barcodes.last.rawValue) {
                    return;
                  }
                  // New barcode found !!
                  setState(() {
                    barcodeStr = barcodes.barcodes.last.rawValue;
                  });
                  if (isUrl(barcodeStr!) &&
                      barcodeStr!.endsWith(uqrcodeDataSuffix)) {
                    IMBoyHttpResponse resp =
                        await HttpClient.client.get(barcodeStr!);
                    if (!resp.ok) {
                      return;
                    }
                    Map payload = resp.payload;
                    // debugPrint(">>> on qrcode: ${payload.toString()}");
                    String result = payload['result'] ?? '';
                    if (result == '') {
                      Get.off(
                        ScannerResultPage(
                          id: payload['id'] ?? '',
                          remark: payload['remark'] ?? '',
                          nickname: payload['nickname'] ?? '',
                          avatar: payload['avatar'] ?? defAvatar,
                          sign: payload['sign'] ?? '',
                          region: payload['region'] ?? '',
                          gender: payload['gender'] ?? 0,
                          isFriend: payload['isfriend'] ?? false,
                        ),
                      );
                    } else if (result == 'user_not_exist') {
                      // EasyLoading.showToast("用户不存在".tr);
                      await logic.showResult("用户不存在".tr);
                    } else if (result == 'user_is_disabled_or_deleted') {
                      // EasyLoading.showToast("用户被禁用或已删除".tr);
                      await logic.showResult("用户被禁用或已删除".tr);
                    }
                  } else if (isUrl(barcodeStr!)) {
                    Get.off(WebViewPage(
                      barcodeStr!,
                      '',
                      errorCallback: (String url) {
                        logic.showResult("无法打开网页： $url");
                      },
                    ));
                  } else {
                    logic.showResult(barcodeStr!);
                  }
                },
              ),
              CustomPaint(
                painter: ScannerOverlay(scanWindow),
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
                            switch (state) {
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
                              default:
                                return const Icon(
                                  Icons.flash_off,
                                  color: Colors.grey,
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
                            switch (state) {
                              case CameraFacing.front:
                                return const Icon(Icons.camera_front);
                              case CameraFacing.back:
                                return const Icon(Icons.camera_rear);
                              default:
                                return const Icon(Icons.camera_front);
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
                          isStarted = true;
                          final ImagePicker picker = ImagePicker();
                          // Pick an image
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image == null) {
                            return;
                          }
                          bool res = await controller.analyzeImage(image.path);
                          debugPrint(">>> on barcode $res ${image.path}");
                          if (res) {
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

class ScannerOverlay extends CustomPainter {
  ScannerOverlay(this.scanWindow);

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()..addRect(scanWindow);

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(backgroundWithCutout, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
