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
import 'package:imboy/theme/default/app_colors.dart';

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
      state.tagItems.value = state.tagController.getTags! as List<String>;
      logic.valueOnChange(diff);
      if (diff) {
        state.tagController.setError = 'needSubmitEffect'.tr;
      }
    });
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return TextFieldTags(
      // key: Key('TextFieldTags'),
      // textEditingController: ,
      // focusNode: tfn,
      textfieldTagsController: state.tagController,
      initialTags: state.tagItems,
      textSeparators: const [' ', ','],
      letterCase: LetterCase.normal,
      validator: (dynamic tag) {
        bool diff = listDiff(
          state.tagItems,
          state.tagController.getTags,
        );
        debugPrint(
            "tag_add_view_validator diff $diff, $tag, len:${tag.length}");
        logic.valueOnChange(diff);
        if (tag.length > 14) {
          // 最最最最最最最最最最最最最最1
          return 'upToWords'.trArgs(['14']);
        }
        if (state.tagController.getTags != null &&
            state.tagController.getTags!.contains(tag)) {
          // return 'you already entered that';
          return 'alreadyEntered'.tr;
        }
        return null;
      },
      inputFieldBuilder: (
        BuildContext context,
        InputFieldValues<dynamic> inputFieldValues,
      ) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: TextField(
            // keyboardType: TextInputType.multiline,
            // minLines: 1,
            // maxLines: null,
            controller: inputFieldValues.textEditingController,
            focusNode: inputFieldValues.focusNode,
            // focusNode: fn,
            style: TextStyle(
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              // helperText: 'allTags'.tr,
              helperStyle: TextStyle(
                color: tagSelectedBackgroundColor,
              ),
              hintText: inputFieldValues.tags.isNotEmpty
                  ? ''
                  : 'selectOrEnterTag'.tr,
              hintStyle: TextStyle(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
              errorText: inputFieldValues.error,
              prefixIconConstraints:
                  BoxConstraints(maxWidth: state.distanceToField * 1.0),
              prefixIcon: inputFieldValues.tags.isEmpty
                  ? null
                  : SingleChildScrollView(
                      controller: inputFieldValues.tagScrollController,
                      scrollDirection: Axis.vertical,
                      child: Wrap(
                        // runSpacing: 7.0,
                        children: (inputFieldValues.tags.map((dynamic tag) {
                          return TagItem(
                            tag: tag,
                            onTagDelete: (String tag) {
                              inputFieldValues.onTagRemoved(tag);
                              final state2 =
                                  StateProvider.of<FilterState<String>>(context,
                                      rebuildOnChange: true);
                              state2.removeSelectedItem(tag);
                            },
                            backgroundColor: isDark
                                ? colorScheme.surfaceContainerHighest
                                : tagBackgroundColor,
                            tagSelectedColor: tagSelectedColor,
                            selectedBackgroundColor: tagSelectedBackgroundColor,
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
                inputFieldValues.onTagRemoved(logic.state.lastInputTag);
                logic.state.lastInputTag = '';
                logic.state.inputTimer?.cancel();
                logic.state.inputTimer = null;
              });
            },
            onSubmitted: (String tag) {
              if (tag.isEmpty) {
                return;
              }
              debugPrint("input_onSubmitted $tag");
              if (tag.length > 14) {
                return;
              }
              final state2 = StateProvider.of<FilterState<String>>(context);
              state2.addSelectedItem(tag);
              if (state2.items != null &&
                  state2.items!.contains(tag) == false) {
                List<String>? items = state2.items;
                items?.add(tag);
                state2.items = items;
              }
              state.tagController.addTag(tag);
              // onSubmitted!(tag);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    initData();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: title ?? 'addTag'.tr,
        automaticallyImplyLeading: true,
      ),
      body: SizedBox(
        height: Get.height - 40,
        child: Obx(() => state.loaded.isTrue
            ? FilterListWidget<String>(
                resetButtonText: 'buttonSetEmpty'.tr,
                applyButtonText: 'buttonConfirm'.tr,
                selectedItemsText: 'selectedItems'.trArgs(['']).trim(),
                // hideHeader: true,
                header: _buildHeader(context),
                enableOnlySingleSelection: false,
                listData: state.recentTagItems.value,
                selectedListData: state.tagItems.value,
                controlButtons: const [ControlButtonType.Reset],
                themeData: FilterListThemeData(
                  context,
                  backgroundColor:
                      isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
                  choiceChipTheme: ChoiceChipThemeData(
                    backgroundColor: isDark ? Colors.black12 : Colors.white,
                    selectedBackgroundColor: isDark
                        ? AppColors.primaryGreen.withValues(alpha: 0.2)
                        : tagSelectedBackgroundColor,
                    textStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87),
                    selectedTextStyle: TextStyle(
                        color:
                            isDark ? AppColors.primaryGreen : tagSelectedColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  controlButtonBarTheme: ControlButtonBarThemeData.raw(
                    controlButtonTheme: ControlButtonThemeData(
                      borderRadius: 8,
                      primaryButtonTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      primaryButtonBackgroundColor: AppColors.primaryGreen,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.grey.withValues(alpha: 0.6),
                    ),
                    buttonSpacing: 16,
                    controlContainerDecoration: BoxDecoration(
                      color: isDark ? colorScheme.surface : Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  headerTheme: HeaderThemeData(
                    backgroundColor:
                        isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
                    // searchFieldDecoration 参数已在新版本中移除
                  ),
                ),
                onApplyButtonClick: (list) async {
                  state.tagItems.value = list ?? [];
                  // 更新 tagController
                  List<String> tags = state.tagController.getTags?.cast<String>() ?? [];
                  if (tags.isNotEmpty) {
                    for (var tag in tags) {
                      state.tagController.onTagRemoved(tag);
                    }
                  }
                  for (var tag in state.tagItems) {
                    state.tagController.addTag(tag);
                  }
                  logic.valueOnChange(true);
                  if (logic.valueChanged.isTrue) {
                    // Get.back(result: state.tagItems.join(','));
                    bool res = await logic.add(
                      scene,
                      peerId,
                      state.tagItems,
                    );
                    if (res) {
                      Get.back(result: state.tagItems.join(','));
                    }
                  }
                },
                choiceChipLabel: (item) {
                  return item;
                },
                validateSelectedItem: (list, val) {
                  ///  identify if item is selected or not
                  return list!.contains(val);
                },
                // onResetButtonClick 参数已在新版本中移除
              )
            : const SizedBox.shrink()),
      ),
    );
  }
}
