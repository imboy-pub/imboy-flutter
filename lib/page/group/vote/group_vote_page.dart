import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_vote_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群投票页面
class GroupVotePage extends ConsumerStatefulWidget {
  final String groupId;

  /// 从聊天 + 面板"投票"直达时为 true：进入后自动弹出创建表单（≤2 步）
  final bool autoCreate;

  const GroupVotePage({
    super.key,
    required this.groupId,
    this.autoCreate = false,
  });

  @override
  ConsumerState<GroupVotePage> createState() => _GroupVotePageState();
}

class _GroupVotePageState extends ConsumerState<GroupVotePage> {
  List<Map<String, dynamic>> _votes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVotes();
    if (widget.autoCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _createVote();
      });
    }
  }

  Future<void> _loadVotes({bool refresh = false}) async {
    setState(() => _isLoading = true);

    final votes = await GroupVoteService.to.getVotes(
      groupId: widget.groupId,
      page: 1,
      size: 100,
    );

    if (mounted) {
      setState(() {
        _votes = votes;
        _isLoading = false;
      });
    }
  }

  Future<void> _createVote() async {
    final titleController = TextEditingController();
    final optionsController = TextEditingController();

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.groupVote.createVote),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.small),
            CupertinoTextField(
              controller: titleController,
              placeholder: t.groupVote.voteTitle,
            ),
            const SizedBox(height: AppSpacing.regular),
            CupertinoTextField(
              controller: optionsController,
              maxLines: 4,
              placeholder: t.groupVote.eachOptionPerLine,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      final options = optionsController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();

      // 修复静默失败：选项不足与创建失败此前均无任何提示，用户点确认后
      // 弹窗关闭、列表无变化，完全无从得知原因（真机 QA 坐实）。
      if (options.length < 2) {
        if (mounted) AppLoading.showInfo(t.groupVote.eachOptionPerLine);
        return;
      }
      final vote = await GroupVoteService.to.createVote(
        groupId: widget.groupId,
        title: titleController.text,
        options: options,
      );
      if (!mounted) return;
      if (vote != null) {
        _loadVotes(refresh: true);
      } else {
        AppLoading.showError(
          t.common.networkErrorWithAction(param: t.groupVote.createVote),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupVote.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _createVote,
            child: const Icon(CupertinoIcons.add, size: 22),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _votes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_votes.isEmpty) {
      return NoDataView(
        text: t.groupVote.noVote,
        onTop: () => _loadVotes(refresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadVotes(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        itemCount: _votes.length,
        itemBuilder: (context, index) {
          final vote = _votes[index];
          return _buildVoteItem(vote);
        },
      ),
    );
  }

  Widget _buildVoteItem(Map<String, dynamic> vote) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = vote['status'] ?? 0;
    final isActive = status == 1;
    final statusText = isActive
        ? t.groupVote.statusInProgress
        : t.groupVote.voteEnded;
    final statusColor = isActive
        ? AppColors.getIosGreen(Theme.of(context).brightness)
        : AppColors.iosGray;
    final voteId = _resolveVoteId(vote);

    return GestureDetector(
      onTap: () async {
        if (voteId.isEmpty) {
          AppLoading.showToast(t.groupVote.voteIdMissing);
          return;
        }
        await context.push(
          '/group/${widget.groupId}/vote/${Uri.encodeComponent(voteId)}',
        );
        if (mounted) {
          _loadVotes(refresh: true);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        padding: const EdgeInsets.all(AppSpacing.regular),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: AppRadius.borderRadiusRegular,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 投票图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.iosPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.chart_bar_square_fill,
                    size: 20,
                    color: AppColors.iosPurple,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Text(
                    vote['title'] as String? ?? '',
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.small,
                    vertical: AppSpacing.tiny,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusTiny,
                  ),
                  child: Text(
                    statusText,
                    style: context.textStyle(
                      FontSizeType.caption2,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  t.groupVote.participantCount(
                    count: vote['participant_count'] as Object? ?? 0,
                  ),
                  style: context.textStyle(
                    FontSizeType.caption2,
                    color: AppColors.iosGray,
                  ),
                ),
                const SizedBox(width: AppSpacing.tiny),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.iosGray3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resolveVoteId(Map<String, dynamic> vote) {
    final voteId = vote['vote_id']?.toString().trim() ?? '';
    if (voteId.isNotEmpty) return voteId;
    return vote['id']?.toString().trim() ?? '';
  }
}
