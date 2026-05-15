import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
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
        title: Text(t.common.e2eeBackupExportTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.common.buttonBack,
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
                  t.common.e2eeImportantNote,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.common.e2eeBackupPwdCantRecover,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 4),
            Text(
              t.common.e2eeBackupStoreMultipleNote,
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
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupPwdLabel,
        hintText: t.common.e2eeBackupPwdHint,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildConfirmPasswordSection() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupConfirmPwdLabel,
        hintText: t.common.e2eeBackupConfirmPwdHint,
        prefixIcon: const Icon(Icons.lock),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildNotesSection() {
    return TextField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupNoteLabel,
        hintText: t.common.e2eeBackupNoteHint,
        prefixIcon: const Icon(Icons.note),
        border: const OutlineInputBorder(),
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
        Text(
          t.common.e2eeBackupPwdStrengthLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
    if (strength < 0.3) return t.common.e2eeBackupPwdWeak;
    if (strength < 0.6) return t.common.e2eeBackupPwdMedium;
    if (strength < 0.8) return t.common.e2eeBackupPwdStrong;
    return t.common.e2eeBackupPwdVeryStrong;
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
          : Text(t.common.e2eeBackupGenerateBtn),
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
                    t.common.e2eeBackupFileGenerated,
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
              'File: ${_generatedFilePath?.split('/').last ?? ""}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _handleShare,
              icon: const Icon(Icons.share),
              label: Text(t.common.e2eeBackupShareBtn),
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

    if (password != confirmPassword) {
      _showError(t.common.e2eeBackupErrPwdMismatch);
      return;
    }

    try {
      setState(() => _isExporting = true);

      final privateKey = await StorageSecureService.to.getPrivateKey();
      final publicKey = await StorageSecureService.to.getPublicKey();
      final deviceId = await StorageSecureService.to.getDeviceId();
      final keyId = await StorageSecureService.to.getKeyId();

      if (privateKey == null || publicKey == null) {
        _showError(t.common.e2eeBackupErrNoKeyData);
        return;
      }

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

      _showSuccessDialog();
    } on Exception {
      setState(() => _isExporting = false);
      _showError(t.common.e2eeBackupErrExportFailed);
    }
  }

  Future<void> _handleShare() async {
    if (_generatedFilePath == null) return;

    try {
      await E2EELocalBackupService.shareBackup(
        _generatedFilePath!,
        shareText: t.common.e2eeBackupShareContent,
      );
    } on Exception {
      _showError(t.common.e2eeBackupErrShareFailed);
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(t.common.e2eeBackupExportSuccessTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.common.e2eeBackupExportSuccessBody),
            const SizedBox(height: 12),
            Text(
              t.common.e2eeBackupImportantNoteColon,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(t.common.e2eeBackupKeepSafe),
            Text(t.common.e2eeBackupStoreMultipleLoc),
            Text(t.common.e2eeBackupPwdCantRecoverNote),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.main.gotIt),
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
