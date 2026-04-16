import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_admin_add_rules.dart'
    show searchContactCandidates;
import 'package:imboy/page/channel/channel_invitation_rules.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

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

  /// 当前用户是否有权发送邀请（私有频道管理员/创建者可用）。
  /// 默认 false，由调用方（路由 extra 或父组件）传入。
  final bool canInvite;

  const ChannelSubscriberPage({
    super.key,
    required this.channelId,
    this.canInvite = false,
  });

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
          _error = '${e.runtimeType}';
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
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.removeSubscriberSuccess)),
          );
          unawaited(_loadSubscribers(refresh: true));
        } else {
          // success=false 代表 API 返回非 ok（例如权限不足、订阅者不存在），
          // 旧实现在此分支静默无反馈，用户点了按钮以为成功；补齐失败提示
          // 与 catch 分支行为一致。
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.removeSubscriberFailed)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.removeSubscriberFailed)),
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
      if (value != null && mounted) {
        setState(() {
          _searchKeyword = value.isEmpty ? null : value;
        });
        unawaited(_loadSubscribers(refresh: true));
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

  Future<void> _showInviteContactPicker() async {
    // 先获取已有待处理邀请列表，用于过滤联系人
    List<Map<String, dynamic>> sentInvitations = [];
    try {
      sentInvitations = await ChannelService.to.getSentInvitations();
    } catch (_) {
      // 获取失败时不阻塞邀请流程，直接显示全量联系人
    }
    final pendingIds = extractPendingInviteeIds(sentInvitations);

    if (!mounted) return;

    final inviteeUid = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteContactPickerSheet(
        channelId: widget.channelId,
        pendingInviteeIds: pendingIds,
      ),
    );

    if (inviteeUid == null || !mounted) return;

    final t = context.t;
    final ok = await ChannelService.to.sendInvitation(
      channelId: widget.channelId,
      inviteeUid: inviteeUid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? t.channel.inviteSuccess : t.channel.inviteFailed),
      ),
    );
    if (ok) unawaited(_loadSubscribers(refresh: true));
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
      floatingActionButton: widget.canInvite
          ? FloatingActionButton(
              onPressed: _showInviteContactPicker,
              tooltip: t.channel.inviteFromContacts,
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
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

// ---------------------------------------------------------------------------
// 邀请联系人选择底部抽屉
// ---------------------------------------------------------------------------

/// 从通讯录中选择联系人发送频道邀请。
///
/// 返回值为被选中联系人的 userId（String），取消或未选择时返回 null。
class _InviteContactPickerSheet extends StatefulWidget {
  final String channelId;
  final List<String> pendingInviteeIds;

  const _InviteContactPickerSheet({
    required this.channelId,
    required this.pendingInviteeIds,
  });

  @override
  State<_InviteContactPickerSheet> createState() =>
      _InviteContactPickerSheetState();
}

class _InviteContactPickerSheetState
    extends State<_InviteContactPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final friends = await ContactRepo().findFriend();
      final maps = friends
          .map(
            (c) => {
              'peer_id': c.peerId,
              'nickname': c.title,
              'account': c.account,
              'remark': c.remark,
              'avatar': c.avatar,
            },
          )
          .toList();
      final candidates = filterContactsForInvitation(
        maps,
        pendingInviteeIds: widget.pendingInviteeIds,
      );
      if (mounted) {
        setState(() {
          _allContacts = candidates;
          _filtered = candidates;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch() {
    final keyword = _searchCtrl.text;
    setState(() {
      _filtered = searchContactCandidates(_allContacts, keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖拽把手
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              t.channel.inviteFromContacts,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: t.channel.inviteSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(child: Text(t.channel.noContactsToInvite))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          final nickname =
                              (c['nickname'] as String? ?? '').trim();
                          final account =
                              (c['account'] as String? ?? '').trim();
                          final avatar = c['avatar'] as String? ?? '';
                          final peerId =
                              c['peer_id']?.toString() ?? '';

                          return ListTile(
                            leading: Avatar(
                              imgUri: avatar,
                              width: 44,
                              height: 44,
                            ),
                            title: Text(
                              nickname.isNotEmpty ? nickname : peerId,
                            ),
                            subtitle: account.isNotEmpty
                                ? Text(account)
                                : null,
                            onTap: () => Navigator.of(context).pop(peerId),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
