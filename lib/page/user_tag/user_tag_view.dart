import 'package:filter_list/filter_list.dart';
// ignore: implementation_imports
import 'package:filter_list/src/state/filter_state.dart';
// ignore: implementation_imports
import 'package:filter_list/src/state/provider.dart';
import 'package:niku/namespace.dart' as n;
// ignore: implementation_imports
import 'package:textfield_tags/textfield_tags.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/list.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/tag.dart';
import 'package:imboy/config/const.dart';

import 'user_tag_logic.dart';

// ignore: must_be_immutable
class UserTagPage extends StatelessWidget {
  final String peerId; // 用户ID

  String peerTag;
  final Color tagBackgroundColor;
  final Color tagSelectedBackgroundColor;

  UserTagPage({
    super.key,
    required this.peerId,
    required this.peerTag,
    this.tagBackgroundColor = const Color(0xfff8f8f8),
    this.tagSelectedBackgroundColor = const Color(0xFF649BEC),
  });

  final logic = Get.put(TagAddLogic());
  final state = Get.find<TagAddLogic>().state;

  Future<void> initData() async {
    state.tagItems.value =
        peerTag.split(',').where((o) => o.trim().isNotEmpty).toList();

    logic.getRecentTagItems(peerId);

    state.tagController.addListener(() {
      bool diff = listDiff(state.tagItems.toList(), state.tagController.getTags);
      state.tagItems.value = state.tagController.getTags!;
      logic.valueOnChange(diff);
      if (diff) {
        state.tagController.setError = '需要确认提交，该操作才生效'.tr;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    initData();

    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      // backgroundColor: Colors.white,
      appBar: PageAppBar(
        title: '添加标签'.tr,
        /*
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
                Get.bottomSheet(
                  SizedBox(
                    width: Get.width,
                    height: 172,
                    child: n.Wrap(
                      [
                        Center(
                          child: TextButton(
                            child: Text(
                              '新建标签'.tr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                // color: Colors.white,
                                fontSize: 16.0,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            onPressed: () async {

                            },
                          ),
                        ),
                        const Divider(),
                        const HorizontalLine(height: 6),
                        Center(
                          child: n.Row([
                            Expanded(child: TextButton(
                              onPressed: () => Get.back(),
                              child: Text(
                                'button_cancel'.tr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  // color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            )),
                            Expanded(child: TextButton(
                              onPressed: () => Get.back(),
                              child: Text(
                                '完成'.tr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  // color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ))
                          ]),
                        )
                      ],
                    ),
                  ),
                  backgroundColor: Colors.white,
                  //改变shape这里即可
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20.0),
                      topRight: Radius.circular(20.0),
                    ),
                  ),
                );

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
        */
      ),
      body: SizedBox(
        height: Get.height - 40,
        child: Obx(() => state.loaded.isTrue
            ? FilterListWidget<String>(
          resetButtonText: '置空'.tr,
          applyButtonText: '确认'.tr,
          // hideHeader: true,
          header: TextFieldTags(
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
                    // keyboardType: TextInputType.multiline,
                    // minLines: 1,
                    // maxLines: null,
                    controller: tecController,
                    // focusNode: fn,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: tagSelectedBackgroundColor,
                            width: 1.0),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: tagSelectedBackgroundColor,
                            width: 1.0),
                      ),
                      // helperText: '全部标签'.tr,
                      helperStyle: TextStyle(
                        color: tagSelectedBackgroundColor,
                      ),
                      hintText: state.tagController.hasTags
                          ? ''
                          : '选择或输入标签'.tr,
                      errorText: error,
                      prefixIconConstraints: BoxConstraints(
                          maxWidth: state.distanceToField * 1.0),
                      prefixIcon: tags.isEmpty
                          ? null
                          : SingleChildScrollView(
                        controller: scController,
                        scrollDirection: Axis.horizontal,
                        child: n.Row(tags.map((String tag) {
                          return TagItem(
                            tag: tag,
                            onTagDelete: (String tag) {
                              debugPrint("tag_add_page_onTagDelete $tag");
                              onTagDelete(tag);
                              final state2 = StateProvider.of<FilterState<String>>(
                                  context,
                                  rebuildOnChange: true);
                              state2.removeSelectedItem(tag);
                            },
                            backgroundColor: tagBackgroundColor,
                            selectedBackgroundColor: tagSelectedBackgroundColor,
                          );
                        }).toList()),
                      ),
                    ),
                    onChanged: (String tag) {
                      debugPrint("input_onChanged $tag");
                    },
                    onSubmitted: (String tag) {
                      if (tag.isEmpty) {
                        return;
                      }
                      debugPrint("input_onSubmitted $tag");
                      final state2 =
                      StateProvider.of<FilterState<String>>(
                          context);
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
          ),
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
            List<String>? tag = state.tagController.getTags?.toSet().toList();
            // state.tagController.getTags = tag?.toList();
            // debugPrint("submit_tag ${tag?.length} ${tag.toString()}, ");
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
            return list!.contains(val);
          },
          onReset: () {
            state.tagController.clearTags();

            state.tagController.setError = '需要确认提交，该操作才生效'.tr;
            debugPrint(
                "tag_add_page_onReset ${state.tagController.getTags?.length}");
          },
          onSelected: (String item, bool selected) {
            if (selected) {
              state.tagController.addTag = item;
            } else {
              state.tagController.removeTag = item;
              state.tagItems.value = state.tagController.getTags!;
            }
            // state.tagController.notifyListeners();
            // debugPrint("tag_add_page_onSelected $selected, $item");
          },
        )
            : const SizedBox.shrink()),
      ),
    );
  }
}
