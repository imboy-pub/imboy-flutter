import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:easy_refresh/easy_refresh.dart';

import 'package:imboy/page/group/group_role_rules.dart';
import 'mute_remaining_badge.dart';

/// 群成员列表页面
class GroupMemberPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupMemberPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupMemberPage> createState() => _GroupMemberPageState();
}

class _GroupMemberPageState extends ConsumerState<GroupMemberPage> {
  final EasyRefreshController _refreshController = EasyRefreshController();
  final ScrollController _scrollController = ScrollController();

  List<GroupMemberModel> _memberList = [];
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoading = false;
  int _myRole = 1;

  StreamSubscription? _localeSubscription;
  // slice-9c：群成员禁言/解禁 S2C 事件订阅
  StreamSubscription<GroupMemberMuteEvent>? _ssMemberMute;
  StreamSubscription<GroupMemberUnmuteEvent>? _ssMemberUnmute;

  @override
  void initState() {
    super.initState();
    _loadData();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) setState(() {});
    });
    _setupMuteEventListeners();
  }

  /// 订阅群成员禁言/解禁事件，实时刷新列表中对应成员的禁言徽章。
  void _setupMuteEventListeners() {
    _ssMemberMute = AppEventBus.on<GroupMemberMuteEvent>().listen(
      (event) {
        if (!mounted) return;
        if (event.gid.toString() != widget.groupId) return;
        if (event.userId.isEmpty) return;
        // 找到对应成员，原地更新 muteUntilMs 后触发重建
        final idx =
            _memberList.indexWhere((m) => m.userId.toString() == event.userId);
        if (idx == -1) return;
        setState(() {
          _memberList[idx].muteUntilMs = event.muteUntilMs;
        });
      },
      onError: (error) =>
          debugPrint('GroupMemberMuteEvent listener error: $error'),
    );

    _ssMemberUnmute = AppEventBus.on<GroupMemberUnmuteEvent>().listen(
      (event) {
        if (!mounted) return;
        if (event.gid.toString() != widget.groupId) return;
        if (event.userId.isEmpty) return;
        final idx =
            _memberList.indexWhere((m) => m.userId.toString() == event.userId);
        if (idx == -1) return;
        setState(() {
          _memberList[idx].muteUntilMs = null;
        });
      },
      onError: (error) =>
          debugPrint('GroupMemberUnmuteEvent listener error: $error'),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    _localeSubscription?.cancel();
    _ssMemberMute?.cancel();
    _ssMemberUnmute?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前用户角色
      if (refresh || _myRole == 1) {
        String currentUid = UserRepoLocal.to.currentUid;
        GroupMemberModel? myMember = await GroupMemberRepo().findByUserId(
          widget.groupId,
          currentUid,
        );
        if (myMember != null) {
          _myRole = myMember.role;
        }
      }

      // 先从本地数据库加载
      GroupMemberRepo repo = GroupMemberRepo();
      if (refresh) {
        _memberList = await repo.page(
          limit: _pageSize,
          where: "${GroupMemberRepo.groupId} = ?",
          whereArgs: [widget.groupId],
          orderBy: "${GroupMemberRepo.role} DESC, ${GroupMemberRepo.createdAt} ASC",
        );
      }

      // 从服务器同步数据
      Map<String, dynamic>? payload = await GroupMemberApi().page(
        gid: widget.groupId,
        page: _currentPage,
        size: _pageSize,
      );

      if (payload != null && payload['list'] != null) {
        List<dynamic> list = payload['list'];
        List<GroupMemberModel> newMembers = [];

        for (var item in list) {
          GroupMemberModel member = await repo.save(item);
          newMembers.add(member);
        }

        if (refresh || _currentPage == 1) {
          _memberList = newMembers;
        } else {
          _memberList.addAll(newMembers);
        }

        // 检查是否还有更多数据
        int total = payload['total'] ?? 0;
        _hasMore = _memberList.length < total;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      EasyLoading.showError(t.loadError);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) {
      return;
    }

    _currentPage++;
    await _loadData();
  }

  /// 构建角色标签
  Widget _buildRoleBadge(int role) {
    
    String label;
    Color color;

    switch (role) {
      case 4:
        label = t.groupOwner;
        color = AppColors.iosOrange;
        break;
      case 3:
        label = t.groupAdmin;
        color = AppColors.getIosBlue(Theme.of(context).brightness);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusTiny,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context, GroupMemberModel member) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    

    return InkWell(
      onTap: () async {
        final result = await context.push<bool>(
          '/group/member_detail',
          extra: {'groupId': widget.groupId, 'userId': member.userId},
        );

        // 如果成员被移除或群主已转让，刷新列表
        if (result == true && mounted) {
          _loadData(refresh: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 头像
            Avatar(imgUri: member.avatar, width: 48, height: 48),
            const SizedBox(width: 12),
            // 昵称和签名
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.alias.isEmpty ? member.nickname : member.alias,
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.medium,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isGroupAdmin(member.role))
                        _buildRoleBadge(member.role),
                      // F2：禁言剩余时间徽章（slice-1 muteUntilMs + slice-2 label）
                      MuteRemainingBadge(
                        muteUntilMs: member.muteUntilMs,
                        nowMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    ],
                  ),
                  if (member.sign.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      member.sign,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.small,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 箭头
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: '${t.groupMembers} (${_memberList.length})',
      ),
      body: _isLoading && _memberList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _memberList.isEmpty
              ? NoDataView(text: t.noData)
              : EasyRefresh(
                  controller: _refreshController,
                  onRefresh: () async {
                    await _loadData(refresh: true);
                  },
                  onLoad: _hasMore ? _loadMore : null,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _memberList.length,
                    itemBuilder: (context, index) {
                      final member = _memberList[index];
                      return Column(
                        children: [
                          _buildListItem(context, member),
                          if (index < _memberList.length - 1)
                            Divider(
                              height: 1,
                              indent: 76,
                              endIndent: 16,
                              color: colorScheme.outline.withValues(alpha: 0.1),
                            ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}
