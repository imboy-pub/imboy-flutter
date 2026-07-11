/// 朋友圈可见性 + 好友选择器单页（P1-1：可见性单页化）。
///
/// - 顶部：可见性五选一（公开/仅好友/仅自己/部分可见/不给谁看）
/// - 命中「部分可见」/「不给谁看」时，同页展开：
///   - 按标签联动区（横滑 Chip；标签 uids 懒加载）
///   - 好友列表（拼音排序 + Checkbox）
/// - 底部：确定按钮（展示已选人数）
///
/// 返回值语义：Navigator.pop
///   - null → 取消
///   - [MomentVisibilityResult] → 用户确认后的可见性 + 允许/排除名单
///
/// 决策逻辑委托 `friend_picker_rules.dart` 纯函数，本 widget 只做：
///   数据加载 + UI 渲染 + 状态持有。
library;

import 'package:azlistview/azlistview.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lpinyin/lpinyin.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_friend_picker/friend_picker_rules.dart';
import 'package:imboy/page/moment/moment_interactions.dart';
import 'package:imboy/store/api/user_tag_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 单页确认后的结果：可见性 code + 允许/排除名单。
class MomentVisibilityResult {
  const MomentVisibilityResult({
    required this.visibility,
    required this.allowUids,
    required this.denyUids,
  });

  final int visibility;
  final List<String> allowUids;
  final List<String> denyUids;
}

/// 朋友圈选择器一次性拉取的标签数量上限。
///
/// 用户标签总数通常 < 50，取 200 留出成长空间同时避免分页 UI。
/// 后端 `user_tag/page` 接口若超限会截断返回，不会报错。
const int kFriendPickerTagPageSize = 200;

/// 单个标签下一次性展开的好友数量上限（`pageRelation`）。
///
/// 经验值：绝大多数标签成员数远小于 1000；
/// 超出的场景应由 UI 升级成二级分页而非在此盲目放大。
const int kFriendPickerTagUidsPageSize = 1000;

/// 单个标签在 UI 中的本地快照（含懒加载状态）。
class _PickerTagEntry {
  _PickerTagEntry({required this.tag});

  final UserTagModel tag;

  /// null = 未加载；非 null = 已加载（可能是空列表）。
  List<String>? uids;

  bool loading = false;
}

class MomentFriendPickerPage extends ConsumerStatefulWidget {
  const MomentFriendPickerPage({
    super.key,
    this.title,
    this.initialVisibility = momentVisibilityFriends,
    this.initialAllowUids = const <String>[],
    this.initialDenyUids = const <String>[],
  });

  /// 页面标题（为空时用 `momentFriendPicker.title`）。
  final String? title;

  /// 调用方传入的初始可见性。
  final int initialVisibility;

  /// 调用方传入的初始「部分可见」白名单。
  final List<String> initialAllowUids;

  /// 调用方传入的初始「不给谁看」黑名单。
  final List<String> initialDenyUids;

  @override
  ConsumerState<MomentFriendPickerPage> createState() =>
      _MomentFriendPickerPageState();
}

class _MomentFriendPickerPageState
    extends ConsumerState<MomentFriendPickerPage> {
  /// 当前选中的可见性。
  late int _visibility;

  /// 「部分可见」白名单选中集合（权威状态）。
  Set<String> _allowPicked = <String>{};

  /// 「不给谁看」黑名单选中集合（权威状态）。
  Set<String> _denyPicked = <String>{};

  /// 当前可见性下生效的选中集合（部分可见/不给谁看之外为空集）。
  Set<String> get _activePicked {
    if (momentVisibilityRequiresAllowUids(_visibility)) return _allowPicked;
    if (momentVisibilityRequiresDenyUids(_visibility)) return _denyPicked;
    return const <String>{};
  }

  set _activePicked(Set<String> next) {
    if (momentVisibilityRequiresAllowUids(_visibility)) {
      _allowPicked = next;
    } else if (momentVisibilityRequiresDenyUids(_visibility)) {
      _denyPicked = next;
    }
  }

  /// 当前可见性是否需要展开好友名单区。
  bool get _needsFriendList => momentVisibilityNeedsFriendList(_visibility);

  /// 好友原始列表（从本地 Repo 加载）。
  List<ContactModel> _friends = const [];

  /// 经拼音归一 + A-Z 排序后的可渲染列表。
  List<ContactModel> _displayFriends = const [];

  /// 标签快照列表。
  List<_PickerTagEntry> _tags = const [];

  bool _loadingFriends = true;
  bool _loadingTags = true;

  /// 是否已发起过好友+标签加载（名单模式首次进入时才置位，避免重复拉取）。
  bool _friendListRequested = false;

  /// 搜索关键词（本地过滤，不走 API）。
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _visibility = widget.initialVisibility;
    _allowPicked = {
      for (final uid in widget.initialAllowUids)
        if (uid.trim().isNotEmpty) uid.trim(),
    };
    _denyPicked = {
      for (final uid in widget.initialDenyUids)
        if (uid.trim().isNotEmpty) uid.trim(),
    };
    // 仅名单模式（部分可见/不给谁看）才拉好友+标签；简单态进入时不触发网络。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_needsFriendList) _ensureFriendListLoaded();
    });
  }

  /// 名单模式首次进入时才拉好友(本地)+标签(网络)，避免简单态误触发。
  void _ensureFriendListLoaded() {
    if (_friendListRequested) return;
    _friendListRequested = true;
    _loadFriends();
    _loadTags();
  }

  Future<void> _loadFriends() async {
    try {
      final list = await ContactRepo().findFriend();
      // 归一化拼音首字母，复用 select_friend.dart 的模式。
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
        _loadingFriends = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadTags() async {
    try {
      final resp = await UserTagApi().page(
        page: 1,
        size: kFriendPickerTagPageSize,
        scene: 'friend',
      );
      final items = <_PickerTagEntry>[];
      final list = resp?['list'];
      if (list is List) {
        for (final json in list) {
          if (json is! Map) continue;
          final model = UserTagModel.fromJson(Map<String, dynamic>.from(json));
          if (model.tagId > 0 && model.name.trim().isNotEmpty) {
            items.add(_PickerTagEntry(tag: model));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _tags = items;
        _loadingTags = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _loadingTags = false);
    }
  }

  Future<List<String>?> _ensureTagUids(_PickerTagEntry entry) async {
    if (entry.uids != null) return entry.uids;
    if (entry.loading) return null;
    setState(() => entry.loading = true);
    try {
      final resp = await UserTagApi().pageRelation(
        page: 1,
        size: kFriendPickerTagUidsPageSize,
        tagId: entry.tag.tagId,
        scene: 'friend',
      );
      final list = resp?['list'];
      final uids = <String>[];
      if (list is List) {
        for (final json in list) {
          if (json is! Map) continue;
          final uid = json['user_id']?.toString() ?? '';
          if (uid.trim().isNotEmpty) {
            uids.add(uid.trim());
          }
        }
      }
      entry.uids = uids;
      entry.loading = false;
      if (mounted) setState(() {});
      return uids;
    } on Exception {
      entry.loading = false;
      if (mounted) {
        AppLoading.showToast(t.momentFriendPicker.tagLoadFailed);
        setState(() {});
      }
      return null;
    }
  }

  Future<void> _onTagTap(_PickerTagEntry entry) async {
    final uids = await _ensureTagUids(entry);
    if (uids == null || uids.isEmpty) return;
    final currentState = resolveTagSelectionState(_activePicked, uids);
    // all → 取消全选；否则（none / partial）→ 全选
    final select = currentState != TagSelectionState.all;
    setState(() {
      _activePicked = applyTagToggle(_activePicked, uids, select: select);
    });
  }

  void _onFriendToggle(ContactModel c) {
    setState(() {
      _activePicked = togglePickedUid(_activePicked, c.peerId.toString());
    });
  }

  void _onVisibilitySelected(int code) {
    setState(() => _visibility = code);
    // 页内切换到名单模式时惰性加载（若尚未加载），避免停在空列表。
    if (momentVisibilityNeedsFriendList(code)) _ensureFriendListLoaded();
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
    final result = MomentVisibilityResult(
      visibility: _visibility,
      allowUids: sortUidsForPayload(_allowPicked),
      denyUids: sortUidsForPayload(_denyPicked),
    );
    Navigator.of(context).pop(result);
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? t.discovery.momentsVisibility;
    final count = _activePicked.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        title: title,
        leading: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onPressed: _onCancel,
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
          _buildVisibilitySection(),
          const Divider(height: 1),
          if (_needsFriendList) ...[
            _buildSearchBar(),
            _buildTagsRow(),
            const Divider(height: 1),
            Expanded(child: _buildFriendList()),
            _buildSelectedBar(count),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  /// 可见性五选一（单页化核心：不再单独跳转 ActionSheet）。
  Widget _buildVisibilitySection() {
    final options = <(int, String)>[
      (momentVisibilityPublic, t.discovery.momentsVisibilityPublic),
      (momentVisibilityFriends, t.contact.momentsVisibilityFriends),
      (momentVisibilityPrivate, t.chat.momentsVisibilityPrivate),
      (momentVisibilityAllowList, t.discovery.momentsVisibilityPartial),
      (momentVisibilityDenyList, t.discovery.momentsVisibilityExclude),
    ];
    return Column(
      children: options
          .map((o) => _buildVisibilityRow(code: o.$1, label: o.$2))
          .toList(),
    );
  }

  Widget _buildVisibilityRow({required int code, required String label}) {
    final selected = _visibility == code;
    return InkWell(
      onTap: () => _onVisibilitySelected(code),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 20,
              color: selected ? AppColors.primary : AppColors.iosGray3,
            ),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Text(
                label,
                style: context.textStyle(FontSizeType.subheadline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: CupertinoSearchTextField(
        placeholder: t.momentFriendPicker.searchHint,
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildTagsRow() {
    if (_loadingTags) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _tags.length,
        separatorBuilder: (_, _) => AppSpacing.horizontalSmall,
        itemBuilder: (context, i) => _buildTagChip(_tags[i]),
      ),
    );
  }

  Widget _buildTagChip(_PickerTagEntry entry) {
    final uids = entry.uids;
    final state = uids == null
        ? TagSelectionState.none
        : resolveTagSelectionState(_activePicked, uids);
    final theme = Theme.of(context);
    final selected = state == TagSelectionState.all;
    final partial = state == TagSelectionState.partial;
    final bg = selected
        ? theme.colorScheme.primary
        : partial
        ? theme.colorScheme.primary.withValues(alpha: 0.25)
        : theme.colorScheme.surfaceContainerHighest;
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: AppRadius.borderRadiusRegular,
      onTap: entry.loading ? null : () => _onTagTap(entry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderRadiusRegular,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.loading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: fg),
              )
            else
              Icon(
                selected
                    ? Icons.check_circle
                    : partial
                    ? Icons.remove_circle
                    : Icons.circle_outlined,
                size: 14,
                color: fg,
              ),
            AppSpacing.horizontalTiny,
            Text(
              entry.tag.name,
              style: context.textStyle(
                FontSizeType.footnote,
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendList() {
    if (_loadingFriends) {
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
    // 搜索模式下不展示 A-Z 悬停标签（列表已被截断，悬停无意义）。
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
    final checked = _activePicked.contains(uid);
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

  Widget _buildSelectedBar(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Text(
          t.momentFriendPicker.selectedCount(count: count),
          style: context.textStyle(
            FontSizeType.footnote,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
