// NumericKeypad

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/component/ui/sound_manager.dart';

class NumericKeypad extends StatelessWidget {
  final NumericKeypadController controller;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final bool enabled;

  const NumericKeypad({
    required this.controller,
    required this.onChanged,
    this.maxLength,
    this.enabled = true,
    super.key,
  });

  static const List<PayKeyboardDataBean> _keyboardDataList = [
    PayKeyboardDataBean(PayKeyboardType.num, "1"),
    PayKeyboardDataBean(PayKeyboardType.num, "2"),
    PayKeyboardDataBean(PayKeyboardType.num, "3"),
    PayKeyboardDataBean(PayKeyboardType.num, "4"),
    PayKeyboardDataBean(PayKeyboardType.num, "5"),
    PayKeyboardDataBean(PayKeyboardType.num, "6"),
    PayKeyboardDataBean(PayKeyboardType.num, "7"),
    PayKeyboardDataBean(PayKeyboardType.num, "8"),
    PayKeyboardDataBean(PayKeyboardType.num, "9"),
    PayKeyboardDataBean(PayKeyboardType.none, ""),
    PayKeyboardDataBean(PayKeyboardType.num, "0"),
    PayKeyboardDataBean(PayKeyboardType.delete, ""),
  ];

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (!enabled || event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _applyKey(const PayKeyboardDataBean(PayKeyboardType.delete, ''));
          return KeyEventResult.handled;
        }
        final value = event.character;
        if (value == null || !RegExp(r'^[0-9]$').hasMatch(value)) {
          return KeyEventResult.ignored;
        }
        _applyKey(PayKeyboardDataBean(PayKeyboardType.num, value));
        return KeyEventResult.handled;
      },
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: AppSizes.buttonHeightXLarge,
        ),
        itemBuilder: (context, index) {
          return buildNumKeyboardItem(context, _keyboardDataList[index]);
        },
        itemCount: _keyboardDataList.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
      ),
    );
  }

  void _applyKey(PayKeyboardDataBean key) {
    unawaited(SoundManager.playMetallicSound());
    if (key.type == PayKeyboardType.delete && controller.value.isNotEmpty) {
      controller.value = controller.value.substring(
        0,
        controller.value.length - 1,
      );
    } else if (key.type == PayKeyboardType.num &&
        (maxLength == null || controller.value.length < maxLength!)) {
      controller.value += key.value;
    } else {
      return;
    }
    onChanged(controller.value);
  }

  Widget buildNumKeyboardItem(
    BuildContext context,
    PayKeyboardDataBean keyboardDataBean,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return CellPressable(
      onTap: !enabled || keyboardDataBean.type == PayKeyboardType.none
          ? null
          : () => _applyKey(keyboardDataBean),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.transparent,
          border: Border(
            top: BorderSide(
              width: 0.5,
              color: isDark
                  ? AppColors.overlayLightStrong
                  : colorScheme.outline.withValues(alpha: 0.1),
            ),
            right: BorderSide(
              width: 0.5,
              color: isDark
                  ? AppColors.overlayLightStrong
                  : colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: keyboardDataBean.type == PayKeyboardType.delete
            ? Icon(
                CupertinoIcons.delete_left,
                semanticLabel: t.common.buttonDelete,
                color: isDark
                    ? Colors.white60
                    : colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              )
            : Text(
                keyboardDataBean.value,
                style: context
                    .textStyle(
                      FontSizeType.extraLargeTitle,
                      color: isDark
                          ? AppColors.onPrimary
                          : colorScheme.onSurface,
                      // DESIGN.md §3.3：禁止 w300/Thin；数字键盘改为 w400 Body 字重
                      fontWeight: FontWeight.w400,
                    )
                    .copyWith(
                      letterSpacing: 2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
      ),
    );
  }
}

enum PayKeyboardType { none, num, delete }

class PayKeyboardDataBean {
  final PayKeyboardType type;
  final String value;

  const PayKeyboardDataBean(this.type, this.value);
}

/// 数字键盘控制器
/// 使用 ValueNotifier 替代 GetX 的 RxString
class NumericKeypadController extends ValueNotifier<String> {
  NumericKeypadController(super.initial);

  void setText(String text) {
    value = text;
  }

  void clearText() {
    value = '';
  }

  /// 获取当前值
  String get currentValue => value;

  /// 检查是否为空
  bool get isEmpty => value.isEmpty;

  /// 检查是否非空
  bool get isNotEmpty => value.isNotEmpty;
}
