import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

/// 移动端电话号码输入组件（完整功能）
class MobilePhoneInputWidget extends StatelessWidget {
  final String initialValue;
  final Function(String) onInputChanged;
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
        onInputChanged(number.phoneNumber ?? '');
      },
      selectorConfig: const SelectorConfig(
        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
      ),
      ignoreBlank: false,
      autoValidateMode: AutovalidateMode.disabled,
      selectorTextStyle: const TextStyle(color: Colors.black),
      initialValue: initialValue.isNotEmpty
          ? PhoneNumber(isoCode: 'CN', phoneNumber: initialValue)
          : PhoneNumber(isoCode: 'CN'),
      inputDecoration: decoration ??
          InputDecoration(
            hintText: hintText ?? t.phoneInputHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
    );
  }
}
