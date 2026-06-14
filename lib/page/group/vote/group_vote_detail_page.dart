import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_vote_service.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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

  @override
  void initState() {
    super.initState();
    _loadVoteDetail();
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

  Widget _buildOptionItem(Map<String, dynamic> option, bool multiple) {
    final optionId = _optionId(option);
    final selected = _selectedOptionIds.contains(optionId);
    final canEdit = _voteStatus == 1;
    final voteCount = _toInt(option['vote_count']);

    if (multiple) {
      return CheckboxListTile(
        value: selected,
        onChanged: canEdit
            ? (value) {
                setState(() {
                  if (value == true) {
                    _selectedOptionIds.add(optionId);
                  } else {
                    _selectedOptionIds.remove(optionId);
                  }
                });
              }
            : null,
        title: Text(_toText(option['option_text'])),
        subtitle: Text(context.t.groupVote.totalVotes(count: voteCount)),
      );
    }

    return CheckboxListTile(
      value: selected,
      onChanged: canEdit
          ? (value) {
              if (value != true) return;
              setState(() {
                _selectedOptionIds = {optionId};
              });
            }
          : null,
      title: Text(_toText(option['option_text'])),
      subtitle: Text(context.t.groupVote.totalVotes(count: voteCount)),
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_toText(_vote!['description']).isNotEmpty)
            Text(_toText(_vote!['description'])),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
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
          const SizedBox(height: 16),
          ...options.map(
            (option) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.small),
              child: _buildOptionItem(option, isMultiple),
            ),
          ),
          const SizedBox(height: 16),
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
          if (_voteStatus == 1) const SizedBox(height: 12),
          if (_voteStatus == 1)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _cancelVote,
                    child: Text(context.t.groupVote.cancelMyVote),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _closeVote,
                    child: Text(context.t.groupVote.voteEnded),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
