import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'update_provider.dart';

class UpdatePage extends ConsumerWidget {
  final String title;
  final Future<bool> Function(String) callback;
  final String value;
  final String field;
  final int maxLength;

  const UpdatePage({
    super.key,
    this.title = "",
    required this.callback,
    this.value = "",
    this.field = "",
    this.maxLength = 56,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(updateTextControllerProvider);
    final focusNode = ref.watch(updateFocusNodeProvider);
    final state = ref.watch(updatePageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // 初始化控制器
    if (controller.text.isEmpty && value.isNotEmpty) {
      controller.text = value;
      Future.delayed(const Duration(milliseconds: 100)).then((e) {
        ref.read(updatePageProvider.notifier).valueOnChange(value, false);
      });
    }

    Widget body = const SizedBox.shrink();
    if (field == "input") {
      body = inputField(context, ref, controller, focusNode);
    } else if (field == "text") {
      body = textField(context, ref, controller, focusNode);
    } else if (field == "gender") {
      body = genderField(context, ref, controller);
    }

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Row(
          children: [
            Expanded(child: Text(title, textAlign: TextAlign.center)),
            Container(
              height: AppSpacing.regular * 4,
              decoration: BoxDecoration(
                color: state.valueChanged
                    ? AppColors.primary
                    : (isDark ? AppColors.iosGray3Dark : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(AppSpacing.regular * 2),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.regular * 2),
                  onTap: state.valueChanged
                      ? () async {
                          if (field == "input") {
                            String trimmedText = controller.text.trim();
                            if (trimmedText.isEmpty) {
                              ref
                                  .read(updatePageProvider.notifier)
                                  .valueOnChange(value, false);
                            } else {
                              bool res = await callback(trimmedText);
                              if (res && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          } else if (field == "text") {
                            String trimmedText = controller.text.trim();
                            bool res = await callback(trimmedText);
                            if (res && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } else if (field == "gender") {
                            bool res = await callback(state.value);
                            if (res && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        }
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.regular * 2,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t.buttonAccomplish,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.small,
                        fontWeight: FontWeight.w600,
                        color: state.valueChanged
                            ? Colors.white
                            : AppColors.getTextColor(
                                Theme.of(context).brightness,
                                isSecondary: true,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: body,
      ),
    );
  }

  Widget inputField(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: AppRadius.borderRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextFormField(
        autofocus: true,
        focusNode: focusNode,
        controller: controller,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(14, 14, 8, 14),
          filled: false,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          border: InputBorder.none,
        ),
        readOnly: false,
        onFieldSubmitted: (val) async {
          if (val.isEmpty) {
            ref.read(updatePageProvider.notifier).valueOnChange(value, false);
          } else {
            bool res = await callback(val);
            if (res && context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        onChanged: (val) {
          onChanged(val, ref, controller);
        },
        onSaved: (val) {},
        validator: (val) {
          return null;
        },
      ),
    );
  }

  void onChanged(String? val, WidgetRef ref, TextEditingController controller) {
    if (val == '' || val == value) {
      ref.read(updatePageProvider.notifier).valueOnChange(value, false);
    } else {
      ref.read(updatePageProvider.notifier).valueOnChange(value, true);
    }
    ref.read(updatePageProvider.notifier).setVal(val ?? '');
  }

  Widget textField(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : Colors.white,
              borderRadius: AppRadius.borderRadiusMedium,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              autofocus: true,
              focusNode: focusNode,
              controller: controller,
              keyboardType: TextInputType.multiline,
              maxLines: 6,
              minLines: 4,
              maxLength: maxLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                height: 1.4,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(16),
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: isDark
                      ? AppColors.iosGray3Dark
                      : const Color(0xFFCCCCCC),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                counterStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.iosGray : const Color(0xFF999999),
                ),
              ),
              readOnly: false,
              onFieldSubmitted: (val) async {
                bool res = await callback(val.trim());
                if (res && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              onChanged: (val) {
                onChanged(val, ref, controller);
              },
              onSaved: (val) {},
              validator: (val) {
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget genderField(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
  ) {
    Widget secondary = const Text(
      '√',
      style: TextStyle(fontSize: 20, color: Colors.green),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(updatePageProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: AppRadius.borderRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            value: '1',
            title: Text(
              t.male,
              style: TextStyle(
                fontSize: state.value == '1' ? 20 : 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            selected: false,
            secondary: state.value == '1' ? secondary : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).colorScheme.primary,
            // ignore: deprecated_member_use
            groupValue: state.value,
            // ignore: deprecated_member_use
            onChanged: (val) {
              onChanged(val, ref, controller);
            },
          ),
          const Divider(height: 0.5),
          RadioListTile<String>(
            value: '2',
            title: Text(
              t.female,
              style: TextStyle(
                fontSize: state.value == '2' ? 20 : 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            selected: false,
            secondary: state.value == '2' ? secondary : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).colorScheme.primary,
            // ignore: deprecated_member_use
            groupValue: state.value,
            // ignore: deprecated_member_use
            onChanged: (val) {
              onChanged(val, ref, controller);
            },
          ),
          const Divider(height: 0.5),
          RadioListTile<String>(
            value: '3',
            title: Text(
              t.keepSecret,
              style: TextStyle(
                fontSize: state.value == '3' ? 20 : 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            selected: false,
            secondary: state.value == '3' ? secondary : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).colorScheme.primary,
            // ignore: deprecated_member_use
            groupValue: state.value,
            // ignore: deprecated_member_use
            onChanged: (val) {
              onChanged(val, ref, controller);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
