// NumericKeypad
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/sound_manager.dart';
import 'package:imboy/service/app_logger.dart';

class NumericKeypad extends StatelessWidget {
  final NumericKeypadController controller;
  final ValueChanged<String> onChanged;

  const NumericKeypad({
    required this.controller,
    required this.onChanged,
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
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: (125 / 54),
      ),
      itemBuilder: (context, index) {
        return buildNumKeyboardItem(context, _keyboardDataList[index]);
      },
      itemCount: _keyboardDataList.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  Widget buildNumKeyboardItem(
    BuildContext context,
    PayKeyboardDataBean keyboardDataBean,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        // 播放金属感按键音效
        try {
          await SoundManager.playMetallicSound();
        } catch (e) {
          // 如果音效播放失败，不影响功能继续使用
          AppLogger.warning("金属音效播放失败: $e");
        }

        if (keyboardDataBean.type == PayKeyboardType.delete) {
          if (controller.value.isNotEmpty) {
            controller.value = controller.value.substring(
              0,
              controller.value.length - 1,
            );
            onChanged(controller.value);
          }
        } else if (keyboardDataBean.type == PayKeyboardType.num) {
          controller.value += keyboardDataBean.value;
          onChanged(controller.value);
        }
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            top: BorderSide(
              width: 0.5,
              color: isDark
                  ? Colors.white12
                  : colorScheme.outline.withValues(alpha: 0.1),
            ),
            right: BorderSide(
              width: 0.5,
              color: isDark
                  ? Colors.white12
                  : colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: keyboardDataBean.type == PayKeyboardType.delete
            ? Icon(
                Icons.backspace,
                color: isDark
                    ? Colors.white60
                    : colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              )
            : Text(
                keyboardDataBean.value,
                style: TextStyle(
                  fontSize: 28,
                  color: isDark ? Colors.white : colorScheme.onSurface,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
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
