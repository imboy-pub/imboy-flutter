import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart' show isGroupAdmin;
import 'package:imboy/service/group_vote_service.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群投票详情页
class GroupVoteDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final String voteId;

  const GroupVoteDetailPage({
    super.key,
    required this.groupId,
    required this.voteId,
  });

  @override
  ConsumerState<GroupVoteDetailPage> createState() =>
      _GroupVoteDetailPageState();
}

class _GroupVoteDetailPageState extends ConsumerState<GroupVoteDetailPage> {
  Map<String, dynamic>? _vote;
  Set<String> _selectedOptionIds = <String>{};
  bool _hasVoted = false;
  bool _isLoading = true;

  /// 加载失败标记：与"投票不存在/已删除"区分，两者文案不同。
  bool _loadFailed = false;
  bool _isSubmitting = false;

  /// 当前登录用户在本群的角色（0 = 未加载 / 不在群），安全默认无管理权限。
  int _currentUserRole = 0;

  @override
  void initState() {
    super.initState();
    _loadVoteDetail();
    unawaited(_loadCurrentRole());
  }

  /// 异步加载当前用户在本群的角色（SR-4：结束投票需按角色收窄）。
  /// 失败时静默回退，保持 0（安全默认：无管理权限）。
  Future<void> _loadCurrentRole() async {
    try {
      final uid = UserRepoLocal.to.currentUid;
      final member = await GroupMemberRepo().findByUserId(widget.groupId, uid);
      if (mounted && member != null) {
        setState(() => _currentUserRole = member.role);
      }
    } catch (_) {
      // 静默失败：保持 _currentUserRole=0，UI 不显示管理操作
    }
  }

  /// SR-4：结束投票仅发起人 / 管理员 / 群主可见可点。
  bool get _canCloseVote {
    if (isGroupAdmin(_currentUserRole)) return true;
    final creatorId = _toText(_vote?['creator_id']);
    return creatorId.isNotEmpty && creatorId == UserRepoLocal.to.currentUid;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _toText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _optionId(Map<String, dynamic> option) {
    final optionId = _toText(option['option_id']);
    if (optionId.isNotEmpty) return optionId;
    return _toText(option['id']);
  }

  Future<void> _loadVoteDetail() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    final Map<String, dynamic>? vote;
    final List<Map<String, dynamic>> myVotes;
    try {
      vote = await GroupVoteService.to.getVote(
        groupId: widget.groupId,
        voteId: widget.voteId,
      );
      myVotes = await GroupVoteService.to.getMyVotes(
        voteId: widget.voteId,
        numericVoteId: vote?['id'],
      );
    } catch (e) {
      // myVotes 失败绝不能降级成空列表：那等于告诉用户"你还没投票"，
      // 已投票的人会看到可投票界面并重复提交。
      iPrint('GroupVoteDetailPage: 加载投票详情失败 - $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
      return;
    }

    if (!mounted) return;

    final selected = <String>{};
    if (myVotes.isNotEmpty) {
      final first = myVotes.first;
      final optionIdsRaw = first['option_ids'];
      if (optionIdsRaw is List) {
        for (final id in optionIdsRaw) {
          final text = _toText(id);
          if (text.isNotEmpty) selected.add(text);
        }
      }
    }

    setState(() {
      _vote = vote;
      _selectedOptionIds = selected;
      _hasVoted = selected.isNotEmpty;
      _isLoading = false;
    });
  }

  Future<void> _submitVote() async {
    if (_selectedOptionIds.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final success = _hasVoted
        ? await GroupVoteService.to.updateVote(
            groupId: widget.groupId,
            voteId: widget.voteId,
            optionIds: _selectedOptionIds.toList(),
          )
        : await GroupVoteService.to.castVote(
            groupId: widget.groupId,
            voteId: widget.voteId,
            optionIds: _selectedOptionIds.toList(),
          );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      AppLoading.showToast(context.t.groupVote.voteSuccess);
      await _loadVoteDetail();
    }
    // 失败分支不再叠兜底文案：后端中文原因已由 GroupVoteApi 透出
  }

  Future<void> _cancelVote() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final success = await GroupVoteService.to.cancelVote(
      groupId: widget.groupId,
      voteId: widget.voteId,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      AppLoading.showToast(context.t.groupVote.cancelVoteSuccess);
      await _loadVoteDetail();
    }
    // 失败分支不再叠兜底文案：后端中文原因已由 GroupVoteApi 透出
  }

  Future<void> _closeVote() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final success = await GroupVoteService.to.closeVote(
      groupId: widget.groupId,
      voteId: widget.voteId,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      AppLoading.showToast(context.t.groupVote.voteEnded);
      await _loadVoteDetail();
    }
    // 失败分支不再叠兜底文案：后端中文原因已由 GroupVoteApi 透出
  }

  /// 选项合并为一张 InsetGrouped 卡片（iOS 原生质感），行间细分隔线
  Widget _buildOptionsCard(
    List<Map<String, dynamic>> options,
    bool multiple, {
    required int totalVotes,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: AppColors.iosGray5.withValues(alpha: isDark ? 0.2 : 1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0)
              // 分隔线与选项文本左对齐（内边距16 + 图标22 + 间距10）
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 48),
                color: isDark ? AppColors.iosSeparatorDark : AppColors.iosGray5,
              ),
            _buildOptionRow(options[i], multiple, totalVotes: totalVotes),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionRow(
    Map<String, dynamic> option,
    bool multiple, {
    required int totalVotes,
  }) {
    final optionId = _optionId(option);
    final selected = _selectedOptionIds.contains(optionId);
    final canEdit = _voteStatus == 1;
    final voteCount = _toInt(option['vote_count']);
    final percent = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accent = AppColors.getIosBlue(brightness);
    final optionText = _toText(option['option_text']);

    return Semantics(
      selected: selected,
      enabled: canEdit,
      button: canEdit,
      label:
          '$optionText ${(percent * 100).toInt()}%，'
          '${context.t.groupVote.voteCount(count: voteCount)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canEdit
            ? () {
                setState(() {
                  if (multiple) {
                    if (selected) {
                      _selectedOptionIds.remove(optionId);
                    } else {
                      _selectedOptionIds.add(optionId);
                    }
                  } else {
                    _selectedOptionIds = {optionId};
                  }
                });
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 选项文本 + 勾选标记 + 得票占比
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      selected
                          ? (multiple
                                ? CupertinoIcons.checkmark_square_fill
                                : CupertinoIcons.checkmark_alt_circle_fill)
                          : (multiple
                                ? CupertinoIcons.square
                                : CupertinoIcons.circle),
                      key: ValueKey('$optionId-$selected'),
                      color: selected ? accent : AppColors.iosGray3,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Text(
                      optionText,
                      style: context.textStyle(
                        FontSizeType.body,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Text(
                    '${(percent * 100).toInt()}%',
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: FontWeight.w600,
                      color: selected ? accent : AppColors.iosGray,
                    ),
                  ),
                ],
              ),
              // 进度条与票数同行（对齐选项文本起点），压紧行高
              const SizedBox(height: AppSpacing.small),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.borderRadiusTiny,
                        child: Container(
                          height: 4,
                          color: isDark
                              ? AppColors.overlayWhite10
                              : AppColors.iosGray5,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percent.clamp(0.0, 1.0),
                            child: Container(
                              color: selected
                                  ? accent
                                  : accent.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Text(
                      context.t.groupVote.voteCount(count: voteCount),
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _voteStatus => _toInt(_vote?['status']);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupVote.title,
        automaticallyImplyLeading: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_loadFailed) {
      return NoDataView(
        text: context.t.common.loadError,
        icon: CupertinoIcons.cloud_bolt,
        onTop: _loadVoteDetail,
      );
    }

    if (_vote == null) {
      return NoDataView(
        text: context.t.groupVote.noVote,
        onTop: _loadVoteDetail,
      );
    }

    final options = _toMapList(_vote!['options']);
    final voteType = _toInt(_vote!['vote_type']);
    final isMultiple = voteType == 2;
    final totalVotes = _toInt(_vote!['total_votes']);

    // 宽屏（桌面端）下内容居中限宽，避免卡片被拉满整窗
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _loadVoteDetail),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.large,
                AppSpacing.regular,
                AppSpacing.large,
                AppSpacing.xxxLarge,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(isMultiple, totalVotes),
                  const SizedBox(height: AppSpacing.regular),
                  _buildOptionsCard(
                    options,
                    isMultiple,
                    totalVotes: totalVotes,
                  ),
                  if (_voteStatus == 1) ...[
                    const SizedBox(height: AppSpacing.xLarge),
                    ..._buildVoteActions(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 头部信息区：标题 + 描述 + 一行克制的元信息（状态点 + 状态/类型/票数/已投票）
  /// 行业标杆（微信/Telegram）均用安静的元信息行而非彩色标签堆砌
  Widget _buildHeader(bool isMultiple, int totalVotes) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final active = _voteStatus == 1;
    final description = _toText(_vote!['description']);
    final statusColor = active
        ? AppColors.getIosGreen(brightness)
        : AppColors.iosGray;
    final secondaryStyle = context.textStyle(
      FontSizeType.footnote,
      color: AppColors.getTextSecondary(brightness),
    );
    Widget dot() => Text(
      '·',
      style: context.textStyle(
        FontSizeType.footnote,
        fontWeight: FontWeight.w600,
        color: AppColors.getTextSecondary(brightness),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _toText(_vote!['title']),
          style: context.textStyle(
            FontSizeType.title,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.tiny),
          Text(
            description,
            style: context.textStyle(
              FontSizeType.normal,
              color: AppColors.getTextSecondary(brightness),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.small),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.tiny,
          runSpacing: AppSpacing.tiny,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.tiny),
            Text(
              active ? t.groupVote.statusInProgress : t.groupVote.voteEnded,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            dot(),
            Text(
              isMultiple
                  ? t.groupVote.multipleChoice
                  : t.groupVote.singleChoice,
              style: secondaryStyle,
            ),
            dot(),
            Text(
              t.groupVote.totalVotes(count: totalVotes),
              style: secondaryStyle,
            ),
            if (_hasVoted) ...[
              dot(),
              Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                size: 13,
                color: AppColors.getIosBlue(brightness),
              ),
              const SizedBox(width: AppSpacing.tiny),
              Text(
                t.groupVote.alreadyVoted,
                style: context.textStyle(
                  FontSizeType.footnote,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getIosBlue(brightness),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 投票操作区：已选提示 + 主按钮（品牌蓝，禁用态淡化）+ 次要操作
  List<Widget> _buildVoteActions() {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.getIosBlue(brightness);
    final surface = brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceContainer;
    final selectedCount = _selectedOptionIds.length;
    final canSubmit = selectedCount > 0 && !_isSubmitting;

    return [
      if (selectedCount > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.small),
          child: Text(
            t.groupVote.selectedCount(count: selectedCount),
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w500,
              color: accent,
            ),
          ),
        ),
      // 主按钮：禁用态用品牌蓝 40% 淡化（微信式），而非灰色板
      CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 50),
        borderRadius: AppRadius.borderRadiusMedium,
        color: accent,
        disabledColor: accent.withValues(alpha: 0.4),
        onPressed: canSubmit ? _submitVote : null,
        child: _isSubmitting
            ? const CupertinoActivityIndicator(color: AppColors.onPrimary)
            : Text(
                _hasVoted ? t.groupVote.updateVote : t.common.confirm,
                style: TextStyle(
                  fontSize: FontSizeType.body.size,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimary,
                ),
              ),
      ),
      if (_hasVoted) ...[
        const SizedBox(height: AppSpacing.medium),
        Row(
          children: [
            // 已投票才有"取消"可言；非管理员时单独占满整行
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: AppRadius.borderRadiusMedium,
                color: surface,
                onPressed: _isSubmitting ? null : _cancelVote,
                child: Text(
                  t.groupVote.cancelMyVote,
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ),
            ),
            // SR-4：结束投票仅发起人 / 管理员 / 群主可见（隐藏而非报错）
            if (_canCloseVote) ...[
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: AppRadius.borderRadiusMedium,
                  color: surface,
                  onPressed: _isSubmitting ? null : _closeVote,
                  child: Text(
                    t.groupVote.endVote,
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getIosRed(brightness),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ] else if (_canCloseVote) ...[
        // 未投票时结束投票降级为居中的次要文字操作，不与主按钮抢视觉
        const SizedBox(height: AppSpacing.small),
        Center(
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.small,
            ),
            onPressed: _isSubmitting ? null : _closeVote,
            child: Text(
              t.groupVote.endVote,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.getIosRed(brightness),
              ),
            ),
          ),
        ),
      ],
    ];
  }
}
