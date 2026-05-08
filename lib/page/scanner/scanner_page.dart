import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/page/scanner/qr_login_confirm_page.dart';
import 'package:imboy/page/scanner/qr_login_intent.dart';
import 'package:imboy/page/scanner/scanner_result_page.dart';
import 'package:imboy/page/scanner/scanner_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with SingleTickerProviderStateMixin {
  late MobileScannerController controller;
  bool _isControllerInitialized = false;

  StreamSubscription? _localeSubscription;

  @override
  void initState() {
    super.initState();
    // 禁用自动启动，在 widget 构建完成后手动启动
    controller = MobileScannerController(
      formats: [BarcodeFormat.all],
      autoStart: false, // 关键：禁用自动启动
    );

    // 延迟启动，确保 UI 完全加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanner();
    });

    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _startScanner() async {
    if (_isControllerInitialized || !mounted) return;

    try {
      await controller.start();
      if (mounted) {
        setState(() {
          _isControllerInitialized = true;
        });
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Failed to start scanner: ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> onDetect(BarcodeCapture barcodes) async {
    if (kDebugMode)
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

    // slice-4: 优先识别 web 登录 QR（imboy://qr_login/<token> 私有 scheme），
    // 不命中再 fallback 到现有 user/group/channel HTTP URL 名片识别。
    final intent = detectQrLoginIntent(barcodeStr);
    if (intent is QrLoginIntentWebLogin) {
      if (!mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => QrLoginConfirmPage(qrToken: intent.qrToken),
        ),
      );
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
      if (kDebugMode) debugPrint("> on qrcode: type=${payload['type']}");
      String result = payload['result'] ?? '';
      String type = payload['type'] ?? 'user';
      if (result == '' && type == 'user') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) =>
                PeopleInfoPage(id: payload['id'], scene: 'qrcode'),
          ),
        );
      } else if (result == '' && type == 'group') {
        await GroupMemberRepo().save(payload['group_member']);
        if (!mounted) return;
        Navigator.push(
          context,
          CupertinoPageRoute(
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
        CupertinoPageRoute(
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
                                ? AppColors.iosYellow
                                : Colors.white.withValues(alpha: 0.5);
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
                          if (kDebugMode)
                            debugPrint("> on barcode detected: ${res != null}");
                          if (res == null) {
                            state.showSnackBar(
                              SnackBar(
                                content: Text(t.noBarcodeFound),
                                backgroundColor: AppColors.getIosRed(
                                  Theme.of(context).brightness,
                                ),
                              ),
                            );
                          } else {
                            state.showSnackBar(
                              SnackBar(
                                content: Text(t.barcodeFound),
                                backgroundColor: AppColors.getIosGreen(
                                  Theme.of(context).brightness,
                                ),
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
