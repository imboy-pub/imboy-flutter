import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

// 条件导入：移动端使用完整的电话号码输入组件
import 'phone_input_stub.dart' if (dart.library.io) 'phone_input_mobile.dart';

/// 电话号码输入组件（Web/Mobile 自适应）
///
/// - Web 平台：使用简单的 TextField（避免 dlibphonenumber 资源耗尽）
/// - 移动端：使用 InternationalPhoneNumberInput（完整功能）
class PhoneInputWidget extends StatelessWidget {
  final String initialValue;
  final void Function(String) onInputChanged;
  final String? hintText;
  final InputDecoration? decoration;

  const PhoneInputWidget({
    super.key,
    required this.onInputChanged,
    this.initialValue = '',
    this.hintText,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    // Web 平台使用简单输入框
    if (kIsWeb) {
      return _WebPhoneInputWidget(
        initialValue: initialValue,
        onInputChanged: onInputChanged,
        hintText: hintText,
        decoration: decoration,
      );
    }

    // 移动端使用完整组件
    return MobilePhoneInputWidget(
      initialValue: initialValue,
      onInputChanged: onInputChanged,
      hintText: hintText,
      decoration: decoration,
    );
  }
}

/// Web 平台简单电话号码输入组件
class _WebPhoneInputWidget extends StatefulWidget {
  final String initialValue;
  final void Function(String) onInputChanged;
  final String? hintText;
  final InputDecoration? decoration;

  const _WebPhoneInputWidget({
    required this.initialValue,
    required this.onInputChanged,
    this.hintText,
    this.decoration,
  });

  @override
  State<_WebPhoneInputWidget> createState() => _WebPhoneInputWidgetState();
}

class _WebPhoneInputWidgetState extends State<_WebPhoneInputWidget> {
  late TextEditingController _controller;
  String _selectedCountryCode = '+86'; // 默认中国

  final Map<String, String> _commonCountries = {
    '+86': '🇨🇳 中国',
    '+1': '🇺🇸 美国',
    '+44': '🇬🇧 英国',
    '+81': '🇯🇵 日本',
    '+82': '🇰🇷 韩国',
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // 组合完整的电话号码
    final fullNumber = '$_selectedCountryCode$value';
    widget.onInputChanged(fullNumber);
  }

  @override
  Widget build(BuildContext context) {
    final defaultDecoration = InputDecoration(
      hintText: widget.hintText ?? t.common.phoneInputHint,
      border: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: BorderSide(color: AppColors.iosSeparator),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: BorderSide(color: AppColors.iosSeparator),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.regular,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 国家代码选择器
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.iosSeparator),
            borderRadius: AppRadius.borderRadiusSmall,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
          margin: const EdgeInsets.only(right: AppSpacing.small),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountryCode,
              items: _commonCountries.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCountryCode = value;
                    _onChanged(_controller.text);
                  });
                }
              },
            ),
          ),
        ),

        // 电话号码输入框
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            decoration: widget.decoration ?? defaultDecoration,
            onChanged: _onChanged,
          ),
        ),
      ],
    );
  }
}
