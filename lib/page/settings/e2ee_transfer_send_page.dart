import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/i18n/strings.g.dart';

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
    // 延迟初始化，避免布局期间触发 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initTransfer();
      }
    });
  }

  Future<void> _initTransfer() async {
    try {
      // 检查密钥是否存在
      final hasKey = await E2EEKeyService.hasKey();
      if (!hasKey) {
        setState(() {
          _errorMessage = '请先生成密钥对';
          _isLoading = false;
        });
        return;
      }

      // 密钥存在，显示输入对话框让用户输入接收方用户 ID
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '初始化失败: $e';
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
      // 1. 获取接收方的公钥
      final keyData = await E2EEService.getUserDevicePublicKeys(toUid);
      final didToPem = keyData['didToPem'] ?? {};

      if (didToPem.isEmpty) {
        setState(() {
          _errorMessage = '接收方没有可用的公钥';
          _isLoading = false;
        });
        return;
      }

      // 获取第一个可用设备的公钥
      final recipientPublicKey = didToPem.values.first;

      // 2. 构建密钥包
      final storage = StorageSecureService.to;
      final privateKey = await storage.getPrivateKey();
      final publicKey = await storage.getPublicKey();
      final deviceId = await storage.getDeviceId();
      final keyId = await storage.getKeyId();

      if (privateKey == null || publicKey == null) {
        setState(() {
          _errorMessage = '密钥未找到';
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

      // 3. 使用接收方公钥加密密钥包
      final encryptedKeyBundle = await E2EETransferService.encryptKeyBundle(
        keyBundle,
        recipientPublicKey,
      );

      // 4. 创建传输会话
      final result = await E2EETransferService.createTransfer(
        toUid: toUid,
        encryptedKeyBundle: encryptedKeyBundle,
      );
      setState(() {
        _sessionId = result['session_id'] as String;
        _expiresAt = result['expires_at'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '创建传输会话失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发送密钥到新设备'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: Text(t.buttonRetry),
                onPressed: () {
                  // 显示输入对话框
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
          child: const Text('创建传输会话'),
        ),
      );
    }

    return _buildQRCodeView();
  }

  Widget _buildQRCodeView() {
    final qrData = E2EETransferService.generateQRCodeData(_sessionId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.qr_code_2,
            size: 48,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(height: 16),
          const Text(
            '请在新设备上扫描此二维码',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '二维码将在 $_expiresAt 过期',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
          const SizedBox(height: 24),
          Text(
            '会话 ID: $_sessionId',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          CupertinoButton.filled(
            child: const Text('刷新二维码'),
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
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('输入接收方用户 ID'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: '接收方用户 ID',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(t.cancel),
              onPressed: () {
                Navigator.pop(ctx);
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('创建'),
              onPressed: () {
                final toUid = controller.text.trim();
                if (toUid.isEmpty) {
                  showCupertinoDialog(
                    context: context,
                    builder: (c) {
                      return CupertinoAlertDialog(
                        content: const Text('请输入有效的用户 ID'),
                        actions: [
                          CupertinoDialogAction(
                            child: Text(t.confirm),
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
