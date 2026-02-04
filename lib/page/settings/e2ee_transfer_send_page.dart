import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';

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

      // TODO: 需要接收方用户 ID
      // 这里简化处理，实际使用时需要用户输入或选择
      setState(() {
        _errorMessage = '请输入接收方用户 ID';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '初始化失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createTransfer(int toUid) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await E2EETransferService.createTransfer(
        toUid: toUid.toString(),
        encryptedKeyBundle: '', // TODO: 使用接收方公钥加密密钥包
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
                child: const Text('重试'),
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
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('输入接收方用户 ID'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: '接收方用户 ID',
              keyboardType: TextInputType.number,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('创建'),
              onPressed: () {
                final toUid = int.tryParse(controller.text);
                if (toUid == null) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) {
                      return CupertinoAlertDialog(
                        content: const Text('请输入有效的用户 ID'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('确定'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }
                Navigator.pop(context);
                _createTransfer(toUid);
              },
            ),
          ],
        );
      },
    );
  }
}
