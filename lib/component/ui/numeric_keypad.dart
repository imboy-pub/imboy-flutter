// NumericKeypad
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NumericKeypad extends StatelessWidget {
  final NumericKeypadController controller;
  final ValueChanged<String> onChanged;

  const NumericKeypad({required this.controller, required this.onChanged, super.key});

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
        return buildNumKeyboardItem(_keyboardDataList[index]);
      },
      itemCount: _keyboardDataList.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  Widget buildNumKeyboardItem(PayKeyboardDataBean keyboardDataBean) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (keyboardDataBean.type == PayKeyboardType.delete) {
          if (controller.value.isNotEmpty) {
            controller.value =
                controller.value.substring(0, controller.value.length - 1);
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
          color: keyboardDataBean.type == PayKeyboardType.num
              ? Colors.transparent
              : Colors.black26,
          border: const Border(
            top: BorderSide(width: 0.5, color: Colors.black26),
            right: BorderSide(width: 0.5, color: Colors.black26),
          ),
        ),
        child: keyboardDataBean.type == PayKeyboardType.delete
            ? const Icon(
                Icons.cancel_presentation,
                color: Colors.white60,
              )
            : Text(
                keyboardDataBean.value,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white60,
                ),
              ),
      ),
    );
  }
}

enum PayKeyboardType {
  none,
  num,
  delete,
}

class PayKeyboardDataBean {
  final PayKeyboardType type;
  final String value;

  const PayKeyboardDataBean(this.type, this.value);
}

class NumericKeypadController extends RxString {
  NumericKeypadController(super.initial);

  void setText(String text) {
    value = text;
  }

  void clearText() {
    value = '';
  }
}
