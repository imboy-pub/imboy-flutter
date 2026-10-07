import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

/// 移动端电话号码输入组件（完整功能）
class MobilePhoneInputWidget extends StatelessWidget {
  final String initialValue;

  /// `fullNumber`：国家码+号码整串；`localNumber`：剥掉 dialCode 的本地号码。
  /// 剥离用 startsWith+substring 精确匹配，不用正则（`^\+\d+` 会贪婪
  /// 吞掉整串连续数字，历史 P0：手机注册/登录/找回密码表单永久禁用）。
  final void Function(String fullNumber, String localNumber) onInputChanged;
  final String? hintText;
  final InputDecoration? decoration;

  const MobilePhoneInputWidget({
    super.key,
    required this.initialValue,
    required this.onInputChanged,
    this.hintText,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return InternationalPhoneNumberInput(
      onInputChanged: (PhoneNumber number) {
        final String full = number.phoneNumber ?? '';
        final String dial = number.dialCode ?? '';
        final String local = dial.isNotEmpty && full.startsWith(dial)
            ? full.substring(dial.length)
            : full;
        onInputChanged(full, local);
      },
      selectorConfig: const SelectorConfig(
        selectorType: PhoneInputSelectorType.DIALOG,
      ),
      ignoreBlank: false,
      autoValidateMode: AutovalidateMode.disabled,
      selectorTextStyle: const TextStyle(color: AppColors.lightTextPrimary),
      initialValue: initialValue.isNotEmpty
          ? PhoneNumber(isoCode: 'CN', phoneNumber: initialValue)
          : PhoneNumber(isoCode: 'CN'),
      inputDecoration:
          decoration ??
          InputDecoration(
            hintText: hintText ?? t.common.phoneInputHint,
            border: OutlineInputBorder(
              borderRadius: AppRadius.borderRadiusSmall,
              borderSide: BorderSide(color: AppColors.iosSeparator),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.regular,
            ),
          ),
    );
  }
}
