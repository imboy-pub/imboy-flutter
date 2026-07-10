import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    setState(() => _isLoading = true);

    final vote = await GroupVoteService.to.getVote(
      groupId: widget.groupId,
      voteId: widget.voteId,
    );
    final myVotes = await GroupVoteService.to.getMyVotes(voteId: widget.voteId);

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.t.groupVote.voteSuccess
              : context.t.common.operationFailedAgainLater,
        ),
      ),
    );

    if (success) {
      await _loadVoteDetail();
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.t.groupVote.cancelVoteSuccess
              : context.t.groupVote.cancelVoteFailed,
        ),
      ),
    );
    if (success) {
      await _loadVoteDetail();
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.t.groupVote.voteEnded
              : context.t.groupVote.endVoteFailed,
        ),
      ),
    );
    if (success) {
      await _loadVoteDetail();
    }
  }

  Widget _buildOptionItem(
    Map<String, dynamic> option,
    bool multiple, {
    required int totalVotes,
  }) {
    final optionId = _optionId(option);
    final selected = _selectedOptionIds.contains(optionId);
    final canEdit = _voteStatus == 1;
    final voteCount = _toInt(option['vote_count']);
    final percent = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = selected
        ? AppColors.getIosBlue(Theme.of(context).brightness)
        : AppColors.iosGray;

    return GestureDetector(
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
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.small),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: AppRadius.borderRadiusRegular,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.5)
                : AppColors.iosGray5.withValues(alpha: isDark ? 0.2 : 1),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选项文本 + 勾选标记 + 票数百分比
            Row(
              children: [
                Icon(
                  selected
                      ? (multiple
                            ? CupertinoIcons.checkmark_square_fill
                            : CupertinoIcons.checkmark_alt_circle_fill)
                      : (multiple
                            ? CupertinoIcons.square
                            : CupertinoIcons.circle),
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    _toText(option['option_text']),
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
                    FontSizeType.footnote,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
            // 进度条
            const SizedBox(height: AppSpacing.small),
            ClipRRect(
              borderRadius: AppRadius.borderRadiusTiny,
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 6,
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: AppSpacing.tiny),
            // 票数文案
            Text(
              context.t.groupVote.totalVotes(count: voteCount),
              style: context.textStyle(
                FontSizeType.caption2,
                color: AppColors.iosGray,
              ),
            ),
          ],
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
      return const Center(child: CircularProgressIndicator());
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

    return RefreshIndicator(
      onRefresh: _loadVoteDetail,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        children: [
          Text(
            _toText(_vote!['title']),
            style: context.textStyle(
              FontSizeType.extraLarge,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          if (_toText(_vote!['description']).isNotEmpty)
            Text(_toText(_vote!['description'])),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: AppSpacing.small,
            children: [
              Chip(
                label: Text(
                  _voteStatus == 1
                      ? context.t.groupVote.statusInProgress
                      : context.t.groupVote.voteEnded,
                ),
              ),
              Chip(
                label: Text(context.t.groupVote.totalVotes(count: totalVotes)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.regular),
          ...options.map(
            (option) =>
                _buildOptionItem(option, isMultiple, totalVotes: totalVotes),
          ),
          const SizedBox(height: AppSpacing.regular),
          if (_voteStatus == 1)
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: (_selectedOptionIds.isEmpty || _isSubmitting)
                    ? null
                    : _submitVote,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _hasVoted
                            ? context.t.groupVote.updateVote
                            : context.t.common.confirm,
                      ),
              ),
            ),
          if (_voteStatus == 1) const SizedBox(height: AppSpacing.medium),
          if (_voteStatus == 1)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _cancelVote,
                    child: Text(context.t.groupVote.cancelMyVote),
                  ),
                ),
                // SR-4：结束投票仅发起人 / 管理员 / 群主可见（隐藏而非报错）
                if (_canCloseVote) ...[
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _closeVote,
                      child: Text(context.t.groupVote.voteEnded),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
