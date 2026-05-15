import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/account_security/bind_mobile_provider.dart';

/// 绑定/更改手机页面 - 像素级对齐 iOS 设置风
class BindMobilePage extends ConsumerStatefulWidget {
  const BindMobilePage({super.key});

  @override
  ConsumerState<BindMobilePage> createState() => _BindMobilePageState();
}

class _BindMobilePageState extends ConsumerState<BindMobilePage> {
  @override
  void initState() {
    super.initState();
    final notifier = ref.read(bindMobileProvider.notifier);
    notifier.mobileCtl.addListener(
      () => notifier.updateMobile(notifier.mobileCtl.text.trim()),
    );
    notifier.codeCtl.addListener(
      () => notifier.updateCode(notifier.codeCtl.text.trim()),
    );
  }

  @override
  void dispose() {
    ref.read(bindMobileProvider.notifier).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMobile = UserRepoLocal.to.current.mobile;
    final hasBound = currentMobile.isNotEmpty;
    final asyncState = ref.watch(bindMobileProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: hasBound ? t.account.changeMobile : t.account.bindMobile,
      useLargeTitle: false,
      bottomWidget: _buildSubmitButton(context, ref, asyncState, hasBound, t),
      child: Column(
        children: [
          // 当前状态 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.account.currentMobile),
                subtitle: Text(
                  hasBound ? hiddenPhone(currentMobile) : t.common.notBound,
                ),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.getIosBlue(brightness),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.phone,
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
              (hasBound ? t.account.newMobile : t.account.mobile).toUpperCase(),
            ),
            children: [
              CupertinoListTile.notched(
                title: const SizedBox(
                  width: 80,
                  child: Text(
                    '手机号', // 使用标准简短标签
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                additionalInfo: Expanded(
                  child: PhoneInputWidget(
                    initialValue: '',
                    onInputChanged: (String full) => ref
                        .read(bindMobileProvider.notifier)
                        .updateMobile(full),
                    hintText: t.account.enterMobileHint,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const SizedBox(
                  width: 80,
                  child: Text(
                    '验证码',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                additionalInfo: Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: ref
                              .read(bindMobileProvider.notifier)
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
                  ok: asyncState.mobileOk,
                  text: asyncState.mobileOk
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
              t.common.verificationCodeSentToMobile,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.iosGray, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeButton(BuildContext context, WidgetRef ref, dynamic state) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      minSize: 32,
      color: AppColors.getIosBlue(Theme.of(context).brightness),
      disabledColor: AppColors.iosGray.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      onPressed: state.canSendCode
          ? () async {
              final error = await ref
                  .read(bindMobileProvider.notifier)
                  .sendCode();
              if (error != null && mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: AppColors.iosRed,
                  ),
                );
            }
          : null,
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
    dynamic state,
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
                      .read(bindMobileProvider.notifier)
                      .submit();
                  if (error == null && context.mounted)
                    Navigator.of(context).pop();
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
