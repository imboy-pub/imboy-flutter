import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/theme.dart';

import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class TitleTextField extends StatelessWidget {
  final String title;
  TextEditingController controller;
  final int minLines;
  final int maxLines;
  final int? maxLength;

  final EdgeInsetsGeometry? contentPadding;

  TitleTextField({
    super.key,
    required this.title,
    required this.controller,
    required this.minLines,
    required this.maxLines,
    this.maxLength,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return n.Column([
      Text(title),
      TextField(
        textAlign: TextAlign.left,
        controller: controller,
        cursorColor: Colors.black54,
        decoration: InputDecoration(
          labelText: '',
          labelStyle: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          contentPadding:
              contentPadding ?? const EdgeInsets.fromLTRB(10, 10, 10, 10),
          fillColor: Get.isDarkMode ? darkInputFillColor : lightInputFillColor,
          filled: true,
          enabledBorder: OutlineInputBorder(
            /*边角*/
            borderRadius: const BorderRadius.all(
              Radius.circular(5), //边角为5
            ),
            borderSide: BorderSide(
              color: Get.isDarkMode
                  ? darkInputFillColor
                  : lightInputFillColor, //边线颜色为白色
              width: 1, //边线宽度为2
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Get.isDarkMode
                  ? darkInputFillColor
                  : lightInputFillColor, //边框颜色为白色
              width: 1, //宽度为5
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(5), //边角为30
            ),
          ),
        ),
        // focusNode: _inputFocusNode,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: minLines,
        // 长按是否展示【剪切/复制/粘贴菜单LengthLimitingTextInputFormatter】
        enableInteractiveSelection: true,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.newline,
        // onChanged: widget.onTextChanged,
        onTap: () {
          // updateState(inputType);
          // widget.onTextFieldTap;
        },
        // 点击键盘的动作按钮时的回调，参数为当前输入框中的值
        // onSubmitted: (_) => _handleSendPressed(),
      )
    ])
      ..crossAxisAlignment = CrossAxisAlignment.start
      ..mainAxisSize = MainAxisSize.min;
  }
}
