import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/mention_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  StreamSubscription<dynamic>? _mentionSub;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMentions();
    _loadUnreadCount();
    _mentionSub = AppEventBus.on<NewMentionEvent>().listen((_) {
      _loadMentions(refresh: true);
      _loadUnreadCount();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _mentionSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // 触底加载更多：滚动监听回调，非 build 期触发，避免 "setState during build" 崩溃风险
  void _onScroll() {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreMentions();
    }
  }

  Future<void> _loadMoreMentions() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    final result = await MentionService.to.getMentions(
      page: nextPage,
      size: 20,
      groupId: widget.groupId,
    );

    if (!mounted) return;
    setState(() {
      _page = nextPage;
      if (result != null) {
        final items = result['items'] as List? ?? [];
        _mentions.addAll(items.cast<Map<String, dynamic>>());
        _hasMore = items.length >= 20;
      }
      _isLoadingMore = false;
    });
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

    if (!mounted) return;
    if (groupId.isEmpty || msgId.isEmpty) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      appBar: GlassAppBar(
        title: t.mention.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          if (_unreadCount > 0)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _markAllAsRead,
              child: Text(t.mention.allRead),
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading && _mentions.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
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
        controller: _scrollController,
        itemCount: _mentions.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _mentions.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.regular),
                child: CupertinoActivityIndicator(),
              ),
            );
          }

          final mention = _mentions[index];
          return _buildMentionItem(
            mention,
            isDark,
            isLast: index == _mentions.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildMentionItem(
    Map<String, dynamic> mention,
    bool isDark, {
    required bool isLast,
  }) {
    final isRead = mention['is_read'] == 1;

    return Column(
      key: ValueKey(mention['id']),
      children: [
        ImBoyListTile(
          onTap: () async {
            await _openMention(mention, isRead);
          },
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Avatar(
                imgUri: mention['avatar'] as String? ?? '',
                width: 48,
                height: 48,
              ),
              if (!isRead)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.getIosRed(Theme.of(context).brightness),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            mention['nickname'] as String? ?? '',
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(
            mention['content'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _formatTime(mention['created_at']),
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.getTextColor(
                Theme.of(context).brightness,
              ).withValues(alpha: 0.5),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 78),
            child: Divider(
              height: 0.33,
              color: AppColors.getIosSeparator(
                Theme.of(context).brightness,
              ).withValues(alpha: 0.4),
            ),
          ),
      ],
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
      return t.common.timeDaysShort(count: diff.inDays);
    } else if (diff.inHours > 0) {
      return t.common.timeHoursShort(count: diff.inHours);
    } else if (diff.inMinutes > 0) {
      return t.common.timeMinutesShort(count: diff.inMinutes);
    } else {
      return t.common.timeNowShort;
    }
  }
}
