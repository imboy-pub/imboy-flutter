import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_vote_service.dart';

/// 群投票页面
class GroupVotePage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupVotePage({super.key, required this.groupId});

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

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.groupVote.createVote),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: t.groupVote.voteTitle),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: optionsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t.groupVote.voteOptions,
                hintText: t.groupVote.eachOptionPerLine,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      final options = optionsController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();

      if (options.length >= 2) {
        final vote = await GroupVoteService.to.createVote(
          groupId: widget.groupId,
          title: titleController.text,
          options: options,
        );
        if (vote != null && mounted) {
          _loadVotes(refresh: true);
        }
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createVote,
            tooltip: t.groupVote.createVote,
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
        itemCount: _votes.length,
        itemBuilder: (context, index) {
          final vote = _votes[index];
          return _buildVoteItem(vote);
        },
      ),
    );
  }

  Widget _buildVoteItem(Map<String, dynamic> vote) {
    final status = vote['status'] ?? 0;
    final statusText =
        status == 1 ? t.groupVote.statusInProgress : t.groupVote.voteEnded;
    final statusColor = status == 1 ? Colors.green : Colors.grey;
    final voteId = _resolveVoteId(vote);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          if (voteId.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(
              content: Text(t.groupVote.voteIdMissing),
            ));
            return;
          }
          await context.push(
            '/group/${widget.groupId}/vote/${Uri.encodeComponent(voteId)}',
          );
          if (mounted) {
            _loadVotes(refresh: true);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vote['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.groupVote.participantCount(
                  count: vote['participant_count'] ?? 0,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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
