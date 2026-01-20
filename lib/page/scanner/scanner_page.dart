import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/page/scanner/scanner_result_page.dart';
import 'package:imboy/page/scanner/scanner_provider.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with SingleTickerProviderStateMixin {
  MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.all],
  );

  StreamSubscription? _localeSubscription;

  @override
  void initState() {
    super.initState();
    controller.start();
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Future<void> dispose() async {
    _localeSubscription?.cancel();
    super.dispose();
    await controller.dispose();
  }

  Future<void> onDetect(BarcodeCapture barcodes) async {
    debugPrint("> scanner onDetect ${barcodes.barcodes.length}");
    final scannerNotifier = ref.read(scannerProvider.notifier);
    final scannerState = ref.read(scannerProvider);

    if (!scannerState.attainableResult) {
      return;
    }

    scannerNotifier.updateBarcode(barcodes);
    scannerNotifier.startProcessing();

    final barcodeStr = barcodes.barcodes.last.rawValue;
    if (barcodeStr == null) {
      return;
    }

    bool isIMBoyQrcode = barcodeStr.endsWith(qrcodeDataSuffix);
    if (isUrl(barcodeStr) && isIMBoyQrcode) {
      IMBoyHttpResponse resp = await HttpClient.client.get(barcodeStr);
      if (!resp.ok) {
        EasyLoading.showError(resp.msg);
        return;
      }
      Map payload = resp.payload;
      debugPrint("> on qrcode: ${payload.toString()}");
      String result = payload['result'] ?? '';
      String type = payload['type'] ?? 'user';
      if (result == '' && type == 'user') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PeopleInfoPage(id: payload['id'], scene: 'qrcode'),
          ),
        );
      } else if (result == '' && type == 'group') {
        await GroupMemberRepo().save(payload['group_member']);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              peerId: payload['id'],
              peerTitle: payload['title'],
              peerAvatar: payload['avatar'],
              peerSign: '',
              type: 'C2G',
              options: {'memberCount': payload['member_count']},
            ),
          ),
        );
      } else if (result == 'user_not_exist') {
        await _showResult(t.userNotExist);
      } else if (result == 'user_is_disabled_or_deleted') {
        // 用户被禁用或已删除
        await _showResult(t.userDisabledOrDeleted);
      }
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScannerResultPage(scanResult: barcodeStr),
        ),
      );
    }
  }

  Future<void> _showResult(String txt) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      builder: (context) => InkWell(
        onTap: () {
          Navigator.pop(context);
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(0.0),
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
          alignment: Alignment.center,
          color: Colors.white,
          child: Center(
            child: Text(
              txt,
              textAlign: TextAlign.left,
              style: const TextStyle(color: Colors.black, fontSize: 24),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      enableDrag: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final scannerState = ref.watch(scannerProvider);

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
                padding: const EdgeInsets.only(left: 0, top: 20),
                child: MaterialButton(
                  minWidth: 20,
                  height: 18,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  color: Theme.of(context).colorScheme.surface,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.arrow_left, size: 16),
                ),
              ),
              MobileScanner(
                fit: BoxFit.contain,
                scanWindow: scanWindow,
                controller: controller,
                onDetect: onDetect,
              ),
              CustomPaint(painter: ScannerOverlay(scanWindow)),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  height: 100,
                  color: Colors.black.withValues(alpha: 0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: ValueListenableBuilder(
                          valueListenable: controller,
                          builder: (context, MobileScannerState state, child) {
                            final iconData = state.torchState == TorchState.on
                                ? Icons.flash_on
                                : Icons.flash_off;
                            final color = state.torchState == TorchState.on
                                ? Colors.yellow
                                : Colors.grey;
                            return Icon(iconData, color: color);
                          },
                        ),
                        iconSize: 32.0,
                        onPressed: () => controller.toggleTorch(),
                      ),
                      IconButton(
                        color: Colors.white,
                        icon: scannerState.isStarted
                            ? const Icon(Icons.stop)
                            : const Icon(Icons.play_arrow),
                        iconSize: 32.0,
                        onPressed: () {
                          scannerState.isStarted
                              ? controller.stop()
                              : controller.start();
                          ref
                              .read(scannerProvider.notifier)
                              .toggleScanning(!scannerState.isStarted);
                        },
                      ),
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 200,
                          height: 20,
                          child: FittedBox(
                            child: Text(
                              t.scanQrCode,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        color: Colors.white,
                        icon: ValueListenableBuilder(
                          valueListenable: controller,
                          builder:
                              (
                                context,
                                MobileScannerState cameraFacing,
                                child,
                              ) {
                                final iconData =
                                    cameraFacing.cameraDirection ==
                                        CameraFacing.front
                                    ? Icons.camera_front
                                    : Icons.camera_rear;
                                return Icon(iconData);
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
                          ScaffoldMessengerState state = ScaffoldMessenger.of(
                            context,
                          );
                          if (!scannerState.isStarted) {
                            controller.start();
                          }
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image == null) {
                            return;
                          }
                          if (!mounted) return;
                          BarcodeCapture? res = await controller.analyzeImage(
                            image.path,
                          );
                          debugPrint("> on barcode $res ${image.path}");
                          if (res == null) {
                            state.showSnackBar(
                              SnackBar(
                                content: Text(t.noBarcodeFound),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            state.showSnackBar(
                              SnackBar(
                                content: Text(t.barcodeFound),
                                backgroundColor: Colors.green,
                              ),
                            );
                            onDetect(res);
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
      ..color = Colors.black.withValues(alpha: 0.5)
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
