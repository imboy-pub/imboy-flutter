import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/storage_secure.dart';

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

  @override
  void initState() {
    super.initState();
    // 延迟接受传输，避免布局期间触发 setState
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
        _statusMessage = '正在接受传输...';
      });

      // 获取当前设备的设备 ID
      final deviceId = await StorageSecure().getDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        // 生成新设备 ID
        await E2EEKeyService.generateKeyPair();
        final newDeviceId = await StorageSecure().getDeviceId();
        if (newDeviceId == null || newDeviceId.isEmpty) {
          throw Exception('无法获取设备 ID');
        }
      }

      final result = await E2EETransferService.acceptTransfer(
        sessionId: sessionId,
        deviceId: deviceId ?? await StorageSecure().getDeviceId() ?? '',
      );

      // 确认传输
      await E2EETransferService.confirmTransfer(sessionId: sessionId);

      if (mounted) {
        setState(() {
          _statusMessage = '传输成功！';
        });

        showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: const Text('传输成功'),
              content: Text('密钥已成功从设备 ${result['from_device_id']} 传输'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('确定'),
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '传输失败: $e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('从旧设备接收密钥'),
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
    if (widget.sessionId != null) {
      return _buildStatusView();
    }

    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) {
        return Center(child: Text('扫描错误: $error'));
      },
    );
  }

  Widget _buildStatusView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_statusMessage == '传输成功！')
              const Icon(Icons.check_circle, size: 64, color: Colors.green)
            else if (_statusMessage?.contains('失败') == true)
              const Icon(Icons.error, size: 64, color: Colors.red)
            else
              const SizedBox(
                width: 64,
                height: 64,
                child: CupertinoActivityIndicator(),
              ),
            const SizedBox(height: 24),
            Text(
              _statusMessage ?? '处理中...',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_statusMessage?.contains('失败') == true) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: const Text('重试'),
                onPressed: () {
                  setState(() {
                    _statusMessage = null;
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
