import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/mention_service.dart';
import 'package:imboy/i18n/strings.g.dart';

/// @提及列表页面
class MentionListPage extends ConsumerStatefulWidget {
  final String? groupId;

  const MentionListPage({super.key, this.groupId});

  @override
  ConsumerState<MentionListPage> createState() => _MentionListPageState();
}

class _MentionListPageState extends ConsumerState<MentionListPage> {
  List<Map<String, dynamic>> _mentions = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;
  StreamSubscription? _mentionSub;

  @override
  void initState() {
    super.initState();
    _loadMentions();
    _loadUnreadCount();
    _mentionSub = AppEventBus.on<NewMentionEvent>().listen((_) {
      _loadMentions(refresh: true);
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _mentionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMentions({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    setState(() => _isLoading = true);

    final result = await MentionService.to.getMentions(
      page: _page,
      size: 20,
      groupId: widget.groupId,
    );

    if (mounted) {
      setState(() {
        if (result != null) {
          final items = result['items'] as List? ?? [];
          if (refresh) {
            _mentions = items.cast<Map<String, dynamic>>();
          } else {
            _mentions.addAll(items.cast<Map<String, dynamic>>());
          }
          _hasMore = items.length >= 20;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    final count = await MentionService.to.getUnreadCount(
      groupId: widget.groupId,
    );
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  Future<void> _markAsRead(int mentionId) async {
    await MentionService.to.markAsRead(mentionId);
    _loadUnreadCount();
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

  String _resolveGroupId(Map<String, dynamic> mention) {
    final fromGroupId = _toText(mention['group_id']);
    if (fromGroupId.isNotEmpty) return fromGroupId;
    return _toText(mention['gid']);
  }

  String _resolveMessageId(Map<String, dynamic> mention) {
    final msgId = _toText(mention['msg_id']);
    if (msgId.isNotEmpty) return msgId;
    return _toText(mention['message_id']);
  }

  Future<void> _openMention(Map<String, dynamic> mention, bool isRead) async {
    final mentionId = _toInt(mention['id']);
    final groupId = _resolveGroupId(mention);
    final msgId = _resolveMessageId(mention);

    if (!isRead && mentionId > 0) {
      await _markAsRead(mentionId);
    }

    if (groupId.isEmpty || msgId.isEmpty || !mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.mention.navInfoMissing)));
      return;
    }

    final encodedMsgId = Uri.encodeQueryComponent(msgId);
    context.push('/chat/$groupId?type=C2G&msg_id=$encodedMsgId');
  }

  Future<void> _markAllAsRead() async {
    await MentionService.to.markAllAsRead(groupId: widget.groupId);
    _loadMentions(refresh: true);
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.mention.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(t.mention.allRead),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _mentions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mentions.isEmpty) {
      return NoDataView(
        text: t.mention.noMention,
        onTop: () => _loadMentions(refresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMentions(refresh: true),
      child: ListView.builder(
        itemCount: _mentions.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _mentions.length) {
            if (!_isLoading) {
              _page++;
              _loadMentions();
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final mention = _mentions[index];
          return _buildMentionItem(mention);
        },
      ),
    );
  }

  Widget _buildMentionItem(Map<String, dynamic> mention) {
    final isRead = mention['is_read'] == 1;

    return ListTile(
      leading: Stack(
        children: [
          Avatar(imgUri: mention['avatar'] ?? '', width: 48, height: 48),
          if (!isRead)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        mention['nickname'] ?? '',
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        mention['content'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(mention['created_at']),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () async {
        await _openMention(mention, isRead);
      },
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      timestamp is int ? timestamp : int.parse(timestamp.toString()) * 1000,
    );
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 7) {
      return '${dt.month}/${dt.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
