import 'package:filter_list/filter_list.dart';
import 'package:fluent_ui/fluent_ui.dart' as fl;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/list.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/tag.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;
import 'package:textfield_tags/textfield_tags.dart';

import 'tag_add_logic.dart';

// ignore: must_be_immutable
class TagAddPage extends StatelessWidget {
  final String peerId; // 用户ID

  String peerTag;
  final Color tagBackgroundColor;
  final Color tagSelectedBackgroundColor;

  TagAddPage({
    super.key,
    required this.peerId,
    required this.peerTag,
    this.tagBackgroundColor = const Color(0xfff8f8f8),
    this.tagSelectedBackgroundColor = const Color(0xFF649BEC),
  });

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(TagAddLogic());
    final state = Get.find<TagAddLogic>().state;
    state.tagItems.value =
        peerTag.split(',').where((o) => o.trim().isNotEmpty).toList();
    for (var item in state.tagItems) {
      if (!state.recentTagItems.contains(item)) {
        state.recentTagItems.add(item);
      }
    }
    state.tagController.addListener(() {
      bool diff =
          listDiff(state.tagItems.toList(), state.tagController.getTags);
      state.tagItems.value = state.tagController.getTags!;
      // state.tagController.setError = '';
      // debugPrint(
      //     "tag_add_view_tagsController_addListener $diff tagItems ${state.tagItems.value.toList().toString()}");
      // debugPrint(
      //     "tag_add_view_tagsController_addListener $diff getTags ${state.tagController.getTags.toString()}");
      logic.valueOnChange(diff);
      if (diff) {
        state.tagController.setError = '需要确认提交，该操作才生效'.tr;
      }
    });
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      // backgroundColor: Colors.white,
      appBar: PageAppBar(
        titleWidget: n.Row(
          [
            Expanded(
              child: Text(
                '添加标签'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // 中间用Expanded控件
            ),
            ElevatedButton(
              onPressed: () async {
                //
              },
              // ignore: sort_child_properties_last
              child: Text(
                '新建'.tr,
                textAlign: TextAlign.center,
              ),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(
                  // AppColors.primaryElement,
                  tagSelectedBackgroundColor,
                ),
                foregroundColor: MaterialStateProperty.all<Color>(
                  Colors.white,
                ),
                minimumSize: MaterialStateProperty.all(const Size(60, 40)),
                visualDensity: VisualDensity.compact,
                padding: MaterialStateProperty.all(EdgeInsets.zero),
              ),
            ),
          ],
        ),
      ),
      body: fl.FluentTheme(
        data: fl.FluentThemeData(),
        child: n.Padding(
          left: 12,
          top: 12,
          right: 12,
          child: n.Column(
            [
              TextFieldTags(
                // key: Key('TextFieldTags'),
                // textEditingController: ,
                // focusNode: tfn,
                textfieldTagsController: state.tagController,
                initialTags: state.tagItems,
                textSeparators: const [' ', ','],
                // textSeparators: const [','],
                letterCase: LetterCase.normal,
                validator: (String tag) {
                  bool diff =
                      listDiff(state.tagItems, state.tagController.getTags);
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

                inputfieldBuilder: (context, tecController, fn, error,
                    onChanged, onSubmitted) {
                  return ((context, scController, tags, onTagDelete) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: TextField(
                        controller: tecController,
                        focusNode: fn,
                        decoration: InputDecoration(
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: tagSelectedBackgroundColor, width: 1.0),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: tagSelectedBackgroundColor, width: 1.0),
                          ),
                          // helperText: '全部标签'.tr,
                          helperStyle: TextStyle(
                            color: tagSelectedBackgroundColor,
                          ),
                          hintText:
                              state.tagController.hasTags ? '' : '选择或输入标签'.tr,
                          errorText: error,
                          prefixIconConstraints: BoxConstraints(
                              maxWidth: state.distanceToField * 1.0),
                          prefixIcon: tags.isNotEmpty
                              ? SingleChildScrollView(
                                  controller: scController,
                                  scrollDirection: Axis.horizontal,
                                  child: n.Row(tags.map((String tag) {
                                    return TagItem(
                                      tag: tag,
                                      onTagDelete: (String tag) {
                                        debugPrint(
                                            "tag_add_page_onTagDelete $tag");
                                        onTagDelete(tag);
                                        // Get.find<FilterState>().removeSelectedItem(tag);
                                        // final state = StateProvider.of<FilterState<String>>(context);
                                        // state.removeSelectedItem(tag);
                                      },
                                      backgroundColor: tagBackgroundColor,
                                      selectedBackgroundColor:
                                          tagSelectedBackgroundColor,
                                    );
                                  }).toList()),
                                )
                              : null,
                        ),
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                      ),
                    );
                  });
                },
              ),
              n.Padding(
                top: 10,
                child: fl.SizedBox(
                  height: Get.height - 160,
                  child: FilterListWidget<String>(
                    resetButtonText: '置空'.tr,
                    applyButtonText: '确认'.tr,
                    hideHeader: true,
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
                      ),
                    ),
                    onApplyButtonClick: (list) async {
                      List<String>? tag =
                          state.tagController.getTags?.toSet().toList();
                      // state.tagController.getTags = tag?.toList();
                      debugPrint(
                          "submit_tag ${tag?.length} ${tag.toString()}, ");
                      bool res = await logic.add(peerId, tag ?? []);
                      if (res) {
                        // EasyLoading.showSuccess('操作成功'.tr);
                        Get.back(result: tag!.join(','));
                      }
                    },
                    choiceChipLabel: (item) {
                      /// Used to display text on chip

                      debugPrint(
                          "tag_add_page_choiceChipLabel $item, ${state.tagItems.contains(item)}");
                      return item;
                    },
                    validateSelectedItem: (list, val) {
                      ///  identify if item is selected or not
                      debugPrint(
                          "tag_add_page_validateSelectedItem $val, ${list!.contains(val)}, ${list.toString()}");
                      // if (list.contains(val)) {
                      //   state.tagController.addTag = val;
                      // }

                      return list.contains(val);
                    },
                    onReset: () {
                      state.tagController.clearTags();

                      state.tagController.setError = '需要确认提交，该操作才生效'.tr;
                      debugPrint(
                          "tag_add_page_onReset ${state.tagController.getTags?.length}");

                      /// When search query change in search bar then this method will be called
                      ///
                      // return true;
                    },
                    onSelected: (String item, bool selected) {
                      if (selected) {
                        state.tagController.addTag = item;
                      } else {
                        state.tagController.removeTag = item;
                        state.tagItems.value = state.tagController.getTags!;
                      }
                      // debugPrint("tag_add_page_onSelected $selected, $item, index $index");
                      state.tagController.notifyListeners();
                    },
                  ),
                ),
              ),
            ],
            // 内容文本左对齐
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
        ),
      ),
    );
  }
}
