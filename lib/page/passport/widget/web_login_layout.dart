import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Keep the QR square and form usable when a desktop window becomes narrow.
class WebLoginLayout extends StatelessWidget {
  const WebLoginLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = AppBreakpoints.isWide(constraints.maxWidth);
        final form = Container(
          padding: EdgeInsets.all(
            wide ? AppSpacing.xxLarge : AppSpacing.regular,
          ),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceContainer,
            borderRadius: wide ? AppRadius.borderRadiusMedium : null,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: child,
          ),
        );
        if (!wide) return SizedBox.expand(child: form);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 3, child: _LoginInformation()),
            Expanded(flex: 2, child: form),
          ],
        );
      },
    ),
  );
}

class _LoginInformation extends StatelessWidget {
  const _LoginInformation();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.allXXLarge,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.chat_bubble,
              size: AppSizes.iconSizeXLarge,
              color: AppColors.primary,
            ),
            AppSpacing.horizontalRegular,
            Expanded(
              child: Text(
                'ImBoy Web',
                style: context.textStyle(
                  FontSizeType.extraLargeTitle,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.verticalXXLarge,
        _feature(
          context,
          CupertinoIcons.device_phone_portrait,
          t.chat.webFeatureMultiDevice,
          t.chat.webFeatureMultiDeviceDesc,
        ),
        AppSpacing.verticalXXLarge,
        _feature(
          context,
          CupertinoIcons.lock,
          t.chat.webFeatureE2EE,
          t.chat.webFeatureE2EEDesc,
        ),
        AppSpacing.verticalXXLarge,
        _feature(
          context,
          CupertinoIcons.bell,
          t.common.webFeatureNotification,
          t.common.webFeatureNotificationDesc,
        ),
        AppSpacing.verticalXXLarge,
        _feature(
          context,
          CupertinoIcons.paperclip,
          t.chat.webFeatureFileTransfer,
          t.chat.webFeatureFileTransferDesc,
        ),
      ],
    ),
  );

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: AppSizes.touchTarget,
        height: AppSizes.touchTarget,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          borderRadius: AppRadius.borderRadiusCell,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      AppSpacing.horizontalLarge,
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.textStyle(
                FontSizeType.large,
                fontWeight: FontWeight.w600,
                color: AppColors.darkTextPrimary,
              ),
            ),
            AppSpacing.verticalTiny,
            Text(
              description,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
