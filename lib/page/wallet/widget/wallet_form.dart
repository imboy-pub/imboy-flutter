import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 钱包表单共享组件（转账 / 红包），统一遵循 DESIGN.md §8：
/// surface 分组卡片、无边框填充输入、50pt/圆角主按钮。

/// 分组卡片包裹（surface 背景 + medium 圆角），承载单个填充输入。
class WalletFieldCard extends StatelessWidget {
  const WalletFieldCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(Theme.of(context).brightness),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny),
      child: child,
    );
  }
}

/// 无边框、无填充的输入装饰（放进 [WalletFieldCard] 里用，靠卡片提供背景）。
InputDecoration walletInputDecoration({String? hint, String? suffix}) {
  return InputDecoration(
    hintText: hint,
    suffixText: suffix,
    border: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.small,
      vertical: 14,
    ),
  );
}

/// 金额 hero 卡片：大字号 ￥ + 金额输入，支付页视觉主角。
class WalletAmountField extends StatelessWidget {
  const WalletAmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.accent,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final Color accent;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(Theme.of(context).brightness),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.getTextColor(
                Theme.of(context).brightness,
                isSecondary: true,
              ),
            ),
          ),
          AppSpacing.verticalSmall,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '￥',
                style: context
                    .textStyle(FontSizeType.large, fontWeight: FontWeight.bold)
                    .copyWith(color: accent),
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // 两位小数精度守卫，与 wallet_page 充值输入框保持一致
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  style: context.textStyle(
                    FontSizeType.largeTitle,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 钱包余额提示行（footnote 次级色，左对齐略缩进）。
class WalletBalanceHint extends StatelessWidget {
  const WalletBalanceHint({super.key, required this.balanceYuan});

  final double balanceYuan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny),
      child: Text(
        t.common.walletBalanceLabel(balance: balanceYuan.toStringAsFixed(2)),
        style: context.textStyle(
          FontSizeType.footnote,
          color: AppColors.getTextColor(
            Theme.of(context).brightness,
            isSecondary: true,
          ),
        ),
      ),
    );
  }
}

/// 页面级主按钮：满宽、50pt 高、medium 圆角，颜色由调用方指定语义。
class WalletPrimaryButton extends StatelessWidget {
  const WalletPrimaryButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMedium,
          ),
        ),
        child: Text(
          label,
          style: context.textStyle(
            FontSizeType.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
