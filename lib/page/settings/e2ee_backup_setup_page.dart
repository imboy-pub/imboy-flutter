import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_backup_setup_service.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/service/e2ee_server_backup_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// E2EE 云端备份设置向导（发生率压降路径3·首次启用强制）。
///
/// - **不可跳过**：导航栏无返回键 + PopScope 拦截系统返回；仅在上传失败
///   一次后开放「稍后再说」（完成标记不落，下次启动会重新触发本向导）。
/// - **凭据二选一**：自选恢复口令（≥8 位，<12 位给弱口令提示），或一键
///   生成 160-bit 随机恢复密钥（与导出页同款交互与剪贴板 60s 清除）。
/// - **成功回执**：口令缓存进安全存储 + 落完成标记 → 弹成功（版本号）→
///   关页。此后密钥变化由 [E2EEBackupSetupService] 用缓存口令自动重传。
class E2EEBackupSetupPage extends StatefulWidget {
  const E2EEBackupSetupPage({super.key, this.uploadOverride});

  /// 测试注入：widget 测试无网，用假上传验证全链
  final Future<E2EEBackupPutResult> Function(String password)? uploadOverride;

  @override
  // ignore: library_private_types_in_public_api
  State<E2EEBackupSetupPage> createState() => _E2EEBackupSetupPageState();
}

class _E2EEBackupSetupPageState extends State<E2EEBackupSetupPage> {
  /// 恢复密钥复制后的剪贴板驻留时限（#102，与导出页同款）
  static const Duration _recoveryKeyClipboardTtl = Duration(seconds: 60);

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;

  /// 至少失败一次后才开放「稍后再说」（成功前不允许无备份离开）
  bool _failedOnce = false;

  /// 上传成功后放行返回（PopScope）
  bool _allowLeave = false;

  void _scheduleRecoveryKeyClipboardClear(String key) {
    Future<void>.delayed(_recoveryKeyClipboardTtl, () async {
      final data = await Clipboard.getData('text/plain');
      if (data?.text == key) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_allowLeave) {
          AppLoading.showToast(t.common.e2eeBackupSetupBlockedToast);
        }
      },
      child: IosPageTemplate(
        title: t.common.e2eeBackupSetupTitle,
        // 不可跳过：不提供返回键
        leading: const SizedBox.shrink(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.regular),
          child: Column(
            children: [
              _buildIntroCard(),
              const SizedBox(height: AppSpacing.xLarge),
              _buildPasswordField(),
              const SizedBox(height: AppSpacing.regular),
              _buildConfirmPasswordField(),
              const SizedBox(height: AppSpacing.small),
              _buildWeakHint(),
              const SizedBox(height: AppSpacing.regular),
              _buildRecoveryKeyButton(),
              const SizedBox(height: AppSpacing.xLarge),
              _buildSubmitButton(),
              if (_failedOnce) ...[
                const SizedBox(height: AppSpacing.regular),
                _buildLaterButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: AppColors.iosGray6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        t.common.e2eeBackupSetupBody,
        style: context.textStyle(FontSizeType.subheadline),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupPwdLabel,
        hintText: t.common.e2eeBackupSetupPwdHint,
        prefixIcon: const Icon(CupertinoIcons.lock),
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupConfirmPwdLabel,
        hintText: t.common.e2eeBackupConfirmPwdHint,
        prefixIcon: const Icon(CupertinoIcons.lock_fill),
        border: const OutlineInputBorder(),
      ),
      // BUG#132 同源：缺 onChanged 时确认框输入不触发 setState，
      // 提交按钮 isEnabled 不重算，卡在初始 disabled 状态。
      onChanged: (_) => setState(() {}),
    );
  }

  /// 弱口令提示：非空且不足 12 位时展示（≥8 位仍允许提交）
  Widget _buildWeakHint() {
    final pwd = _passwordController.text;
    if (pwd.isEmpty || pwd.length >= 12) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t.common.e2eeBackupSetupWeakHint,
        style: context.textStyle(
          FontSizeType.footnote,
          color: AppColors.iosOrange,
        ),
      ),
    );
  }

  Widget _buildRecoveryKeyButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _generateRecoveryKey,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.wand_stars, size: 18),
            const SizedBox(width: 4),
            Text(t.common.e2eeUseRecoveryKey),
          ],
        ),
      ),
    );
  }

  /// 生成随机恢复密钥填入口令/确认框，并弹窗强制用户知悉需保存
  /// （与导出页同款交互；#102 剪贴板 60s 自动清除）
  void _generateRecoveryKey() {
    final key = E2EECryptoService.generateRecoveryKey();
    _passwordController.text = key;
    _confirmPasswordController.text = key;
    setState(() {});
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
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
              _scheduleRecoveryKeyClipboardClear(key);
              if (ctx.mounted) Navigator.pop(ctx);
              AppLoading.showSuccess(
                t.common.e2eeRecoveryKeyCopiedAutoClear(
                  seconds: _recoveryKeyClipboardTtl.inSeconds,
                ),
              );
            },
            child: Text(t.common.buttonCopy),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final pwd = _passwordController.text;
    final enabled = !_submitting && pwd.isNotEmpty && pwd.length >= 8;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: enabled ? _handleSubmit : null,
        // 实底按钮文字必须显式 onPrimary（红底蓝字教训，批次121）
        child: Text(
          _submitting ? t.common.loading : t.common.e2eeBackupSetupSubmit,
          style: TextStyle(
            color: enabled
                ? AppColors.onPrimary
                : AppColors.onPrimary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildLaterButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _allowLeaveNow,
      child: Text(
        t.common.e2eeBackupSetupLater,
        style: context.textStyle(
          FontSizeType.footnote,
          color: AppColors.iosGray,
        ),
      ),
    );
  }

  /// 稍后再说：本次放行离开，但完成标记不落——下次启动向导重新触发
  void _allowLeaveNow() {
    setState(() => _allowLeave = true);
    AppLoading.showToast(t.common.e2eeBackupSetupPostponedToast);
    Navigator.of(context).pop();
  }

  Future<void> _handleSubmit() async {
    final pwd = _passwordController.text;
    if (pwd.length < 8) {
      AppLoading.showToast(t.common.e2eeBackupSetupPwdTooShort);
      return;
    }
    if (pwd != _confirmPasswordController.text) {
      AppLoading.showToast(t.common.e2eeBackupErrPwdMismatch);
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = widget.uploadOverride != null
          ? await widget.uploadOverride!(pwd)
          : await _uploadReal(pwd);
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _failedOnce = true);
        AppLoading.showToast(t.common.e2eeBackupErrCloudUploadFailed);
        return;
      }
      await E2EEBackupSetupService.to.completeSetup(passphrase: pwd);
      if (!mounted) return;
      setState(() => _allowLeave = true);
      _showSuccessDialog(result.backupVersion);
    } on Object catch (e) {
      iPrint('[E2EEBackupSetup] 云端上传失败: ${e.runtimeType}');
      if (mounted) {
        setState(() => _failedOnce = true);
        AppLoading.showToast(t.common.e2eeBackupErrCloudUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<E2EEBackupPutResult> _uploadReal(String pwd) async {
    final privateKey = await StorageSecureService.to.getPrivateKey();
    final publicKey = await StorageSecureService.to.getPublicKey();
    if (privateKey == null || publicKey == null) {
      return const E2EEBackupPutResult(ok: false);
    }
    return E2EEServerBackupService.upload(
      password: pwd,
      privateKey: privateKey,
      publicKey: publicKey,
      deviceId: await StorageSecureService.to.getDeviceId() ?? 'unknown',
      keyId: await StorageSecureService.to.getKeyId() ?? 'unknown',
    );
  }

  void _showSuccessDialog(int backupVersion) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          t.common.e2eeBackupCloudUploadSuccess(version: backupVersion),
        ),
        content: Text(t.common.e2eeBackupSetupSavedNote),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              // 先关弹窗再关页面（页面级 context 关页，避免 unmount 陷阱）
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
  }
}
