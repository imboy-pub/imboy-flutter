import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

String talkRecordAiProviderTitle(TalkRecordAiProvider provider) =>
    switch (provider) {
      TalkRecordAiProvider.doubao => t.talkRecord.aiDoubaoTitle,
      TalkRecordAiProvider.minimax => t.talkRecord.aiMinimaxTitle,
      TalkRecordAiProvider.zhipu => t.talkRecord.aiZhipuTitle,
    };

String talkRecordAiError(Object? error) => switch (error) {
  TalkRecordAiCredentialException(code: 'invalid_key') =>
    t.talkRecord.aiInvalidKey,
  TalkRecordAiCredentialException(code: 'unsupported_platform') =>
    t.talkRecord.aiUnsupportedPlatform,
  TalkRecordAiCredentialException(code: 'account_changed') =>
    t.talkRecord.aiAccountChanged,
  TalkRecordAiCredentialException(code: 'credential_changed') =>
    t.talkRecord.aiCredentialChanged,
  _ => t.talkRecord.aiStorageFailed,
};

class TalkRecordAiText extends StatelessWidget {
  const TalkRecordAiText(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.textStyle(
      FontSizeType.body,
      color: error
          ? AppColors.getIosRed(Theme.of(context).brightness)
          : Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary,
    ),
  );
}

class TalkRecordAiCard extends StatelessWidget {
  const TalkRecordAiCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(AppSpacing.medium),
    ),
    padding: const EdgeInsets.all(AppSpacing.regular),
    child: child,
  );
}

class TalkRecordAiEntryRow extends StatelessWidget {
  const TalkRecordAiEntryRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = CupertinoIcons.sparkles,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
    minimumSize: const Size(AppSpacing.xxxLarge, AppSpacing.xxxLarge),
    onPressed: onTap,
    child: Row(
      children: [
        Icon(icon, color: AppColors.getIosBlue(Theme.of(context).brightness)),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.tiny),
              TalkRecordAiText(subtitle),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Icon(
          CupertinoIcons.chevron_right,
          size: AppSpacing.regular,
          color: AppColors.getIosSeparator(Theme.of(context).brightness),
        ),
      ],
    ),
  );
}
