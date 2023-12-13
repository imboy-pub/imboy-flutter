import 'dart:async';

import 'package:filter_list/filter_list.dart';

// ignore: implementation_imports
import 'package:filter_list/src/state/filter_state.dart';

// ignore: implementation_imports
import 'package:filter_list/src/state/provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/list.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/tag.dart';
import 'package:imboy/config/const.dart';

// ignore: implementation_imports
import 'package:textfield_tags/textfield_tags.dart';

import 'user_tag_relation_logic.dart';

// ignore: must_be_immutable
class UserTagRelationPage extends StatelessWidget {
  final String peerId; // 用户ID

  String? title;
  final String scene;

  String peerTag;
  final Color tagBackgroundColor;
  final Color tagSelectedBackgroundColor;
  final Color tagColor;
  final Color tagSelectedColor;

  UserTagRelationPage({
    super.key,
    required this.peerId,
    required this.peerTag,
    required this.scene,
    this.title,
    this.tagBackgroundColor = const Color(0xFFE5E5E5),
    this.tagSelectedBackgroundColor = const Color(0xFFE7F9EE),
    this.tagColor = const Color(0xFF7A7A7A),
    this.tagSelectedColor = const Color(0xFF19B84D),
  });

  final logic = Get.put(UserTagRelationLogic());
  final state = Get.find<UserTagRelationLogic>().state;

  Future<void> initData() async {
    state.tagItems.value =
        peerTag.split(',').where((o) => o.trim().isNotEmpty).toList();

    List<String> res = await logic.getRecentTagItems(scene);
    // 当前 tag合并到 recentTagItems
    for (var item in state.tagItems) {
      if (!res.contains(item)) {
        // 排重
        res.add(item);
      }
    }
    state.recentTagItems.value = res;
    state.loaded.value = true;

    state.tagController.addListener(() {
      bool diff =
          listDiff(state.tagItems.toList(), state.tagController.getTags);
      state.tagItems.value = state.tagController.getTags!;
      logic.valueOnChange(diff);
      if (diff) {
        state.tagController.setError = '需要确认提交，该操作才生效'.tr;
      }
    });
  }

  Widget _buildHeader() {
    return TextFieldTags(
      // key: Key('TextFieldTags'),
      // textEditingController: ,
      // focusNode: tfn,
      textfieldTagsController: state.tagController,
      initialTags: state.tagItems,
      textSeparators: const [' ', ','],
      // textSeparators: const [','],
      letterCase: LetterCase.normal,
      validator: (String tag) {
        bool diff = listDiff(
          state.tagItems,
          state.tagController.getTags,
        );
        debugPrint(
            "tag_add_view_validator diff $diff, $tag, len:${tag.length}");
        logic.valueOnChange(diff);
        if (tag.length > 14) {
          // 最最最最最最最最最最最最最最1
          return '最多14个字'.tr;
        }
        if (state.tagController.getTags != null &&
            state.tagController.getTags!.contains(tag)) {
          // return 'you already entered that';
          return '你已经输入过了'.tr;
        }
        return null;
      },

      inputfieldBuilder:
          (context, tecController, fn, error, onChanged, onSubmitted) {
        return ((context, scController, tags, onTagDelete) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: TextField(
              // keyboardType: TextInputType.multiline,
              // minLines: 1,
              // maxLines: null,
              controller: tecController,
              // focusNode: fn,
              decoration: InputDecoration(
                border: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: tagSelectedBackgroundColor, width: 1.0),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: tagSelectedBackgroundColor, width: 1.0),
                ),
                // helperText: '全部标签'.tr,
                helperStyle: TextStyle(
                  color: tagSelectedBackgroundColor,
                ),
                hintText: state.tagController.hasTags ? '' : '选择或输入标签'.tr,
                errorText: error,
                prefixIconConstraints:
                    BoxConstraints(maxWidth: state.distanceToField * 1.0),
                prefixIcon: tags.isEmpty
                    ? null
                    : SingleChildScrollView(
                        controller: scController,
                        scrollDirection: Axis.vertical,
                        child: Wrap(
                          // runSpacing: 7.0,
                          children: (tags.map((String tag) {
                            return TagItem(
                              tag: tag,
                              onTagDelete: (String tag) {
                                onTagDelete(tag);
                                final state2 =
                                    StateProvider.of<FilterState<String>>(
                                        context,
                                        rebuildOnChange: true);
                                state2.removeSelectedItem(tag);
                              },
                              backgroundColor: tagBackgroundColor,
                              tagSelectedColor: tagSelectedColor,
                              selectedBackgroundColor:
                                  tagSelectedBackgroundColor,
                            );
                          }).toList()),
                        )),
              ),
              onChanged: (String tag) {
                debugPrint("input_onChanged $tag");
                logic.state.inputTimer?.cancel();
                logic.state.inputTimer = null;
                logic.state.lastInputTag = tag;

                logic.state.inputTimer =
                    Timer.periodic(const Duration(seconds: 2), (timer) {
                  onSubmitted!(logic.state.lastInputTag);
                  logic.state.lastInputTag = '';
                  logic.state.inputTimer?.cancel();
                  logic.state.inputTimer = null;
                });
              },
              onSubmitted: (String tag) {
                if (tag.isEmpty) {
                  return;
                }
                // debugPrint("input_onSubmitted $tag");
                final state2 = StateProvider.of<FilterState<String>>(context);
                state2.addSelectedItem(tag);
                if (state2.items != null &&
                    state2.items!.contains(tag) == false) {
                  List<String>? items = state2.items;
                  items?.add(tag);
                  state2.items = items;
                }
                state.tagController.addTag = tag;
                // onSubmitted!(tag);
              },
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    initData();

    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      // backgroundColor: Colors.white,
      appBar: PageAppBar(
        title: title ?? '添加标签'.tr,
      ),
      body: SizedBox(
        height: Get.height - 40,
        child: Obx(() => state.loaded.isTrue
            ? FilterListWidget<String>(
                resetButtonText: '置空'.tr,
                applyButtonText: '确认'.tr,
                // hideHeader: true,
                header: _buildHeader(),
                enableOnlySingleSelection: false,
                listData: state.recentTagItems,
                selectedListData: state.tagItems,
                controlButtons: const [ControlButtonType.Reset],
                themeData: FilterListThemeData(
                  context,
                  backgroundColor: AppColors.ChatBg,
                  choiceChipTheme: ChoiceChipThemeData(
                    backgroundColor: tagBackgroundColor,
                    selectedBackgroundColor: tagSelectedBackgroundColor,
                    textStyle: TextStyle(color: tagColor),
                    selectedTextStyle: TextStyle(color: tagSelectedColor),
                  ),
                  controlButtonBarTheme: const ControlButtonBarThemeData.raw(
                    backgroundColor: AppColors.ChatBg,
                    controlButtonTheme: ControlButtonThemeData(
                      borderRadius: 4,
                      primaryButtonTextStyle: TextStyle(color: Colors.white),
                      primaryButtonBackgroundColor: Color(0xFF19B84D),
                      textStyle: TextStyle(color: Color(0xFF19B84D)),
                      backgroundColor: Color(0xFFE5E5E5),
                    ),
                    buttonSpacing: 20,
                    controlContainerDecoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    // margin: margin,
                    // padding: padding,
                    // height: height,
                  ),
                ),
                onApplyButtonClick: (list) async {
                  List<String>? tag =
                      state.tagController.getTags?.toSet().toList();
                  // state.tagController.getTags = tag?.toList();
                  // debugPrint("submit_tag ${tag?.length} ${tag.toString()}, ");
                  bool res = await logic.add(scene, peerId, tag ?? []);
                  if (res) {
                    // EasyLoading.showSuccess('操作成功'.tr);
                    Get.back(result: tag!.join(','));
                  }
                },
                choiceChipLabel: (item) {
                  return item;
                },
                validateSelectedItem: (list, val) {
                  ///  identify if item is selected or not
                  return list!.contains(val);
                },
                onReset: () {
                  state.tagController.clearTags();
                  state.tagController.setError = '需要确认提交，该操作才生效'.tr;
                },
                onSelected: (String item, bool selected) {
                  if (selected) {
                    state.tagController.addTag = item;
                  } else {
                    state.tagController.removeTag = item;
                    state.tagItems.value = state.tagController.getTags!;
                  }
                  // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
                  state.tagController.notifyListeners();
                  // debugPrint("tag_add_page_onSelected $selected, $item");
                },
              )
            : const SizedBox.shrink()),
      ),
    );
  }
}
