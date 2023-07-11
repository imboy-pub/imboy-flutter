import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/contact_tag/contact_tag_logic.dart';
import 'package:imboy/page/contact/contact_tag_detail/contact_tag_detail_logic.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:niku/namespace.dart' as n;

import 'user_tag_update_logic.dart';

// ignore: must_be_immutable
class UserTagUpdatePage extends StatelessWidget {
  UserTagModel tag;
  final String scene;

  UserTagUpdatePage({
    super.key,
    required this.tag,
    required this.scene,
  });

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(UserTagUpdateLogic());
    final state = Get.find<UserTagUpdateLogic>().state;
    state.textController.text = tag.name;

    return Scaffold(
        // 输入框(TextField)被键盘遮挡解决方案
        resizeToAvoidBottomInset: false,
        appBar: PageAppBar(
          leading: InkWell(
            onTap: () {
              Get.close(1);
            },
            child: const Icon(Icons.close),
          ),
          title: '更改标签名称'.tr,
          // rightDMActions: [],
        ),
        body: SizedBox(
            width: Get.width,
            height: 120,
            child: n.Column(
              [
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
                    textInputAction: TextInputAction.none,
                    decoration: InputDecoration(
                        contentPadding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                        filled: true,
                        fillColor: Colors.white,
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3),
                            borderSide: const BorderSide(
                              width: 1.0,
                              color: AppColors.AppBarColor,
                            )),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3),
                            borderSide: const BorderSide(
                              width: 1.0,
                              color: AppColors.AppBarColor,
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
                      debugPrint("onFieldSubmitted $val");
                      if (val == '') {
                        state.valueChanged.value = false;
                      } else {}
                    },
                    //style: ,
                    onChanged: (val) {
                      if (tag.name == val) {
                        state.valueChanged.value = false;
                      } else {
                        state.valueChanged.value = true;
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
                        } else {
                          debugPrint("submit_trimmedText $trimmedText");
                          bool res = await logic.changeName(
                            scene: scene,
                            tagId: tag.tagId,
                            tagName: trimmedText,
                          );
                          if (res) {
                            Get.back();
                            Get.find<ContactTagLogic>().replaceObjectTag(
                                scene: scene,
                                oldName: tag.name,
                                newName: trimmedText);
                            final index = Get.find<ContactTagLogic>()
                                .state
                                .items
                                .indexWhere((e) => e.tagId == tag.tagId);
                            if (index > -1) {
                              tag.name = trimmedText;
                              Get.find<ContactTagLogic>()
                                  .state
                                  .items
                                  .setRange(index, index + 1, [tag]);
                            }
                            try {
                              Get.find<ContactTagDetailLogic>()
                                  .state
                                  .tagName
                                  .value = trimmedText;
                            } catch (e) {
                              //
                            }
                            EasyLoading.showSuccess('操作成功'.tr);
                          } else {
                            EasyLoading.showError('操作失败'.tr);
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
                        ),
                      ),
                      style: state.valueChanged.isTrue
                          ? ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                AppColors.primaryElement,
                              ),
                              foregroundColor: MaterialStateProperty.all<Color>(
                                Colors.white,
                              ),
                              minimumSize:
                                  MaterialStateProperty.all(const Size(60, 40)),
                              visualDensity: VisualDensity.compact,
                              padding:
                                  MaterialStateProperty.all(EdgeInsets.zero),
                            )
                          : ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                AppColors.AppBarColor,
                              ),
                              foregroundColor: MaterialStateProperty.all<Color>(
                                AppColors.LineColor,
                              ),
                              minimumSize:
                                  MaterialStateProperty.all(const Size(60, 40)),
                              visualDensity: VisualDensity.compact,
                              padding:
                                  MaterialStateProperty.all(EdgeInsets.zero),
                            ),
                    ),
                  )
                ])
                  // 内容居中
                  ..mainAxisAlignment = MainAxisAlignment.center
              ],
              // 顶部对齐
              mainAxisAlignment: MainAxisAlignment.start,
            )));
  }
}
