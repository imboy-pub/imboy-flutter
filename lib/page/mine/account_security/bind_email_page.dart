import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/account_security/bind_email_provider.dart';

/// 绑定/更改邮箱页面 - 像素级对齐 iOS 设置风
class BindEmailPage extends ConsumerStatefulWidget {
  const BindEmailPage({super.key});

  @override
  ConsumerState<BindEmailPage> createState() => _BindEmailPageState();
}

class _BindEmailPageState extends ConsumerState<BindEmailPage> {
  @override
  void initState() {
    super.initState();
    final notifier = ref.read(bindEmailProvider.notifier);
    notifier.emailCtl.addListener(
      () => notifier.updateEmail(notifier.emailCtl.text.trim()),
    );
    notifier.codeCtl.addListener(
      () => notifier.updateCode(notifier.codeCtl.text.trim()),
    );
  }

  @override
  void dispose() {
    ref.read(bindEmailProvider.notifier).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = UserRepoLocal.to.current.email;
    final hasBound = currentEmail.isNotEmpty;
    final asyncState = ref.watch(bindEmailProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: hasBound ? t.account.changeEmail : t.account.bindEmail,
      useLargeTitle: false,
      bottomWidget: _buildSubmitButton(context, ref, asyncState, hasBound, t),
      child: Column(
        children: [
          // 当前状态 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.account.currentEmail),
                subtitle: Text(
                  hasBound ? _maskEmail(currentEmail) : t.common.notBound,
                ),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.getIosBlue(brightness),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.mail,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (hasBound
                                ? AppColors.getIosBlue(brightness)
                                : AppColors.iosGray)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasBound ? t.main.bound : t.common.notBound,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasBound
                          ? AppColors.getIosBlue(brightness)
                          : AppColors.iosGray,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 输入表单 Section
          ImBoySettingsSection(
            header: Text(
              (hasBound ? t.common.newEmailAddress : t.common.emailAddress)
                  .toUpperCase(),
            ),
            children: [
              CupertinoListTile.notched(
                title: Row(
                  children: [
                    const SizedBox(
                      width: 80,
                      child: Text('邮箱', style: TextStyle(fontSize: 17)),
                    ),
                    Expanded(
                      child: CupertinoTextField(
                        controller: ref
                            .read(bindEmailProvider.notifier)
                            .emailCtl,
                        placeholder: t.common.enterEmailAddress,
                        keyboardType: TextInputType.emailAddress,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 12,
                        ),
                        decoration: null,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoListTile.notched(
                title: Row(
                  children: [
                    const SizedBox(
                      width: 80,
                      child: Text('验证码', style: TextStyle(fontSize: 17)),
                    ),
                    Expanded(
                      child: CupertinoTextField(
                        controller: ref
                            .read(bindEmailProvider.notifier)
                            .codeCtl,
                        placeholder: '000000',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 12,
                        ),
                        decoration: null,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCodeButton(context, ref, asyncState),
                  ],
                ),
              ),
            ],
          ),

          // 校验状态 Section
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Column(
              children: [
                _ValidationRow(
                  label: t.chat.formatCheck,
                  ok: asyncState.emailOk,
                  text: asyncState.emailOk
                      ? t.main.correct
                      : t.main.pendingInput,
                ),
                _ValidationRow(
                  label: t.main.lengthCheck,
                  ok: asyncState.codeOk,
                  text: '${asyncState.codeLength} / 6',
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              t.common.verificationCodeSentToEmail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.iosGray, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeButton(
    BuildContext context,
    WidgetRef ref,
    BindEmailState state,
  ) {
    final bool canSend = state.canSendCode;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      color: AppColors.getIosBlue(Theme.of(context).brightness),
      disabledColor: AppColors.iosGray.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      onPressed: canSend
          ? () async {
              final error = await ref
                  .read(bindEmailProvider.notifier)
                  .sendCode();
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: AppColors.iosRed,
                  ),
                );
              }
            }
          : null,
      minimumSize: Size(32, 32),
      child: state.isSendingCode
          ? const CupertinoActivityIndicator(radius: 8, color: Colors.white)
          : Text(
              state.seconds > 0
                  ? '${state.seconds}s'
                  : t.common.getVerificationCode,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    WidgetRef ref,
    BindEmailState state,
    bool hasBound,
    Translations t,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: state.canSubmit
              ? () async {
                  final error = await ref
                      .read(bindEmailProvider.notifier)
                      .submit();
                  if (error == null && context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              : null,
          child: state.isSubmitting
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text(
                  hasBound ? t.common.confirmChange : t.common.bindNow,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({
    required this.label,
    required this.ok,
    required this.text,
  });
  final String label;
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.iosGreen : AppColors.iosGray;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.iosGray),
            ),
          ),
          Icon(
            ok ? CupertinoIcons.check_mark_circled : CupertinoIcons.circle,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

String _maskEmail(String email) {
  final v = email.trim();
  final at = v.indexOf('@');
  if (at <= 1) return v;
  final name = v.substring(0, at);
  final domain = v.substring(at);
  if (name.length <= 2) return '${name[0]}*$domain';
  return '${name.substring(0, 2)}***$domain';
}
