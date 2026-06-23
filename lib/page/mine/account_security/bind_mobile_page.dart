import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';
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
                  child: Icon(
                    CupertinoIcons.phone,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: AppSpacing.tiny,
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
                    style: context.textStyle(
                      FontSizeType.small,
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
                title: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        '手机号',
                        style: context.textStyle(FontSizeType.body),
                      ),
                    ),
                    Expanded(
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
                            vertical: AppSpacing.medium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoListTile.notched(
                title: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        '验证码',
                        style: context.textStyle(FontSizeType.body),
                      ),
                    ),
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
                          vertical: AppSpacing.medium,
                        ),
                        decoration: null,
                        style: context.textStyle(FontSizeType.body),
                      ),
                    ),
                    AppSpacing.horizontalSmall,
                    _buildCodeButton(context, ref, asyncState),
                  ],
                ),
              ),
            ],
          ),

          // 校验状态 Section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxLarge,
              AppSpacing.small,
              AppSpacing.xxLarge,
              0,
            ),
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
            padding: const EdgeInsets.all(AppSpacing.xLarge),
            child: Text(
              t.common.verificationCodeSentToMobile,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeButton(
    BuildContext context,
    WidgetRef ref,
    BindMobileState state,
  ) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: 0,
      ),
      color: AppColors.getIosBlue(Theme.of(context).brightness),
      disabledColor: AppColors.iosGray.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      onPressed: state.canSendCode
          ? () async {
              final error = await ref
                  .read(bindMobileProvider.notifier)
                  .sendCode();
              if (error != null && context.mounted) {
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
          ? CupertinoActivityIndicator(radius: 8, color: AppColors.onPrimary)
          : Text(
              state.seconds > 0
                  ? '${state.seconds}s'
                  : t.common.getVerificationCode,
              style: context.textStyle(
                FontSizeType.small,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    WidgetRef ref,
    BindMobileState state,
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
            foregroundColor: AppColors.onPrimary,
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
                  if (error == null && context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              : null,
          child: state.isSubmitting
              ? CupertinoActivityIndicator(color: AppColors.onPrimary)
              : Text(
                  hasBound ? t.common.confirmChange : t.common.bindNow,
                  style: context.textStyle(
                    FontSizeType.body,
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
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Icon(
            ok ? CupertinoIcons.check_mark_circled : CupertinoIcons.circle,
            size: 14,
            color: color,
          ),
          AppSpacing.horizontalTiny,
          Text(
            text,
            style: context.textStyle(FontSizeType.small, color: color),
          ),
        ],
      ),
    );
  }
}
