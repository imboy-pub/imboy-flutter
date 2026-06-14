import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// E2EE 备份导入页面
///
/// 功能：
/// - 选择备份文件
/// - 验证文件格式
/// - 输入密码解密
/// - 恢复私钥到安全存储
class E2EEBackupImportPage extends StatefulWidget {
  final String? initialFilePath;

  const E2EEBackupImportPage({super.key, this.initialFilePath});

  @override
  // ignore: library_private_types_in_public_api
  _E2EEBackupImportPageState createState() => _E2EEBackupImportPageState();
}

class _E2EEBackupImportPageState extends State<E2EEBackupImportPage> {
  final _passwordController = TextEditingController();
  bool _isImporting = false;
  File? _selectedFile;
  Map<String, dynamic>? _backupInfo;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _selectedFile = File(widget.initialFilePath!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _verifyFile();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.common.e2eeBackupImportTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.common.buttonBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        children: [
          _buildWarningCard(),
          const SizedBox(height: 24),
          _buildFileSelector(),
          if (_backupInfo != null) ...[
            const SizedBox(height: 16),
            _buildBackupInfoCard(),
          ],
          const SizedBox(height: 24),
          _buildPasswordSection(),
          const SizedBox(height: 24),
          _buildImportButton(),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.iosOrange),
                const SizedBox(width: 8),
                Text(
                  t.common.e2eeBackupImportGuide,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.common.e2eeBackupImportReplaceKey,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 4),
            Text(
              t.common.e2eeBackupImportTrustedSource,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.common.e2eeBackupSelectFile,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.regular),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      color: _selectedFile != null
                          ? AppColors.iosGreen
                          : AppColors.iosGray,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? (_selectedFile!.path.split('/').last)
                          : t.common.e2eeBackupSelectFileHint,
                      style: TextStyle(
                        color: _selectedFile != null
                            ? AppColors.iosGreen
                            : Colors.grey.shade600,
                        fontSize: FontSizeType.small.size,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupInfoCard() {
    if (_backupInfo == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.iosBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.common.e2eeBackupInfoTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.check_circle,
                  color: AppColors.iosGreen,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              t.common.e2eeBackupVersionLabel,
              _backupInfo!['version'].toString(),
            ),
            _buildInfoRow(
              t.common.e2eeBackupAlgorithmLabel,
              _backupInfo!['algorithm'].toString(),
            ),
            _buildInfoRow(
              t.common.e2eeBackupFileSizeLabel,
              '${_backupInfo!['file_size']} bytes',
            ),
            const SizedBox(height: 8),
            Text(
              t.common.e2eeBackupFileValid,
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: AppColors.iosGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupPwdLabel,
        hintText: t.common.e2eeBackupImportPwdHint,
        prefixIcon: const Icon(Icons.lock),
        border: const OutlineInputBorder(),
        suffixIcon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
      enabled: _backupInfo != null,
    );
  }

  Widget _buildImportButton() {
    final isEnabled =
        _passwordController.text.isNotEmpty &&
        _backupInfo != null &&
        !_isImporting;

    return ElevatedButton(
      onPressed: isEnabled ? _handleImport : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: isEnabled ? null : AppColors.iosGray,
      ),
      child: _isImporting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(t.common.e2eeBackupImportBtn),
    );
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['enc'],
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _backupInfo = null;
        });
        await _verifyFile();
      }
    } on Exception {
      _showError(t.common.e2eeBackupErrSelectFile);
    }
  }

  Future<void> _verifyFile() async {
    if (_selectedFile == null) return;

    try {
      final info = await E2EELocalBackupService.verifyBackupFile(
        _selectedFile!.path,
      );
      setState(() => _backupInfo = info);
    } on Exception {
      setState(() {
        _backupInfo = null;
      });
      _showError(t.common.e2eeBackupErrValidateFailed);
    }
  }

  Future<void> _handleImport() async {
    final password = _passwordController.text;

    try {
      setState(() => _isImporting = true);

      final result = await E2EELocalBackupService.importBackup(
        filePath: _selectedFile!.path,
        password: password,
      );

      await StorageSecureService.to.savePrivateKey(
        result['private_key'] as String,
      );
      await StorageSecureService.to.savePublicKey(
        result['public_key'] as String,
      );
      await StorageSecureService.to.setDeviceId(result['device_id'] as String);
      await StorageSecureService.to.setKeyId(result['key_id'] as String);

      setState(() => _isImporting = false);

      _showSuccessDialog(result);
    } on Exception {
      setState(() => _isImporting = false);
      _showError(t.common.e2eeBackupErrImportFailed);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(t.common.e2eeBackupImportSuccessTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.common.e2eeBackupImportSuccessBody),
            const SizedBox(height: 12),
            Text(
              'Device ID: ${_maskId(result['device_id']?.toString() ?? '')}',
            ),
            Text('Key ID: ${_maskId(result['key_id']?.toString() ?? '')}'),
            Text('${t.common.e2eeBackupCreatedAtRow}: ${result['created_at']}'),
            const SizedBox(height: 12),
            Text(
              t.common.e2eeBackupImportSuccessNote,
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(t.common.buttonAccomplish),
          ),
        ],
      ),
    );
  }

  /// 脱敏 ID 显示（只显示前4位和后4位）
  String _maskId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.iosRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
