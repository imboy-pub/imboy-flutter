import 'package:flutter/material.dart';

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
    // 优化点：Text样式增加可选性，统一主题风格
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
      mainAxisSize: MainAxisSize.min, // 尽量小的高度
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium, // 优化：使用主题样式
        ),
        const SizedBox(height: 8), // 优化：增加标题与输入框间距
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
            // fillColor: Get.isDarkMode ? darkInputFillColor : lightInputFillColor,
            filled: true,
            enabledBorder: OutlineInputBorder(
              /*边角*/
              borderRadius: const BorderRadius.all(
                Radius.circular(5), //边角为5
              ),
              borderSide: BorderSide(
                // color: Get.isDarkMode
                //     ? darkInputFillColor
                //     : lightInputFillColor, //边线颜色为白色
                width: 1, //边线宽度为2
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                // color: Get.isDarkMode
                //     ? darkInputFillColor
                //     : lightInputFillColor, //边框颜色为白色
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
        ),
      ],
    );
  }
}
