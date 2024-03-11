import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_logic.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_logic.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:niku/namespace.dart' as n;

import 'user_tag_save_logic.dart';

// ignore: must_be_immutable
class UserTagSavePage extends StatelessWidget {
  UserTagModel? tag;
  final String scene;

  UserTagSavePage({
    super.key,
    this.tag,
    required this.scene,
  });

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(UserTagUpdateLogic());
    final state = Get.find<UserTagUpdateLogic>().state;
    state.textController.text = tag?.name ?? '';

    return Scaffold(
      // 输入框(TextField)被键盘遮挡解决方案
      resizeToAvoidBottomInset: false,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        leading: InkWell(
          onTap: () {
            if (Get.isBottomSheetOpen ?? false) {
              Get.closeAllBottomSheets();
            } else {
              Get.back();
            }
          },
          child: const Icon(Icons.close),
        ),
        title: tag == null ? 'add_tag'.tr : 'change_tag_name'.tr,
        // rightDMActions: [],
      ),
      body: SizedBox(
          width: Get.width,
          height: 120,
          child: n.Column([
            n.Padding(
              top: 10,
              bottom: 10,
              left: 10,
              right: 10,
              child: TextFormField(
                autofocus: true,
                focusNode: state.inputFocusNode,
                controller: state.textController,
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
                        borderSide: const BorderSide(
                          width: 1.0,
                          // color: AppColors.AppBarColor,
                        )),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(
                          width: 1.0,
                          // color: AppColors.AppBarColor,
                        )),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3),
                      borderSide:
                          const BorderSide(width: 1.0, color: Colors.red),
                    ),
                    errorStyle: const TextStyle(),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3),
                      borderSide:
                          const BorderSide(width: 1.0, color: Colors.red),
                    ),
                    border: InputBorder.none),
                readOnly: false,
                onFieldSubmitted: (val) async {
                  FocusScope.of(Get.context!).requestFocus();
                  // debugPrint("onFieldSubmitted $val");
                  if (val == '') {
                    state.valueChanged.value = false;
                  } else {}
                },
                //style: ,
                onChanged: (val) {
                  if (tag?.name == val) {
                    state.valueChanged.value = false;
                  } else {
                    state.valueChanged.value = true;
                  }
                  if (val.isEmpty) {
                    state.valueChanged.value = false;
                  }
                },
                onSaved: (value) {},
                validator: (value) {
                  return null;
                },
              ),
            ),
            n.Row([
              Obx(
                () => ElevatedButton(
                  onPressed: () async {
                    String trimmedText = state.textController.text.trim();
                    if (trimmedText == '') {
                      state.valueChanged.value = false;
                    } else if (tag == null && state.valueChanged.isTrue) {
                      tag = await logic.addTag(
                        scene: scene,
                        tagName: trimmedText,
                      );
                      if (tag != null) {
                        if (Get.isBottomSheetOpen ?? false) {
                          Get.closeAllBottomSheets();
                        } else {
                          Get.back();
                        }
                      }
                    } else if (state.valueChanged.isTrue) {
                      debugPrint("submit_trimmedText $trimmedText");
                      bool res = await logic.changeName(
                        scene: scene,
                        tagId: tag?.tagId ?? 0,
                        tagName: trimmedText,
                      );
                      if (res) {
                        Get.find<ContactTagListLogic>().replaceObjectTag(
                          scene: scene,
                          oldName: tag?.name ?? '',
                          newName: trimmedText,
                        );
                        tag?.name = trimmedText;
                        Get.find<ContactTagListLogic>().updateTag(tag);
                        try {
                          Get.find<ContactTagDetailLogic>()
                              .state
                              .tagName
                              .value = trimmedText;
                        } catch (e) {
                          //
                        }
                        EasyLoading.showSuccess('tip_success'.tr);

                        if (Get.isBottomSheetOpen ?? false) {
                          Get.closeAllBottomSheets();
                        } else {
                          Get.back();
                        }
                      }
                    }
                  },
                  // ignore: sort_child_properties_last
                  child: n.Padding(
                    left: 40,
                    right: 40,
                    child: Text(
                      'button_accomplish'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16.0,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  style: state.valueChanged.isTrue
                      ? ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                            Colors.green,
                          ),
                          foregroundColor: MaterialStateProperty.all<Color>(
                            Colors.white,
                          ),
                          minimumSize:
                              MaterialStateProperty.all(const Size(60, 40)),
                          visualDensity: VisualDensity.compact,
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        )
                      : ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                            Colors.green.withOpacity(0.6),
                          ),
                          foregroundColor: MaterialStateProperty.all<Color>(
                            Colors.white.withOpacity(0.6),
                          ),
                          minimumSize:
                              MaterialStateProperty.all(const Size(60, 40)),
                          visualDensity: VisualDensity.compact,
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        ),
                ),
              )
            ])
              // 内容居中
              ..mainAxisAlignment = MainAxisAlignment.center
          ],
              // 顶部对齐
              mainAxisAlignment: MainAxisAlignment.start)),
    );
  }
}
