import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 搜索字段组件 - 使用优化后的主题系统
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
    return Container(
      padding: EdgeInsets.only(
        top: top ?? 0.0,
        left: left ?? 0.0,
        right: 8.0,
        bottom: 8.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // 使用主题表面色
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest, // 使用主题容器最高色
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.text,
                textAlignVertical: TextAlignVertical.center, // TextField 垂直居中光标
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent, // 使用透明背景，让容器背景显示
                  hintText: t.search,
                  hintStyle: ThemeManager.instance.getTextStyle(
                    FontSizeType.normal,
                    color: AppColors.textSecondary.withValues(
                      alpha: 0.7,
                    ), // 使用主题次要文字色
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: AppColors.primaryGreen, // 使用主题主色
                      width: 2.0,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.search,
                      color: AppColors.textSecondary, // 使用主题次要文字色
                      size: 20,
                    ),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.clear,
                              color: AppColors.textSecondary, // 使用主题次要文字色
                              size: 16,
                            ),
                          ),
                          onPressed: () {
                            controller.clear();
                            if (onClear != null) {
                              onClear!();
                            }
                          },
                          splashRadius: 20,
                        )
                      : null,
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.normal,
                  color: Theme.of(context).colorScheme.onSurface, // 使用主题文字色
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 取消按钮 - 使用优化后的主题样式
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              t.buttonCancel,
              style: ThemeManager.instance.getTextStyle(
                FontSizeType.normal,
                color: AppColors.primaryGreen, // 使用主题主色
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size(120, 56 + (top ?? 0.0));
}
