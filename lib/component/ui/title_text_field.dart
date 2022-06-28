import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class TitleTextField extends StatelessWidget {
  final String title;
  TextEditingController controller;
  final int minLines;
  final int maxLines;
  final int maxLength;

  final EdgeInsetsGeometry? contentPadding;

  TitleTextField({
    Key? key,
    required this.title,
    required this.controller,
    required this.minLines,
    required this.maxLines,
    required this.maxLength,
    this.contentPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return n.Column(
      [
        Text(title),
        TextField(
          textAlign: TextAlign.left,
          controller: controller,
          cursorColor: Colors.black54,
          decoration: InputDecoration(
            labelText: "",
            labelStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.MainTextColor,
            ),
            contentPadding:
                contentPadding ?? const EdgeInsets.fromLTRB(10, 10, 10, 10),
            fillColor: const Color.fromARGB(255, 247, 247, 247),
            filled: true,
            enabledBorder: const OutlineInputBorder(
              /*边角*/
              borderRadius: BorderRadius.all(
                Radius.circular(5), //边角为5
              ),
              borderSide: BorderSide(
                color: Colors.white, //边线颜色为白色
                width: 1, //边线宽度为2
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white, //边框颜色为白色
                width: 1, //宽度为5
              ),
              borderRadius: BorderRadius.all(
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
      ],
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
    );
  }
}
