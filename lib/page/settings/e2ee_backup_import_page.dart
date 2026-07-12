import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/e2ee_server_backup_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
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
  final _cloudPasswordController = TextEditingController();
  bool _isImporting = false;
  bool _isCloudRestoring = false;
  File? _selectedFile;
  Map<String, dynamic>? _backupInfo;
  E2EEBackupInfo? _cloudInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_probeCloudBackup());
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
    _cloudPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IosPageTemplate(
      title: t.common.e2eeBackupImportTitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          children: [
            _buildWarningCard(),
            if (_cloudInfo?.hasBackup == true) ...[
              const SizedBox(height: AppSpacing.regular),
              _buildCloudRestoreCard(),
            ],
            const SizedBox(height: AppSpacing.xLarge),
            _buildFileSelector(),
            if (_backupInfo != null) ...[
              const SizedBox(height: AppSpacing.regular),
              _buildBackupInfoCard(),
            ],
            const SizedBox(height: AppSpacing.xLarge),
            _buildPasswordSection(),
            const SizedBox(height: AppSpacing.xLarge),
            _buildImportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: AppColors.iosOrange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.info, color: AppColors.iosOrange),
                const SizedBox(width: AppSpacing.small),
                Text(
                  t.common.e2eeBackupImportGuide,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.iosOrange,
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupImportReplaceKey,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosOrange,
              ),
            ),
            AppSpacing.verticalTiny,
            Text(
              t.common.e2eeBackupImportTrustedSource,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudRestoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.cloud_download,
                  color: AppColors.iosBlue,
                ),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    t.common.e2eeBackupCloudRestoreTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.iosBlue,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupCloudRestoreHint(
                version: _cloudInfo?.backupVersion ?? 0,
              ),
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.verticalMedium,
            OutlinedButton.icon(
              onPressed: _isCloudRestoring ? null : _promptCloudRestore,
              icon: _isCloudRestoring
                  ? const SizedBox(
                      height: AppSpacing.large,
                      width: AppSpacing.large,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.cloud_download),
              label: Text(t.common.e2eeBackupCloudRestoreBtn),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
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
            AppSpacing.verticalMedium,
            InkWell(
              onTap: _selectFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.regular),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.iosGray4),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.cloud_upload,
                      color: _selectedFile != null
                          ? AppColors.iosGreen
                          : AppColors.iosGray,
                      size: 48,
                    ),
                    AppSpacing.verticalSmall,
                    Text(
                      _selectedFile != null
                          ? (_selectedFile!.path.split('/').last)
                          : t.common.e2eeBackupSelectFileHint,
                      style: context.textStyle(
                        FontSizeType.small,
                        color: _selectedFile != null
                            ? AppColors.iosGreen
                            : AppColors.iosGray,
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
                const Icon(CupertinoIcons.info, color: AppColors.iosBlue),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    t.common.e2eeBackupInfoTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.iosBlue,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: AppColors.iosGreen,
                  size: 20,
                ),
              ],
            ),
            AppSpacing.verticalMedium,
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
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupFileValid,
              style: context.textStyle(
                FontSizeType.small,
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
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: context.textStyle(FontSizeType.footnote)),
          ),
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
        prefixIcon: const Icon(CupertinoIcons.lock_fill),
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

      await _applyRestoredKeys(result);
    } on Exception {
      if (mounted) _showError(t.common.e2eeBackupErrImportFailed);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 云端备份存在性探测（决定是否显示"从云端恢复"入口）
  Future<void> _probeCloudBackup() async {
    try {
      final info = await E2EEBackupApi().info();
      if (!mounted) return;
      setState(() => _cloudInfo = info);
    } on Exception {
      // 探测失败按无云端备份处理，不打扰用户
    }
  }

  /// 弹出口令输入确认框（恢复会覆盖本地密钥，需显式确认）
  Future<void> _promptCloudRestore() async {
    _cloudPasswordController.clear();
    final password = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.e2eeBackupCloudRestoreTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(t.common.e2eeBackupCloudRestoreConfirmNote),
            AppSpacing.verticalSmall,
            CupertinoTextField(
              controller: _cloudPasswordController,
              obscureText: true,
              autofocus: true,
              placeholder: t.common.e2eeBackupCloudPwdHint,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(context).pop(_cloudPasswordController.text),
            child: Text(t.common.e2eeBackupCloudRestoreBtn),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty || !mounted) return;
    await _handleCloudRestore(password);
  }

  Future<void> _handleCloudRestore(String password) async {
    try {
      setState(() => _isCloudRestoring = true);

      final result = await E2EEServerBackupService.restore(password: password);

      await _applyRestoredKeys(result);
    } on StateError {
      if (mounted) _showError(t.common.e2eeBackupErrNoCloudBackup);
    } on ArgumentError {
      if (mounted) _showError(t.common.e2eeBackupErrCloudPwd);
    } on Exception {
      if (mounted) _showError(t.common.e2eeBackupErrCloudRestoreFailed);
    } finally {
      if (mounted) setState(() => _isCloudRestoring = false);
    }
  }

  /// 恢复成功后的统一后处理：保存密钥四元组到安全存储 + 成功弹窗。
  /// 文件导入与云端恢复两条路径共用。
  Future<void> _applyRestoredKeys(Map<String, dynamic> result) async {
    await StorageSecureService.to.savePrivateKey(
      result['private_key'] as String,
    );
    await StorageSecureService.to.savePublicKey(result['public_key'] as String);
    await StorageSecureService.to.setDeviceId(result['device_id'] as String);
    await StorageSecureService.to.setKeyId(result['key_id'] as String);

    if (!mounted) return;
    _showSuccessDialog(result);
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.e2eeBackupImportSuccessTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(t.common.e2eeBackupImportSuccessBody),
            AppSpacing.verticalMedium,
            Text(
              'Device ID: ${_maskId(result['device_id']?.toString() ?? '')}',
            ),
            Text('Key ID: ${_maskId(result['key_id']?.toString() ?? '')}'),
            Text('${t.common.e2eeBackupCreatedAtRow}: ${result['created_at']}'),
            AppSpacing.verticalMedium,
            Text(
              t.common.e2eeBackupImportSuccessNote,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
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
        backgroundColor: AppColors.getIosRed(Theme.of(context).brightness),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
