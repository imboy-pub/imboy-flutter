import 'dart:async';

import 'package:filter_list/filter_list.dart';
// ignore: implementation_imports
import 'package:filter_list/src/state/filter_state.dart';
// ignore: implementation_imports
import 'package:filter_list/src/state/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/list.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/tag.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:lpinyin/lpinyin.dart';
// ignore: implementation_imports
import 'package:textfield_tags/textfield_tags.dart';

import 'user_tag_relation_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 用户标签关联页面 - 像素级对齐 iOS 17 Premium 风格
class UserTagRelationPage extends ConsumerStatefulWidget {
  final String peerId;
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
  ConsumerState<UserTagRelationPage> createState() => _UserTagRelationPageState();
}

class _UserTagRelationPageState extends ConsumerState<UserTagRelationPage> {
  final TextfieldTagsController<dynamic> _tagController = TextfieldTagsController<dynamic>();
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
    final tagItems = normalizeTagNames(widget.peerTag.split(','));
    _originalTags = List<String>.from(tagItems);
    ref.read(userTagRelationProvider.notifier).setTagItems(tagItems);

    final statistics = await ref.read(userTagRelationProvider.notifier).getTagStatistics(widget.scene, ensureTags: tagItems);
    final res = List<String>.from((statistics['tags'] ?? const <dynamic>[]) as Iterable<dynamic>);
    _tagIdByName = Map<String, int>.from((statistics['tag_id_by_name'] ?? const <dynamic, dynamic>{}) as Map<dynamic, dynamic>);
    
    for (var item in tagItems) { if (!res.contains(item)) res.add(item); }
    ref.read(userTagRelationProvider.notifier).setRecentTagItems(res);

    setState(() { _loaded = true; });

    _tagController.addListener(() {
      bool diff = listDiff(tagItems, _tagController.getTags);
      ref.read(userTagRelationProvider.notifier).setTagItems(_tagController.getTags! as List<String>);
      setState(() { _valueChanged = diff; });
    });
  }

  Widget _buildTagInput(BuildContext context) {
    final relationState = ref.watch(userTagRelationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFieldTags(
      textfieldTagsController: _tagController,
      initialTags: relationState.tagItems,
      textSeparators: const [' ', ','],
      letterCase: LetterCase.normal,
      validator: (dynamic tag) {
        if ((tag.length as int) > 14) return t.main.upToWords(param: '14');
        if (_tagController.getTags != null && _tagController.getTags!.contains(tag)) return t.chat.alreadyEntered;
        return null;
      },
      inputFieldBuilder: (BuildContext context, InputFieldValues<dynamic> inputFieldValues) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: inputFieldValues.textEditingController,
            focusNode: inputFieldValues.focusNode,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: inputFieldValues.tags.isNotEmpty ? '' : t.contact.selectOrEnterTag,
              hintStyle: const TextStyle(color: AppColors.iosGray, fontSize: 16),
              errorText: inputFieldValues.error,
              prefixIcon: inputFieldValues.tags.isEmpty ? null : Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Wrap(
                  spacing: 4, runSpacing: 4,
                  children: inputFieldValues.tags.map((dynamic tag) => TagItem(tag: tag as String, onTagDelete: (String tag) { inputFieldValues.onTagRemoved(tag); StateProvider.of<FilterState<String>>(context, rebuildOnChange: true).removeSelectedItem(tag); }, backgroundColor: isDark ? Colors.white10 : widget.tagBackgroundColor, tagSelectedColor: widget.tagSelectedColor, selectedBackgroundColor: widget.tagSelectedBackgroundColor)).toList(),
                ),
              ),
            ),
            onSubmitted: (String tag) {
              if (tag.isEmpty || tag.length > 14) return;
              StateProvider.of<FilterState<String>>(context).addSelectedItem(tag);
              final s2 = StateProvider.of<FilterState<String>>(context);
              if (s2.items != null && !s2.items!.contains(tag)) { s2.items = List.from(s2.items!)..add(tag); }
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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: widget.title ?? t.common.addTag,
      useLargeTitle: false,
      child: !_loaded ? const SizedBox.shrink() : SizedBox(
        height: MediaQuery.of(context).size.height - 120,
        child: FilterListWidget<String>(
          resetButtonText: t.common.buttonSetEmpty,
          applyButtonText: t.common.buttonConfirm,
          selectedItemsText: t.common.selectedItems(param: '').trim(),
          header: _buildTagInput(context),
          enableOnlySingleSelection: false,
          listData: relationState.recentTagItems,
          selectedListData: relationState.tagItems,
          controlButtons: const [ControlButtonType.Reset],
          themeData: FilterListThemeData(
            context,
            backgroundColor: Colors.transparent,
            choiceChipTheme: ChoiceChipThemeData(
              backgroundColor: isDark ? Colors.white10 : Colors.white,
              selectedBackgroundColor: AppColors.getIosBlue(brightness).withValues(alpha: 0.1),
              textStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              selectedTextStyle: TextStyle(color: AppColors.getIosBlue(brightness), fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1))),
            ),
            controlButtonBarTheme: ControlButtonBarThemeData.raw(
              controlButtonTheme: ControlButtonThemeData(borderRadius: 12, primaryButtonTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), primaryButtonBackgroundColor: AppColors.primary, textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), backgroundColor: AppColors.iosGray),
              buttonSpacing: 16,
              controlContainerDecoration: BoxDecoration(color: isDark ? AppColors.darkSurface : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            headerTheme: HeaderThemeData(backgroundColor: Colors.transparent),
          ),
          onApplyButtonClick: (list) async {
            final tagItems = normalizeTagNames(list ?? []);
            ref.read(userTagRelationProvider.notifier).setTagItems(tagItems);
            List<String> tags = _tagController.getTags?.cast<String>() ?? [];
            for (var t in tags) _tagController.onTagRemoved(t);
            for (var t in tagItems) _tagController.addTag(t);
            if (buildTagSyncPlan(originalTags: _originalTags, nextTags: tagItems).hasChanges) {
              if (await ref.read(userTagRelationProvider.notifier).syncFinalState(scene: widget.scene, objectId: widget.peerId, originalTags: _originalTags, nextTags: tagItems, tagIdByName: _tagIdByName)) {
                Navigator.of(context).pop(tagItems.join(','));
              }
            }
          },
          choiceChipLabel: (item) => item,
          validateSelectedItem: (list, val) => list!.contains(val),
          onItemSearch: (item, query) {
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            if (item.toLowerCase().contains(q)) return true;
            if (PinyinHelper.getPinyinE(item, separator: '', format: PinyinFormat.WITHOUT_TONE).toLowerCase().contains(q)) return true;
            if (PinyinHelper.getShortPinyin(item).toLowerCase().contains(q)) return true;
            return false;
          },
        ),
      ),
    );
  }
}
