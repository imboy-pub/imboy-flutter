import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// E2EE 密钥传输 - 发送页面
/// 显示二维码，供新设备扫描
class E2EETransferSendPage extends StatefulWidget {
  const E2EETransferSendPage({super.key});

  @override
  State<E2EETransferSendPage> createState() => _E2EETransferSendPageState();
}

class _E2EETransferSendPageState extends State<E2EETransferSendPage> {
  bool _isLoading = true;
  String? _sessionId;
  String? _expiresAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initTransfer();
      }
    });
  }

  Future<void> _initTransfer() async {
    try {
      final hasKey = await E2EEKeyService.hasKey();
      if (!hasKey) {
        setState(() {
          _errorMessage = t.common.e2eeTransferErrNoKey;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } on Exception {
      setState(() {
        _errorMessage = t.common.e2eeTransferErrInitFailed;
        _isLoading = false;
      });
    }
  }

  Future<void> _createTransfer(String toUid) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final keyData = await E2EEService.getUserDevicePublicKeys(toUid);
      final didToPem = keyData['didToPem'] ?? {};

      if (didToPem.isEmpty) {
        setState(() {
          _errorMessage = t.common.e2eeTransferErrNoRecipientKey;
          _isLoading = false;
        });
        return;
      }

      final recipientPublicKey = didToPem.values.first;

      final storage = StorageSecureService.to;
      final privateKey = await storage.getPrivateKey();
      final publicKey = await storage.getPublicKey();
      final deviceId = await storage.getDeviceId();
      final keyId = await storage.getKeyId();

      if (privateKey == null || publicKey == null) {
        setState(() {
          _errorMessage = t.common.e2eeTransferErrKeyNotFound;
          _isLoading = false;
        });
        return;
      }

      final keyBundle = {
        'private_key': privateKey,
        'public_key': publicKey,
        'device_id': deviceId,
        'key_id': keyId,
      };

      final encryptedKeyBundle = await E2EETransferService.encryptKeyBundle(
        keyBundle,
        recipientPublicKey,
      );

      final result = await E2EETransferService.createTransfer(
        toUid: toUid,
        fromDeviceId: deviceId ?? '',
        encryptedKeyBundle: encryptedKeyBundle,
      );
      setState(() {
        _sessionId = result['session_id'] as String;
        _expiresAt = result['expires_at'] as String;
        _isLoading = false;
      });
    } on Exception {
      setState(() {
        _errorMessage = t.common.e2eeTransferErrCreateFailed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.chat.e2eeTransferSendTitle),
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
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.iosRed,
              ),
              const SizedBox(height: AppSpacing.regular),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xLarge),
              CupertinoButton.filled(
                child: Text(t.common.buttonRetry),
                onPressed: () {
                  _showToUidDialog();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_sessionId == null) {
      return Center(
        child: CupertinoButton.filled(
          onPressed: _showToUidDialog,
          child: Text(t.common.e2eeTransferCreateSessionBtn),
        ),
      );
    }

    return _buildQRCodeView();
  }

  Widget _buildQRCodeView() {
    final qrData = E2EETransferService.generateQRCodeData(_sessionId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      child: Column(
        children: [
          const Icon(
            Icons.qr_code_2,
            size: 48,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(height: AppSpacing.regular),
          Text(
            t.main.e2eeTransferQRHint,
            style: context.textStyle(
              FontSizeType.large,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            t.main.e2eeTransferQRExpiry(time: _expiresAt ?? ''),
            style: const TextStyle(color: AppColors.iosGray),
          ),
          const SizedBox(height: AppSpacing.xxLarge),
          Container(
            padding: const EdgeInsets.all(AppSpacing.regular),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: AppRadius.borderRadiusMedium,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lightTextPrimary.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250,
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text(
            t.common.e2eeTransferSessionCreated,
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.iosGray,
            ),
          ),
          const SizedBox(height: AppSpacing.xxLarge),
          CupertinoButton.filled(
            child: Text(t.main.e2eeTransferRefreshQR),
            onPressed: () {
              setState(() {
                _sessionId = null;
              });
              _showToUidDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showToUidDialog() {
    final controller = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: Text(t.main.e2eeTransferEnterUidTitle),
          content: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.medium),
            child: CupertinoTextField(
              controller: controller,
              placeholder: t.main.e2eeTransferUidPlaceholder,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(t.common.cancel),
              onPressed: () {
                Navigator.pop(ctx);
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text(t.chat.e2eeTransferCreateBtn),
              onPressed: () {
                final toUid = controller.text.trim();
                if (toUid.isEmpty) {
                  showCupertinoDialog<void>(
                    context: context,
                    builder: (c) {
                      return CupertinoAlertDialog(
                        content: Text(t.common.e2eeTransferUidEmptyError),
                        actions: [
                          CupertinoDialogAction(
                            child: Text(t.common.confirm),
                            onPressed: () => Navigator.pop(c),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }
                Navigator.pop(ctx);
                _createTransfer(toUid);
              },
            ),
          ],
        );
      },
    );
  }
}
