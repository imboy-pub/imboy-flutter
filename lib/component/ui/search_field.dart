import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class SearchField extends StatelessWidget implements PreferredSizeWidget {
  TextEditingController controller;

  /// {@macro flutter.widgets.editableText.onSubmitted}
  ///
  /// See also:
  ///
  ///  * [TextInputAction.next] and [TextInputAction.previous], which
  ///    automatically shift the focus to the next/previous focusable item when
  ///    the user is done editing.
  final ValueChanged<String>? onSubmitted;

  /// {@macro flutter.widgets.editableText.onChanged}
  ///
  /// See also:
  ///
  ///  * [inputFormatters], which are called before [onChanged]
  ///    runs and can validate and change ("format") the input value.
  ///  * [onEditingComplete], [onSubmitted]:
  ///    which are more specialized input change notifications.
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  double? top;
  double? left;

  SearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.onChanged,
    this.onClear,
    this.top,
    this.left,
  });

  @override
  Widget build(BuildContext context) {
    return n.Padding(
      top: top ?? 0.0,
      left: left ?? 0.0,
      child: n.Row([
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.text,
            // TextField 垂直居中光标
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              filled: true,
              // 设置为true以启用填充背景
              fillColor: Theme.of(context).colorScheme.onSecondary,
              // 设置背景颜色
              hintText: 'search'.tr,
              border: InputBorder.none,
              // 去除边框线条
              contentPadding: EdgeInsets.zero,
              prefixIcon: const Icon(Icons.search),
              // 添加搜索图标
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.text = '';
                        controller.clear();
                        if (onClear != null) {
                          onClear!();
                        }
                      },
                    )
                  : null,
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
        TextButton(
          onPressed: () {
            Get.back();
          },
          child: Text(
            'button_cancel'.tr,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ]),
    );
  }

  @override
  @override
  Size get preferredSize => Size(120, 50 + (top ?? 0.0));
}
