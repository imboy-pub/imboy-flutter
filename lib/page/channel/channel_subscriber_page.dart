import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/channel_api.dart';

/// 订阅者信息模型
class SubscriberInfo {
  final String userId;
  final String? nickname;
  final String? avatar;
  final DateTime subscribedAt;
  final bool isMuted;

  SubscriberInfo({
    required this.userId,
    this.nickname,
    this.avatar,
    required this.subscribedAt,
    this.isMuted = false,
  });

  factory SubscriberInfo.fromJson(Map<String, dynamic> json) {
    return SubscriberInfo(
      userId: json['user_id'] as String? ?? '',
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      subscribedAt: json['subscribed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['subscribed_at'] as int)
          : DateTime.now(),
      isMuted: json['is_muted'] == true || json['is_muted'] == 1,
    );
  }
}

/// 订阅者管理页面
class ChannelSubscriberPage extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelSubscriberPage({super.key, required this.channelId});

  @override
  ConsumerState<ChannelSubscriberPage> createState() =>
      _ChannelSubscriberPageState();
}

class _ChannelSubscriberPageState extends ConsumerState<ChannelSubscriberPage> {
  final ChannelApi _api = ChannelApi();
  List<SubscriberInfo> _subscribers = [];
  bool _isLoading = true;
  String? _error;
  String? _searchKeyword;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadSubscribers();
  }

  Future<void> _loadSubscribers({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _subscribers = [];
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.getSubscribers(channelId: widget.channelId);

      if (mounted) {
        setState(() {
          _subscribers = result.map((e) => SubscriberInfo.fromJson(e)).toList();
          _isLoading = false;
          _hasMore = false; // 简化处理，暂不分页
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeSubscriber(SubscriberInfo subscriber) async {
    final t = context.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.channel.removeSubscriber),
        content: Text(t.channel.removeSubscriberConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 调用移除订阅者 API
        final success = await _api.removeSubscriber(
          widget.channelId,
          subscriber.userId,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.removeSubscriberSuccess)),
          );
          _loadSubscribers(refresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.channel.removeSubscriberFailed}: $e')),
          );
        }
      }
    }
  }

  void _showSearchDialog() {
    final controller = TextEditingController(text: _searchKeyword);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.channel.searchSubscribers),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.t.channel.subscriberSearchHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
          ),
          onSubmitted: (value) {
            Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(context.t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.t.search),
          ),
        ],
      ),
    ).then((value) {
      if (value != null) {
        setState(() {
          _searchKeyword = value.isEmpty ? null : value;
        });
        _loadSubscribers(refresh: true);
      }
    });
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return context.t.channel.today;
    } else if (diff.inDays == 1) {
      return context.t.channel.yesterday;
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ${context.t.channel.daysAgo}';
    } else {
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: '${t.channel.manageSubscribers} (${_subscribers.length})',
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: t.search,
          ),
          if (_searchKeyword != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _searchKeyword = null);
                _loadSubscribers(refresh: true);
              },
              tooltip: t.clear,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final t = context.t;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadSubscribers(refresh: true),
              child: Text(t.buttonRetry),
            ),
          ],
        ),
      );
    }

    if (_subscribers.isEmpty) {
      return NoDataView(
        icon: Icons.people_outline,
        text: _searchKeyword != null
            ? t.channel.noSearchResults
            : t.channel.noSubscribers,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSubscribers(refresh: true),
      child: ListView.builder(
        itemCount: _subscribers.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _subscribers.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final subscriber = _subscribers[index];

          return ListTile(
            leading: Avatar(
              imgUri: subscriber.avatar ?? '',
              width: 48,
              height: 48,
            ),
            title: Text(subscriber.nickname ?? subscriber.userId),
            subtitle: Text(
              '${t.channel.subscribedAt} ${_formatTime(subscriber.subscribedAt)}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'view_profile':
                    context.push('/people_info/${subscriber.userId}');
                    break;
                  case 'remove':
                    _removeSubscriber(subscriber);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view_profile',
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(t.channel.viewProfile),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: const Icon(
                      Icons.person_remove_outlined,
                      color: Colors.red,
                    ),
                    title: Text(
                      t.channel.removeSubscriber,
                      style: const TextStyle(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
