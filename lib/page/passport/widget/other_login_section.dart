import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';

class OtherLoginSection extends StatelessWidget {
  final PassportNotifier notifier;
  final bool isDark;
  final bool showAlipay;
  final bool showOneKey;

  const OtherLoginSection({
    super.key,
    required this.notifier,
    required this.isDark,
    this.showAlipay = true,
    this.showOneKey = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showAlipay && !showOneKey) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: AppSpacing.symmetricMedium,
              child: Text(
                t.account.otherLoginMethods,
                style: TextStyle(
                  color: AppColors.iosGray,
                  fontSize: FontSizeType.small.size,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        AppSpacing.verticalRegular,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showOneKey) ...[
              _buildOneKeyButton(context),
              if (showAlipay) const SizedBox(width: 32),
            ],
            if (showAlipay) _buildAlipayButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildOneKeyButton(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: t.passport.oneKeyLogin,
          button: true,
          child: InkWell(
            key: const Key('one_key_login_button'),
            onTap: () async {
              await notifier.loginAuth(false);
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.touch_app,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t.passport.oneKeyLogin,
          style: context.textStyle(
            FontSizeType.small,
            color: isDark ? AppColors.darkTextSecondary : AppColors.iosGray,
          ),
        ),
      ],
    );
  }

  Widget _buildAlipayButton(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const Key('alipay_login_button'),
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            final err = await notifier.loginByAlipay();
            // 用户取消返回 null（静默）；仅失败时提示
            if (err != null) {
              notifier.snackBar(err);
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.alipayBrand,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '支',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontSize: FontSizeType.extraLarge.size,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t.common.withdrawAlipay,
          style: context.textStyle(
            FontSizeType.small,
            color: isDark ? AppColors.darkTextSecondary : AppColors.iosGray,
          ),
        ),
      ],
    );
  }
}
