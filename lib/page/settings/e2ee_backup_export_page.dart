import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/e2ee_server_backup_service.dart';
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
  bool _isCloudUploading = false;
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
    return IosPageTemplate(
      title: t.common.e2eeBackupExportTitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          children: [
            _buildWarningCard(),
            const SizedBox(height: AppSpacing.xLarge),
            _buildPasswordSection(),
            const SizedBox(height: AppSpacing.regular),
            _buildConfirmPasswordSection(),
            const SizedBox(height: AppSpacing.small),
            _buildRecoveryKeyButton(),
            const SizedBox(height: AppSpacing.regular),
            _buildNotesSection(),
            const SizedBox(height: AppSpacing.xLarge),
            _buildPasswordStrengthIndicator(),
            const SizedBox(height: AppSpacing.xLarge),
            _buildExportButton(),
            const SizedBox(height: AppSpacing.regular),
            _buildCloudUploadButton(),
            if (_generatedFilePath != null) ...[
              const SizedBox(height: AppSpacing.regular),
              _buildShareButton(),
            ],
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
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: AppColors.iosOrange,
                ),
                const SizedBox(width: AppSpacing.small),
                Text(
                  t.common.e2eeImportantNote,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.iosOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              t.common.e2eeBackupPwdCantRecover,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosOrange,
              ),
            ),
            const SizedBox(height: AppSpacing.tiny),
            Text(
              t.common.e2eeBackupStoreMultipleNote,
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

  Widget _buildPasswordSection() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupPwdLabel,
        hintText: t.common.e2eeBackupPwdHint,
        prefixIcon: const Icon(CupertinoIcons.lock),
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
        prefixIcon: const Icon(CupertinoIcons.lock_fill),
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// 生成恢复密钥：填入口令/确认字段，并弹窗展示供用户保存（Matrix 4S 第二把钥匙）。
  Widget _buildRecoveryKeyButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(CupertinoIcons.wand_stars, size: 18),
        label: Text(t.common.e2eeUseRecoveryKey),
        onPressed: _generateRecoveryKey,
      ),
    );
  }

  void _generateRecoveryKey() {
    final key = E2EECryptoService.generateRecoveryKey();
    _passwordController.text = key;
    _confirmPasswordController.text = key;
    setState(() {});
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.e2eeRecoveryKeyTitle),
        content: Column(
          children: [
            const SizedBox(height: AppSpacing.small),
            SelectableText(
              key,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              t.common.e2eeRecoveryKeySaveNote,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosOrange,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (ctx.mounted) Navigator.pop(ctx);
              AppLoading.showSuccess(t.common.e2eeRecoveryKeyCopied);
            },
            child: Text(t.common.buttonCopy),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return TextField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupNoteLabel,
        hintText: t.common.e2eeBackupNoteHint,
        prefixIcon: const Icon(CupertinoIcons.doc_text),
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
          style: context.textStyle(
            FontSizeType.small,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        LinearProgressIndicator(
          value: strength,
          backgroundColor: AppColors.iosGray5,
          color: _getStrengthColor(strength),
          minHeight: 8,
        ),
        const SizedBox(height: AppSpacing.tiny),
        Text(
          _getStrengthLabel(strength),
          style: context.textStyle(
            FontSizeType.small,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getStrengthColor(double strength) {
    if (strength < 0.3) return AppColors.iosRed;
    if (strength < 0.6) return AppColors.iosOrange;
    if (strength < 0.8) return AppColors.iosYellow;
    return AppColors.iosGreen;
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
        backgroundColor: isEnabled ? null : AppColors.iosGray,
      ),
      child: _isExporting
          ? const SizedBox(
              height: AppSpacing.large,
              width: AppSpacing.large,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(t.common.e2eeBackupGenerateBtn),
    );
  }

  Widget _buildCloudUploadButton() {
    final isEnabled =
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        !_isExporting &&
        !_isCloudUploading;

    return OutlinedButton.icon(
      onPressed: isEnabled ? _handleCloudUpload : null,
      icon: _isCloudUploading
          ? const SizedBox(
              height: AppSpacing.large,
              width: AppSpacing.large,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(CupertinoIcons.cloud_upload),
      label: Text(t.common.e2eeBackupCloudUploadBtn),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildShareButton() {
    return Card(
      color: AppColors.iosGreen.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: AppColors.iosGreen,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    t.common.e2eeBackupFileGenerated,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.iosGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'File: ${_generatedFilePath?.split('/').last ?? ""}',
              style: context
                  .textStyle(FontSizeType.small)
                  .copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: AppSpacing.medium),
            OutlinedButton.icon(
              onPressed: _handleShare,
              icon: const Icon(CupertinoIcons.share),
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

      final keys = await _readKeys();
      if (keys == null) {
        if (mounted) _showError(t.common.e2eeBackupErrNoKeyData);
        return;
      }

      final filePath = await E2EELocalBackupService.exportBackup(
        password: password,
        privateKey: keys.privateKey,
        publicKey: keys.publicKey,
        deviceId: keys.deviceId,
        keyId: keys.keyId,
        userNotes: _notesController.text,
      );

      if (!mounted) return;
      setState(() => _generatedFilePath = filePath);
      _showSuccessDialog();
    } on Exception {
      if (mounted) _showError(t.common.e2eeBackupErrExportFailed);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// 备份到云端：复用同一密码输入与密钥读取，服务内部已对
  /// 版本冲突自动重试一次，此处失败即提示。
  Future<void> _handleCloudUpload() async {
    final password = _passwordController.text;

    if (password != _confirmPasswordController.text) {
      _showError(t.common.e2eeBackupErrPwdMismatch);
      return;
    }

    try {
      setState(() => _isCloudUploading = true);

      final keys = await _readKeys();
      if (keys == null) {
        if (mounted) _showError(t.common.e2eeBackupErrNoKeyData);
        return;
      }

      final result = await E2EEServerBackupService.upload(
        password: password,
        privateKey: keys.privateKey,
        publicKey: keys.publicKey,
        deviceId: keys.deviceId,
        keyId: keys.keyId,
      );

      if (!mounted) return;
      if (result.ok) {
        _showSuccess(
          t.common.e2eeBackupCloudUploadSuccess(version: result.backupVersion),
        );
      } else {
        _showError(t.common.e2eeBackupErrCloudUploadFailed);
      }
    } on Exception {
      if (mounted) _showError(t.common.e2eeBackupErrCloudUploadFailed);
    } finally {
      if (mounted) setState(() => _isCloudUploading = false);
    }
  }

  /// 从安全存储读取密钥四元组；私钥/公钥缺失返回 null
  Future<
    ({String privateKey, String publicKey, String deviceId, String keyId})?
  >
  _readKeys() async {
    final privateKey = await StorageSecureService.to.getPrivateKey();
    final publicKey = await StorageSecureService.to.getPublicKey();
    final deviceId = await StorageSecureService.to.getDeviceId();
    final keyId = await StorageSecureService.to.getKeyId();

    if (privateKey == null || publicKey == null) return null;
    return (
      privateKey: privateKey,
      publicKey: publicKey,
      deviceId: deviceId ?? 'unknown',
      keyId: keyId ?? 'unknown',
    );
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
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.e2eeBackupExportSuccessTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(t.common.e2eeBackupExportSuccessBody),
            const SizedBox(height: AppSpacing.medium),
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
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.main.gotIt),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.getIosGreen(Theme.of(context).brightness),
        duration: const Duration(seconds: 3),
      ),
    );
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
