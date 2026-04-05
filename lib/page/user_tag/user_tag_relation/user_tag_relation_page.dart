import 'dart:async';

import 'package:filter_list/filter_list.dart';

// ignore: implementation_imports
import 'package:filter_list/src/state/filter_state.dart';

// ignore: implementation_imports
import 'package:filter_list/src/state/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/list.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/tag.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:lpinyin/lpinyin.dart'; // 引入 lpinyin

// ignore: implementation_imports
import 'package:textfield_tags/textfield_tags.dart';

import 'user_tag_relation_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 用户标签关联页面
class UserTagRelationPage extends ConsumerStatefulWidget {
  final String peerId; // 用户ID

  final String? title;
  final String scene;

  final String peerTag;
  final Color tagBackgroundColor;
  final Color tagSelectedBackgroundColor;
  final Color tagColor;
  final Color tagSelectedColor;

  const UserTagRelationPage({
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

  @override
  ConsumerState<UserTagRelationPage> createState() =>
      _UserTagRelationPageState();
}

class _UserTagRelationPageState extends ConsumerState<UserTagRelationPage> {
  final TextfieldTagsController _tagController = TextfieldTagsController();
  List<String> _originalTags = [];
  Map<String, int> _tagIdByName = {};
  bool _loaded = false;
  bool _valueChanged = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // 设置当前标签
    final tagItems = normalizeTagNames(widget.peerTag.split(','));
    _originalTags = List<String>.from(tagItems);
    ref.read(userTagRelationProvider.notifier).setTagItems(tagItems);

    final statistics = await ref
        .read(userTagRelationProvider.notifier)
        .getTagStatistics(widget.scene, ensureTags: tagItems);
    final res = List<String>.from(statistics['tags'] ?? const <String>[]);
    _tagIdByName = Map<String, int>.from(statistics['tag_id_by_name'] ?? {});
    // 当前 tag合并到 recentTagItems
    for (var item in tagItems) {
      if (!res.contains(item)) {
        // 排重
        res.add(item);
      }
    }
    ref.read(userTagRelationProvider.notifier).setRecentTagItems(res);

    setState(() {
      _loaded = true;
    });

    _tagController.addListener(() {
      bool diff = listDiff(tagItems, _tagController.getTags);
      ref
          .read(userTagRelationProvider.notifier)
          .setTagItems(_tagController.getTags! as List<String>);
      setState(() {
        _valueChanged = diff;
      });
      if (diff) {
        _tagController.setError = t.needSubmitEffect;
      }
    });
  }

  Widget _buildHeader(BuildContext context) {
    final relationState = ref.watch(userTagRelationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return TextFieldTags(
      textfieldTagsController: _tagController,
      initialTags: relationState.tagItems,
      textSeparators: const [' ', ','],
      letterCase: LetterCase.normal,
      validator: (dynamic tag) {
        bool diff = listDiff(relationState.tagItems, _tagController.getTags);
        setState(() {
          _valueChanged = diff;
        });
        debugPrint(
          "tag_add_view_validator diff $diff, $tag, len:${tag.length}",
        );
        if (tag.length > 14) {
          // 最最最最最最最最最最最最最最1
          return t.upToWords(param: '14');
        }
        if (_tagController.getTags != null &&
            _tagController.getTags!.contains(tag)) {
          // return 'you already entered that';
          return t.alreadyEntered;
        }
        return null;
      },
      inputFieldBuilder:
          (BuildContext context, InputFieldValues<dynamic> inputFieldValues) {
            return Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: AppRadius.borderRadiusMedium,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: TextField(
                controller: inputFieldValues.textEditingController,
                focusNode: inputFieldValues.focusNode,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  helperStyle: TextStyle(
                    color: widget.tagSelectedBackgroundColor,
                  ),
                  hintText: inputFieldValues.tags.isNotEmpty
                      ? ''
                      : t.selectOrEnterTag,
                  hintStyle: TextStyle(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  errorText: inputFieldValues.error,
                  prefixIconConstraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 1.0,
                  ),
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
                                      StateProvider.of<FilterState<String>>(
                                        context,
                                        rebuildOnChange: true,
                                      );
                                  state2.removeSelectedItem(tag);
                                },
                                backgroundColor: isDark
                                    ? colorScheme.surfaceContainerHighest
                                    : widget.tagBackgroundColor,
                                tagSelectedColor: widget.tagSelectedColor,
                                selectedBackgroundColor:
                                    widget.tagSelectedBackgroundColor,
                              );
                            }).toList()),
                          ),
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
                  _tagController.addTag(tag);
                },
              ),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    final relationState = ref.watch(userTagRelationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: widget.title ?? t.addTag,
        automaticallyImplyLeading: true,
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height - 40,
        child: !_loaded
            ? const SizedBox.shrink()
            : FilterListWidget<String>(
                resetButtonText: t.buttonSetEmpty,
                applyButtonText: t.buttonConfirm,
                selectedItemsText: t.selectedItems(param: '').trim(),
                header: _buildHeader(context),
                enableOnlySingleSelection: false,
                listData: relationState.recentTagItems,
                selectedListData: relationState.tagItems,
                controlButtons: const [ControlButtonType.Reset],
                themeData: FilterListThemeData(
                  context,
                  backgroundColor: isDark
                      ? colorScheme.surface
                      : const Color(0xFFF5F5F5),
                  choiceChipTheme: ChoiceChipThemeData(
                    backgroundColor: isDark ? Colors.black12 : Colors.white,
                    selectedBackgroundColor: isDark
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : widget.tagSelectedBackgroundColor,
                    textStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    selectedTextStyle: TextStyle(
                      color: isDark
                          ? AppColors.primary
                          : widget.tagSelectedColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusLarge,
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
                      primaryButtonBackgroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.grey.withValues(alpha: 0.6),
                    ),
                    buttonSpacing: 16,
                    controlContainerDecoration: BoxDecoration(
                      color: isDark ? colorScheme.surface : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  headerTheme: HeaderThemeData(
                    backgroundColor: isDark
                        ? colorScheme.surface
                        : const Color(0xFFF5F5F5),
                  ),
                ),
                onApplyButtonClick: (list) async {
                  final tagItems = normalizeTagNames(list ?? []);
                  ref
                      .read(userTagRelationProvider.notifier)
                      .setTagItems(tagItems);
                  // 更新 tagController
                  List<String> tags =
                      _tagController.getTags?.cast<String>() ?? [];
                  if (tags.isNotEmpty) {
                    for (var tag in tags) {
                      _tagController.onTagRemoved(tag);
                    }
                  }
                  for (var tag in tagItems) {
                    _tagController.addTag(tag);
                  }
                  setState(() {
                    _valueChanged = buildTagSyncPlan(
                      originalTags: _originalTags,
                      nextTags: tagItems,
                    ).hasChanges;
                  });
                  if (_valueChanged) {
                    bool res = await ref
                        .read(userTagRelationProvider.notifier)
                        .syncFinalState(
                          scene: widget.scene,
                          objectId: widget.peerId,
                          originalTags: _originalTags,
                          nextTags: tagItems,
                          tagIdByName: _tagIdByName,
                        );
                    if (res) {
                      Navigator.of(context).pop(tagItems.join(','));
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
                // 支持拼音搜索
                onItemSearch: (item, query) {
                  if (query.isEmpty) {
                    return true;
                  }
                  final lowerQuery = query.toLowerCase();
                  // 1. 匹配原始文本
                  if (item.toLowerCase().contains(lowerQuery)) {
                    return true;
                  }
                  // 2. 匹配拼音全拼
                  String pinyin = PinyinHelper.getPinyinE(
                    item,
                    separator: '',
                    format: PinyinFormat.WITHOUT_TONE,
                  ).toLowerCase();
                  if (pinyin.contains(lowerQuery)) {
                    return true;
                  }
                  // 3. 匹配拼音首字母
                  String shortPinyin = PinyinHelper.getShortPinyin(
                    item,
                  ).toLowerCase();
                  if (shortPinyin.contains(lowerQuery)) {
                    return true;
                  }
                  return false;
                },
              ),
      ),
    );
  }
}
