import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/page/mine/account_security/bind_email_provider.dart';

class BindEmailPage extends ConsumerStatefulWidget {
  const BindEmailPage({super.key});

  @override
  ConsumerState<BindEmailPage> createState() => _BindEmailPageState();
}

class _BindEmailPageState extends ConsumerState<BindEmailPage> {
  @override
  void initState() {
    super.initState();
    // 设置监听器
    final notifier = ref.read(bindEmailProvider.notifier);
    notifier.emailCtl.addListener(() {
      notifier.updateEmail(notifier.emailCtl.text.trim());
    });
    notifier.codeCtl.addListener(() {
      notifier.updateCode(notifier.codeCtl.text.trim());
    });
  }

  @override
  void dispose() {
    final notifier = ref.read(bindEmailProvider.notifier);
    notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentEmail = UserRepoLocal.to.current.email;
    final hasBound = currentEmail.isNotEmpty;
    final asyncState = ref.watch(bindEmailProvider);

    final inputBorderRadius = AppRadius.borderRadiusMedium;
    const inputFillColor = Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: hasBound ? t.changeEmail : t.bindEmail,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            // Current Status Card
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alternate_email,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                title: Text(
                  t.currentEmail,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  hasBound ? _maskEmail(currentEmail) : t.notBound,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasBound
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.circle),
                  ),
                  child: Text(
                    hasBound ? t.bound : t.notBound,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasBound ? AppColors.primary : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Form Area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    hasBound ? t.newEmailAddress : t.emailAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: inputFillColor,
                    borderRadius: inputBorderRadius,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: ref.read(bindEmailProvider.notifier).emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: t.enterEmailAddress,
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: asyncState.email.isEmpty
                          ? null
                          : IconButton(
                              onPressed: ref
                                  .read(bindEmailProvider.notifier)
                                  .clearEmail,
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                _StatusRow(
                  label: t.formatCheck,
                  value: asyncState.emailOk ? t.correct : t.pendingInput,
                  ok: asyncState.emailOk,
                ),

                const SizedBox(height: 20),

                // Verification Code
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        t.verificationCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: asyncState.canSendCode
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        borderRadius: AppRadius.borderRadiusLarge,
                      ),
                      child: TextButton(
                        onPressed: asyncState.canSendCode
                            ? () async {
                                final error = await ref
                                    .read(bindEmailProvider.notifier)
                                    .sendCode();
                                if (error != null && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(error),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.errorContainer,
                                    ),
                                  );
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        t.sentToEmail(
                                          param: _maskEmail(asyncState.email),
                                        ),
                                      ),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.inverseSurface,
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          disabledForegroundColor: Colors.grey[400],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: asyncState.isSendingCode
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.mail_outline_rounded,
                                    size: 16,
                                    color: asyncState.canSendCode
                                        ? AppColors.primary
                                        : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    asyncState.seconds > 0
                                        ? '${t.resendCode} (${asyncState.seconds}s)'
                                        : t.getVerificationCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),

                Container(
                  decoration: BoxDecoration(
                    color: inputFillColor,
                    borderRadius: inputBorderRadius,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: ref.read(bindEmailProvider.notifier).codeCtl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(fontSize: 16, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        letterSpacing: 1,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                _StatusRow(
                  label: t.lengthCheck,
                  value: '${asyncState.codeLength} / 6',
                  ok: asyncState.codeOk,
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: asyncState.canSubmit
                        ? () async {
                            final error = await ref
                                .read(bindEmailProvider.notifier)
                                .submit();
                            if (error != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t.emailUpdatedTo(
                                      param: _maskEmail(asyncState.email),
                                    ),
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.inverseSurface,
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[200],
                      disabledForegroundColor: Colors.grey[400],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusXLarge,
                      ),
                    ),
                    child: asyncState.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            hasBound ? t.confirmChange : t.bindNow,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    t.verificationCodeSentToEmail,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: ok ? AppColors.primary : Colors.grey[400],
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: TextStyle(
            color: ok ? AppColors.primary : Colors.grey[500],
            fontSize: 12,
            fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
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
