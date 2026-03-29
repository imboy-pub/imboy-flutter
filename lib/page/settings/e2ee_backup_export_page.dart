import 'package:flutter/material.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/storage_secure.dart';

/// E2EE 备份导出页面
///
/// 功能：
/// - 输入并验证备份密码
/// - 显示密码强度指示器
/// - 生成加密备份文件
/// - 提供分享选项（邮件/云盘）
class E2EEBackupExportPage extends StatefulWidget {
  const E2EEBackupExportPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _E2EEBackupExportPageState createState() => _E2EEBackupExportPageState();
}

class _E2EEBackupExportPageState extends State<E2EEBackupExportPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isExporting = false;
  String? _generatedFilePath;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导出 E2EE 备份'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWarningCard(),
          const SizedBox(height: 24),
          _buildPasswordSection(),
          const SizedBox(height: 16),
          _buildConfirmPasswordSection(),
          const SizedBox(height: 16),
          _buildNotesSection(),
          const SizedBox(height: 24),
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 24),
          _buildExportButton(),
          if (_generatedFilePath != null) ...[
            const SizedBox(height: 16),
            _buildShareButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '重要提示',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• 备份密码无法找回，请务必牢记！',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 4),
            Text(
              '• 建议将备份文件存储到多个安全位置（邮件、云盘、U盘）',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: '备份密码 *',
        hintText: '至少 12 位，包含大小写字母、数字和特殊符号',
        prefixIcon: Icon(Icons.lock_outline),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildConfirmPasswordSection() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: '确认密码 *',
        hintText: '再次输入密码',
        prefixIcon: Icon(Icons.lock),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildNotesSection() {
    return TextField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: '备注（可选）',
        hintText: '例如：主手机备份 - 2026年1月',
        prefixIcon: Icon(Icons.note),
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    final strength = E2EELocalBackupService.calculatePasswordStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '密码强度',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: strength,
          backgroundColor: Colors.grey.shade200,
          color: _getStrengthColor(strength),
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text(
          _getStrengthLabel(strength),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Color _getStrengthColor(double strength) {
    if (strength < 0.3) return Colors.red;
    if (strength < 0.6) return Colors.orange;
    if (strength < 0.8) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getStrengthLabel(double strength) {
    if (strength < 0.3) return '弱 - 建议增加复杂度';
    if (strength < 0.6) return '中等 - 建议增加长度或复杂度';
    if (strength < 0.8) return '强 - 可以使用';
    return '非常强 - 安全';
  }

  Widget _buildExportButton() {
    final isEnabled =
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        !_isExporting;

    return ElevatedButton(
      onPressed: isEnabled ? _handleExport : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: isEnabled ? null : Colors.grey,
      ),
      child: _isExporting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('生成备份文件'),
    );
  }

  Widget _buildShareButton() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '备份文件已生成！',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '文件路径: ${_generatedFilePath ?? ""}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _handleShare,
              icon: const Icon(Icons.share),
              label: const Text('通过邮件/云盘分享'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 验证密码
    if (password != confirmPassword) {
      _showError('两次输入的密码不一致');
      return;
    }

    try {
      setState(() => _isExporting = true);

      // 获取密钥数据
      final privateKey = await StorageSecureService.to.getPrivateKey();
      final publicKey = await StorageSecureService.to.getPublicKey();
      final deviceId = await StorageSecureService.to.getDeviceId();
      final keyId = await StorageSecureService.to.getKeyId();

      if (privateKey == null || publicKey == null) {
        _showError('无法获取密钥数据');
        return;
      }

      // 生成备份文件
      final filePath = await E2EELocalBackupService.exportBackup(
        password: password,
        privateKey: privateKey,
        publicKey: publicKey,
        deviceId: deviceId ?? 'unknown',
        keyId: keyId ?? 'unknown',
        userNotes: _notesController.text,
      );

      setState(() {
        _generatedFilePath = filePath;
        _isExporting = false;
      });

      // 显示成功对话框
      _showSuccessDialog();
    } catch (e) {
      setState(() => _isExporting = false);
      _showError('导出失败: ${e.toString()}');
    }
  }

  Future<void> _handleShare() async {
    if (_generatedFilePath == null) return;

    try {
      await E2EELocalBackupService.shareBackup(
        _generatedFilePath!,
        shareText: '这是我的 Imboy E2EE 密钥备份文件，请妥善保管，切勿泄露给他人。',
      );
    } catch (e) {
      _showError('分享失败: ${e.toString()}');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('备份导出成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('您的 E2EE 密钥备份已成功生成。'),
            const SizedBox(height: 12),
            const Text('重要提示：', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('• 请妥善保管备份文件和密码'),
            const Text('• 建议将文件存储到多个安全位置'),
            const Text('• 密码无法找回，请务必牢记'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
