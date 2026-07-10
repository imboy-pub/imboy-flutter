import 'dart:async';
import 'package:imboy/theme/default/font_types.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
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
  // 相机启动失败的可见反馈状态：区分权限被拒 vs 其他初始化失败
  bool _startFailed = false;
  bool _permissionDenied = false;

  StreamSubscription<dynamic>? _localeSubscription;

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
          _startFailed = false;
          _permissionDenied = false;
        });
      }
    } on MobileScannerException catch (e) {
      if (kDebugMode) debugPrint('Failed to start scanner: ${e.errorCode}');
      if (mounted) {
        setState(() {
          _startFailed = true;
          _permissionDenied =
              e.errorCode == MobileScannerErrorCode.permissionDenied;
        });
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Failed to start scanner: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _startFailed = true;
          _permissionDenied = false;
        });
      }
    }
  }

  /// 相机初始化失败时的可见引导：权限被拒 → 去设置开启；其他失败 → 重试
  Widget _buildStartErrorView(BuildContext context) {
    final t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 44,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _permissionDenied
                  ? t.common.noPermission
                  : t.common.permissionAcquisitionFailed,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.medium,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
              onPressed: _permissionDenied
                  ? () => openAppSettings()
                  : _startScanner,
              child: Text(
                _permissionDenied ? t.main.setting : t.common.buttonRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> onDetect(BarcodeCapture barcodes) async {
    if (kDebugMode) {}
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
        CupertinoPageRoute<dynamic>(
          builder: (context) => QrLoginConfirmPage(qrToken: intent.qrToken),
        ),
      );
      return;
    }

    bool isIMBoyQrcode = barcodeStr.endsWith(qrcodeDataSuffix);
    if (isUrl(barcodeStr) && isIMBoyQrcode) {
      IMBoyHttpResponse resp = await HttpClient.client.get(barcodeStr);
      if (!resp.ok) {
        AppLoading.showError(resp.msg);
        return;
      }
      Map<String, dynamic> payload = resp.payload as Map<String, dynamic>;
      if (kDebugMode) debugPrint("> on qrcode: type=${payload['type']}");
      String result = payload['result'] as String? ?? '';
      String type = payload['type'] as String? ?? 'user';
      if (result == '' && type == 'user') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute<dynamic>(
            builder: (context) => PeopleInfoPage(
              id: parseModelString(payload['id']),
              scene: 'qrcode',
            ),
          ),
        );
      } else if (result == '' && type == 'group') {
        await GroupMemberRepo().save(
          payload['group_member'] as Map<String, dynamic>,
        );
        if (!mounted) return;
        Navigator.push(
          context,
          CupertinoPageRoute<dynamic>(
            builder: (context) => ChatPage(
              peerId: parseModelString(payload['id']),
              peerTitle: payload['title'] as String,
              peerAvatar: payload['avatar'] as String,
              peerSign: '',
              type: 'C2G',
              options: {'memberCount': payload['member_count']},
            ),
          ),
        );
      } else if (result == 'user_not_exist') {
        await _showResult(t.common.userNotExist);
      } else if (result == 'user_is_disabled_or_deleted') {
        // 用户被禁用或已删除
        await _showResult(t.common.userDisabledOrDeleted);
      }
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute<dynamic>(
          builder: (context) => ScannerResultPage(scanResult: barcodeStr),
        ),
      );
    }
  }

  Future<void> _showResult(String txt) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        final isDark = brightness == Brightness.dark;
        return InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(0.0),
            height: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
            alignment: Alignment.center,
            color: isDark
                ? AppColors.darkSurfaceGrouped
                : AppColors.lightSurfaceGrouped,
            child: Center(
              child: Text(
                txt,
                textAlign: TextAlign.left,
                style: context.textStyle(
                  FontSizeType.largeTitle,
                  color: AppColors.getTextColor(brightness),
                ),
              ),
            ),
          ),
        );
      },
      isScrollControlled: true,
      enableDrag: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final scannerState = ref.watch(scannerProvider);

    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: 320,
      height: 320,
    );
    return Scaffold(
      // 相机取景全屏背景，固定纯黑（与明暗主题无关）
      backgroundColor: AppColors.darkBackground,
      body: Builder(
        builder: (context) {
          return Stack(
            children: [
              if (_startFailed) _buildStartErrorView(context),
              if (!_startFailed) ...[
                MobileScanner(
                  fit: BoxFit.contain,
                  scanWindow: scanWindow,
                  controller: controller,
                  onDetect: onDetect,
                ),
                CustomPaint(painter: ScannerOverlay(scanWindow)),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 0, top: 20),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(
                    CupertinoIcons.back,
                    color: AppColors.onPrimary,
                    size: 28,
                  ),
                ),
              ),
              if (!_startFailed)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    height: 100,
                    // 相机控制条半透明蒙层，固定黑底
                    color: AppColors.darkBackground.withValues(alpha: 0.4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: controller,
                          builder: (context, MobileScannerState state, child) {
                            final isTorchOn = state.torchState == TorchState.on;
                            return IconButton(
                              color: AppColors.onPrimary,
                              icon: Icon(
                                isTorchOn ? Icons.flash_on : Icons.flash_off,
                                color: isTorchOn
                                    ? AppColors.iosYellow
                                    : AppColors.onPrimary.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                              iconSize: 32.0,
                              tooltip: isTorchOn
                                  ? t.common.turnOffFlashlight
                                  : t.common.turnOnFlashlight,
                              onPressed: () => controller.toggleTorch(),
                            );
                          },
                        ),
                        IconButton(
                          color: AppColors.onPrimary,
                          icon: scannerState.isStarted
                              ? const Icon(Icons.stop)
                              : const Icon(Icons.play_arrow),
                          iconSize: 32.0,
                          tooltip: scannerState.isStarted
                              ? t.common.pauseScan
                              : t.common.resumeScan,
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
                                t.account.scanQrCode,
                                style: const TextStyle(
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          color: AppColors.onPrimary,
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
                          tooltip: t.common.switchCamera,
                        ),
                        IconButton(
                          color: AppColors.onPrimary,
                          icon: const Icon(Icons.image),
                          iconSize: 32.0,
                          tooltip: t.common.buttonSelectFromAlbum,
                          onPressed: () async {
                            ScaffoldMessengerState state = ScaffoldMessenger.of(
                              context,
                            );
                            if (!scannerState.isStarted) {
                              controller.start();
                            }
                            final media = await CapabilityLocator.I
                                .get<MediaPickerCapability>()
                                .pickSingle(context, MediaType.image);
                            if (media == null) return;
                            if (!mounted) return;
                            BarcodeCapture? res = await controller.analyzeImage(
                              media.path,
                            );
                            if (kDebugMode) {}
                            if (!context.mounted) return;
                            if (res == null) {
                              state.showSnackBar(
                                SnackBar(
                                  content: Text(t.common.noBarcodeFound),
                                  backgroundColor: AppColors.getIosRed(
                                    Theme.of(context).brightness,
                                  ),
                                ),
                              );
                            } else {
                              state.showSnackBar(
                                SnackBar(
                                  content: Text(t.main.barcodeFound),
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
      // 取景框外的全屏蒙层，固定黑底半透明（相机场景，与主题无关）
      ..color = AppColors.darkBackground.withValues(alpha: 0.5)
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
