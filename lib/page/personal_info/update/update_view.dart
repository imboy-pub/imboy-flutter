import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/page/mine/select_region/select_region_logic.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/radio_list_title.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'update_logic.dart';

// ignore: must_be_immutable
class UpdatePage extends StatelessWidget {
  final String title;
  final Future<bool> Function(String) callback;

  String value;
  final String field;
  final int maxLength;

  // final EdgeInsetsGeometry? padding;

  UpdatePage({
    super.key,
    this.title = "",
    required this.callback,
    this.value = "",
    this.field = "",
    this.maxLength = 56,
    // this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
  });

  final logic = Get.put(UpdatePageLogic());
  final regionLogic = Get.put(SelectRegionLogic(), tag: "UpdatePage");

  @override
  Widget build(BuildContext context) {
    logic.val.value = value;
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      // 设置提交按钮灰色
      logic.valueOnChange(false);
    });
    Widget body = const SizedBox.shrink();
    if (field == "input") {
      logic.textController.text = value;
      body = inputField(context);
    } else if (field == "text") {
      logic.textController.text = value;
      logic.valueOnChange(true);
      body = textField(context);
    } else if (field == "gender") {
      logic.valueOnChange(true);
      body = genderField(context);
    }
    // double top = 0;
    // if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
    //   top = 22;
    // }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Row(
          children: [
            Expanded(child: Text(title, textAlign: TextAlign.center)),
            Obx(
              () => Container(
                height: ThemeManager.instance.mainSpace * 4,
                decoration: BoxDecoration(
                  color: logic.valueChanged.isTrue
                      ? AppColors.primaryGreen
                      : (isDark
                            ? const Color(0xFF48484A)
                            : const Color(0xFFE5E5E5)),
                  borderRadius: BorderRadius.circular(
                    ThemeManager.instance.mainSpace * 2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      ThemeManager.instance.mainSpace * 2,
                    ),
                    onTap: logic.valueChanged.isTrue
                        ? () async {
                            if (field == "input") {
                              String trimmedText = logic.textController.text
                                  .trim();
                              if (trimmedText == '') {
                                logic.valueOnChange(false);
                              } else {
                                bool res = await callback(trimmedText);
                                if (res) {
                                  Get.back();
                                }
                              }
                            } else if (field == "text") {
                              String trimmedText = logic.textController.text
                                  .trim();
                              bool res = await callback(trimmedText);
                              if (res) {
                                Get.back();
                              }
                            } else if (field == "gender") {
                              bool res = await callback(logic.val.value);
                              if (res) {
                                Get.back();
                              }
                            }
                          }
                        : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ThemeManager.instance.mainSpace * 2,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'buttonAccomplish'.tr,
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.small,
                          fontWeight: FontWeight.w600,
                          color: logic.valueChanged.isTrue
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

  Widget inputField(BuildContext context) {
    return TextFormField(
      autofocus: true,
      focusNode: logic.inputFocusNode,
      controller: logic.textController,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
        filled: true,
        fillColor: Get.isDarkMode
            ? const Color.fromRGBO(70, 70, 70, 1.0)
            : Colors.white70,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(
            width: 1.0,
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(
            width: 1.0,
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(width: 1.0, color: Colors.red),
        ),
        errorStyle: const TextStyle(),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(width: 1.0, color: Colors.red),
        ),
        border: InputBorder.none,
      ),
      readOnly: false,
      onFieldSubmitted: (value) async {
        // FocusScope.of(Get.context!).requestFocus();
        if (value == '') {
          logic.valueOnChange(false);
        } else {
          bool res = await callback(value);
          if (res) {
            Get.back();
          }
        }
      },
      //style: ,
      onChanged: (value) {
        onChanged(value);
      },
      onSaved: (value) {},
      validator: (value) {
        return null;
      },
    );
  }

  void onChanged(String? val) {
    iPrint("onChanged ${logic.val.value} = $val");
    if (val == '' || val == value) {
      logic.valueOnChange(false);
    } else {
      logic.valueOnChange(true);
    }
    logic.setVal(val ?? '');
  }

  Widget textField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 输入提示
          // Padding(
          //   padding: const EdgeInsets.only(bottom: 12),
          //   child: Text(
          //     'signatureInputHint'.tr,
          //     style: TextStyle(
          //       fontSize: 14,
          //       color: isDark
          //           ? const Color(0xFF8E8E93)
          //           : const Color(0xFF999999),
          //     ),
          //   ),
          // ),

          // 输入框容器
          Container(
            decoration: BoxDecoration(
              // color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 0.5,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
            child: TextFormField(
              autofocus: true,
              focusNode: logic.inputFocusNode,
              controller: logic.textController,
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
                // hintText: 'signaturePlaceholder'.tr,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: isDark
                      ? const Color(0xFF48484A)
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
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF999999),
                ),
              ),
              readOnly: false,
              onFieldSubmitted: (value) async {
                bool res = await callback(value.trim());
                if (res) {
                  Get.back();
                }
              },
              onChanged: (value) {
                onChanged(value);
              },
              onSaved: (value) {},
              validator: (value) {
                return null;
              },
            ),
          ),

          // 底部提示
          // Padding(
          //   padding: const EdgeInsets.only(top: 12),
          //   child: Text(
          //     'signatureTips'.tr,
          //     style: TextStyle(
          //       fontSize: 12,
          //       color: isDark
          //           ? const Color(0xFF8E8E93)
          //           : const Color(0xFF999999),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget genderField(BuildContext context) {
    Widget secondary = const Text(
      '√',
      style: TextStyle(fontSize: 20, color: Colors.green),
    );
    return Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IMBoyRadioListTile(
            value: '1',
            title: Text(
              'male'.tr,
              style: TextStyle(
                fontSize: logic.val.value == '1' ? 20 : 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            selected: false,
            secondary: logic.val.value == '1' ? secondary : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).colorScheme.primary,
            groupValue: logic.val.value,
            onChanged: (val) {
              onChanged(val);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: HorizontalLine(
              height: Get.isDarkMode ? 0.5 : 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          IMBoyRadioListTile(
            value: '2',
            title: Text(
              'female'.tr,
              style: TextStyle(
                fontSize: logic.val.value == '2' ? 20 : 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            selected: false,
            secondary: logic.val.value == '2' ? secondary : null,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).colorScheme.primary,
            groupValue: logic.val.value,
            onChanged: (val) {
              onChanged(val);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: HorizontalLine(
              height: Get.isDarkMode ? 0.5 : 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          IMBoyRadioListTile(
            value: '3',
            title: Text(
              'keepSecret'.tr,
              style: TextStyle(
                fontSize: logic.val.value == '3' ? 20 : 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            selected: false,
            secondary: logic.val.value == '3' ? secondary : null,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0.0),
                topRight: Radius.circular(0.0),
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(Get.context!).colorScheme.primary,
            groupValue: logic.val.value,
            onChanged: (val) {
              onChanged(val);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: HorizontalLine(
              height: Get.isDarkMode ? 0.5 : 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
