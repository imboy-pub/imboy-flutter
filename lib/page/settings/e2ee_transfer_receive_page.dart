import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart'
    show kE2eeRecoveryNeededKey;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// E2EE 密钥传输 - 接收页面
/// 扫描旧设备的二维码接收密钥
class E2EETransferReceivePage extends StatefulWidget {
  final String? sessionId;

  const E2EETransferReceivePage({super.key, this.sessionId});

  @override
  State<E2EETransferReceivePage> createState() =>
      _E2EETransferReceivePageState();
}

class _E2EETransferReceivePageState extends State<E2EETransferReceivePage> {
  final _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _statusMessage;
  // Dedicated flag instead of string comparisons to avoid locale-dependent bugs
  bool _isSuccess = false;
  bool _isFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _acceptTransfer(widget.sessionId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final code = capture.barcodes.first;
    if (code.rawValue == null) return;

    final data = E2EETransferService.parseQRCodeData(code.rawValue!);
    if (data == null) return;

    final sessionId = data['session_id'] as String?;
    if (sessionId == null) return;

    setState(() {
      _isProcessing = true;
    });

    await _acceptTransfer(sessionId);
  }

  Future<void> _acceptTransfer(String sessionId) async {
    try {
      setState(() {
        _statusMessage = t.main.e2eeTransferReceiving;
        _isSuccess = false;
        _isFailed = false;
      });

      final deviceId = await StorageSecureService.to.getDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        await E2EEKeyService.generateKeyPair();
        final newDeviceId = await StorageSecureService.to.getDeviceId();
        if (newDeviceId == null || newDeviceId.isEmpty) {
          throw Exception(t.common.e2eeTransferErrNoDeviceId);
        }
      }

      await E2EETransferService.acceptTransfer(
        sessionId: sessionId,
        deviceId: deviceId ?? await StorageSecureService.to.getDeviceId() ?? '',
      );

      await E2EETransferService.confirmTransfer(sessionId: sessionId);

      if (mounted) {
        setState(() {
          _statusMessage = t.common.e2eeTransferSuccess;
          _isSuccess = true;
          _isFailed = false;
        });

        // 与社交恢复一致：设备转移恢复私钥后，清 E2EE 解密缓存并清除
        // 「恢复待办」横幅标记，使本地密文消息用新私钥重新解密显示。
        E2EEService.clearCache();
        unawaited(StorageService.to.setBool(kE2eeRecoveryNeededKey, false));

        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(t.common.e2eeTransferSuccessTitle),
              content: Text(t.common.e2eeTransferSuccessBody),
              actions: [
                CupertinoDialogAction(
                  child: Text(t.common.buttonOk),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _statusMessage = t.common.e2eeTransferFailed;
          _isSuccess = false;
          _isFailed = true;
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.chat.e2eeTransferReceiveTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.common.buttonBack,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.sessionId != null) {
      return _buildStatusView();
    }

    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) {
        return Center(
          child: Text(t.common.e2eeTransferScanError(error: error.toString())),
        );
      },
    );
  }

  Widget _buildStatusView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSuccess)
              const Icon(
                Icons.check_circle,
                size: 64,
                color: AppColors.iosGreen,
              )
            else if (_isFailed)
              const Icon(Icons.error, size: 64, color: AppColors.iosRed)
            else
              const SizedBox(
                width: 64,
                height: 64,
                child: CupertinoActivityIndicator(),
              ),
            const SizedBox(height: 24),
            Text(
              _statusMessage ?? t.common.e2eeTransferProcessingMsg,
              style: TextStyle(fontSize: FontSizeType.medium.size),
              textAlign: TextAlign.center,
            ),
            if (_isFailed) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: Text(t.common.buttonRetry),
                onPressed: () {
                  setState(() {
                    _statusMessage = null;
                    _isSuccess = false;
                    _isFailed = false;
                    _isProcessing = false;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
