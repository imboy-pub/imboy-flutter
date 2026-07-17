/// 朋友圈「提醒谁看」选人页（纯好友多选，返回 uid→展示名映射）。
///
/// 与 [MomentFriendPickerPage] 的差异：@提醒不涉及可见性/白名单/黑名单语义，
/// 只需从好友里多选若干人。故不复用那套 visibility+tag 组合，另建此轻量页，
/// 沿用相同的好友加载 + 拼音 A-Z 排序 + 搜索 + Checkbox 交互。
///
/// 返回值语义（Navigator.pop）：
///   - null → 取消
///   - `Map<String, String>` → uid → 展示名（title：remark>nickname）
library;

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lpinyin/lpinyin.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class MomentAtPickerPage extends ConsumerStatefulWidget {
  const MomentAtPickerPage({super.key, this.initialUids = const <String>[]});

  /// 已选 uid（再次进入时回填勾选）。
  final List<String> initialUids;

  @override
  ConsumerState<MomentAtPickerPage> createState() => _MomentAtPickerPageState();
}

class _MomentAtPickerPageState extends ConsumerState<MomentAtPickerPage> {
  /// 选中集合（权威状态）。
  Set<String> _picked = <String>{};

  /// 好友原始列表（本地 Repo）。
  List<ContactModel> _friends = const [];

  /// 拼音归一 + A-Z 排序后的可渲染列表（受搜索过滤）。
  List<ContactModel> _displayFriends = const [];

  bool _loading = true;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _picked = {
      for (final uid in widget.initialUids)
        if (uid.trim().isNotEmpty) uid.trim(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFriends());
  }

  Future<void> _loadFriends() async {
    try {
      final list = await ContactRepo().findFriend();
      for (final c in list) {
        final pinyin = PinyinHelper.getPinyinE(c.title);
        c.namePinyin = pinyin;
        if (pinyin.isNotEmpty) {
          final tag = pinyin.substring(0, 1).toUpperCase();
          c.nameIndex = RegExp('[A-Z]').hasMatch(tag) ? tag : '#';
        } else {
          c.nameIndex = '#';
        }
      }
      SuspensionUtil.sortListBySuspensionTag(list);
      SuspensionUtil.setShowSuspensionStatus(list);
      if (!mounted) return;
      setState(() {
        _friends = list;
        _displayFriends = list;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onFriendToggle(ContactModel c) {
    final uid = c.peerId.toString();
    setState(() {
      final next = Set<String>.from(_picked);
      if (!next.remove(uid)) next.add(uid);
      _picked = next;
    });
  }

  void _onSearchChanged(String kwd) {
    final trimmed = kwd.trim().toLowerCase();
    setState(() {
      _keyword = trimmed;
      if (trimmed.isEmpty) {
        _displayFriends = _friends;
      } else {
        _displayFriends = _friends
            .where((c) {
              final title = c.title.toLowerCase();
              final pinyin = (c.namePinyin ?? '').toLowerCase();
              return title.contains(trimmed) || pinyin.contains(trimmed);
            })
            .toList(growable: false);
      }
    });
  }

  void _onConfirm() {
    // uid → 展示名映射：供发布页工具栏摘要同步展示，无需二次 IO。
    final byUid = {for (final c in _friends) c.peerId.toString(): c.title};
    final result = <String, String>{
      for (final uid in _picked) uid: byUid[uid] ?? uid,
    };
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final count = _picked.length;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        title: t.discovery.momentAtWho,
        leading: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.momentNotify.cancel),
        ),
        rightDMActions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _onConfirm,
            child: Text(
              count > 0
                  ? t.momentFriendPicker.confirmWithCount(count: count)
                  : t.momentFriendPicker.confirm,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CupertinoSearchTextField(
              placeholder: t.momentFriendPicker.searchHint,
              onChanged: _onSearchChanged,
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildFriendList()),
        ],
      ),
    );
  }

  Widget _buildFriendList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return Center(
        child: Text(
          t.momentFriendPicker.emptyFriends,
          style: const TextStyle(color: AppColors.iosGray),
        ),
      );
    }
    if (_keyword.isNotEmpty) {
      return ListView.builder(
        itemCount: _displayFriends.length,
        itemBuilder: (_, i) => _buildFriendRow(_displayFriends[i]),
      );
    }
    return AzListView(
      data: _displayFriends,
      itemCount: _displayFriends.length,
      itemBuilder: (_, i) => _buildFriendRow(_displayFriends[i]),
      susItemBuilder: (context, i) {
        final c = _displayFriends[i];
        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.centerLeft,
          child: Text(
            c.getSuspensionTag(),
            style: context.textStyle(
              FontSizeType.small,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendRow(ContactModel c) {
    final uid = c.peerId.toString();
    final checked = _picked.contains(uid);
    return InkWell(
      onTap: () => _onFriendToggle(c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Avatar(imgUri: c.avatar, width: 40, height: 40),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Text(
                c.title,
                style: context.textStyle(FontSizeType.subheadline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Checkbox(
              value: checked,
              onChanged: (_) => _onFriendToggle(c),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
