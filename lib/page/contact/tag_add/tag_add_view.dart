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

  TagAddPage({super.key, required this.peerId, required this.peerTag});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(TagAddLogic());
    final state = Get.find<TagAddLogic>().state;
    state.tagItems.value = peerTag
        .split(',')
        .where((o) => o.trim().isNotEmpty)
        .toList();
    state.tagsController.addListener(() {
      bool diff = listDiff(state.tagItems.value.toList(), state.tagsController.getTags);
      debugPrint("tag_add_view_tagsController_addListener $diff tagItems ${state.tagItems.value.toList().toString()}");
      debugPrint("tag_add_view_tagsController_addListener $diff getTags ${state.tagsController.getTags.toString()}");
      logic.valueOnChange(diff);
    });
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        titleWidget: Row(
          children: [
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
            Obx(
              () => ElevatedButton(
                onPressed: () async {
                  // String trimmedText = logic.remarkTextController.text.trim();
                  // if (trimmedText == '') {
                  //   logic.valueOnChange(false);
                  // } else {
                  //   // bool res = await callback(trimmedText);
                  //   // if (res) {
                  //   //   Get.back();
                  //   // }
                  // }
                },
                // ignore: sort_child_properties_last
                child: Text(
                  'button_accomplish'.tr,
                  textAlign: TextAlign.center,
                ),
                style: logic.valueChanged.isTrue
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
                        padding: MaterialStateProperty.all(EdgeInsets.zero),
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
                        padding: MaterialStateProperty.all(EdgeInsets.zero),
                      ),
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
              Autocomplete<String>(
                optionsViewBuilder: (context, onSelected, options) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 4.0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final dynamic option = options.elementAt(index);
                              return TextButton(
                                onPressed: () {
                                  onSelected(option);
                                },
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15.0),
                                    child: Text(
                                      '#$option',
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        color: AppColors.primaryElement,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return state.tagItems.where((String option) {
                    return option.contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selectedTag) {
                  state.tagsController.addTag = selectedTag;
                },
                fieldViewBuilder: (context, ttec, tfn, onFieldSubmitted) {
                  return TextFieldTags(
                    textEditingController: ttec,
                    focusNode: tfn,
                    textfieldTagsController: state.tagsController,
                    initialTags: state.tagItems,
                    textSeparators: const [' ', ','],
                    // textSeparators: const [','],
                    letterCase: LetterCase.normal,
                    validator: (String tag) {
                      bool diff = listDiff(state.tagItems, state.tagsController.getTags);
                      debugPrint("tag_add_view_validator diff $diff, $tag, len:${tag.length}");
                      logic.valueOnChange(diff);
                      if (tag.length > 14) {
                        // 最最最最最最最最最最最最最最1
                        return '最多14个字'.tr;
                      }
                      return null;
                    },

                    inputfieldBuilder:
                        (context, tecController, fn, error, onChanged, onSubmitted) {
                      return ((context, scController, tags, onTagDelete) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: TextField(
                            controller: tecController,
                            focusNode: fn,
                            decoration: InputDecoration(
                              border: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors.primaryElement,
                                    width: 3.0),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors.primaryElement,
                                    width: 3.0),
                              ),
                              // helperText: '全部标签'.tr,
                              helperStyle: const TextStyle(
                                color: AppColors.primaryElement,
                              ),
                              hintText: state.tagsController.hasTags
                                  ? ''
                                  : '选择或输入标签'.tr,
                              errorText: error,
                              prefixIconConstraints: BoxConstraints(
                                  maxWidth: state.distanceToField * 0.74),
                              prefixIcon: tags.isNotEmpty
                                  ? SingleChildScrollView(
                                      controller: scController,
                                      scrollDirection: Axis.horizontal,
                                      child: n.Row(tags.map((String tag) {
                                        return TagItem(
                                          tag: tag,
                                          onTagDelete: onTagDelete,
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
                  );
                },
              ),
              n.Padding(
                top: 10,
                child: fl.Expander(
                  // leading: fl.RadioButton(
                  //   checked: true,
                  //   onChanged: (v){},
                  // ),
                  header: Text('全部标签'.tr),
                  initiallyExpanded: true,
                  content: n.Column(
                    [
                      fl.SizedBox(
                        width: 110,
                        // height: 48,
                        child: fl.Button(
                          onPressed: () => debugPrint('pressed button'),
                          child: n.Row([
                            n.Padding(
                              top: 4,
                              right: 8,
                              child: n.Icon(Icons.add),
                            ),
                            n.Text('新建标签'.tr),
                          ]),
                        ),
                      ),
                    ],
                    // 内容文本左对齐
                    crossAxisAlignment: CrossAxisAlignment.start,
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
