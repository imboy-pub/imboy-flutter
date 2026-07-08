import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
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
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:easy_refresh/easy_refresh.dart';

import 'package:imboy/page/group/group_role_rules.dart';
import 'group_member_mute_util.dart';
import 'mute_remaining_badge.dart';

/// 群成员列表页面
///
/// 体验优化：
/// - 顶部搜索栏（按昵称/群昵称即时过滤）
/// - 角色筛选分段控件（全部 / 群主 / 管理员 / 普通）
/// - 列表项统一 iOS 视觉
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

  /// 搜索关键字（即时过滤）
  String _keyword = '';

  /// 角色筛选：0=全部 4=群主 3=管理员 1=普通成员
  int _roleFilter = 0;

  StreamSubscription<dynamic>? _localeSubscription;
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
        final idx = _memberList.indexWhere(
          (m) => m.userId.toString() == event.userId,
        );
        if (idx == -1) return;
        // BUG-11：不可变更新，替换匹配成员为新实例，避免原地修改 Model
        setState(() {
          _memberList = applyMemberMuteUpdate(
            _memberList,
            event.userId,
            event.muteUntilMs,
          );
        });
      },
      onError: (Object error) {
        debugPrint('[GroupMemberPage] mute event error: $error');
      },
    );

    _ssMemberUnmute = AppEventBus.on<GroupMemberUnmuteEvent>().listen(
      (event) {
        if (!mounted) return;
        if (event.gid.toString() != widget.groupId) return;
        if (event.userId.isEmpty) return;
        final idx = _memberList.indexWhere(
          (m) => m.userId.toString() == event.userId,
        );
        if (idx == -1) return;
        setState(() {
          _memberList = applyMemberMuteUpdate(_memberList, event.userId, null);
        });
      },
      onError: (Object error) {
        debugPrint('[GroupMemberPage] unmute event error: $error');
      },
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
          orderBy:
              "${GroupMemberRepo.role} DESC, ${GroupMemberRepo.createdAt} ASC",
        );
      }

      // 从服务器同步数据
      Map<String, dynamic>? payload = await GroupMemberApi().page(
        gid: widget.groupId,
        page: _currentPage,
        size: _pageSize,
      );

      if (payload != null && payload['list'] != null) {
        List<dynamic> list = payload['list'] as List<dynamic>;
        List<GroupMemberModel> newMembers = [];

        for (var item in list) {
          GroupMemberModel member = await repo.save(
            item as Map<String, dynamic>,
          );
          newMembers.add(member);
        }

        if (refresh || _currentPage == 1) {
          _memberList = newMembers;
        } else {
          _memberList.addAll(newMembers);
        }

        // 检查是否还有更多数据
        int total = payload['total'] as int? ?? 0;
        _hasMore = _memberList.length < total;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLoading.showError(t.common.loadError);
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

  /// 本地过滤（搜索关键字 + 角色筛选）
  List<GroupMemberModel> get _filteredList {
    var list = _memberList;
    // 角色筛选
    if (_roleFilter != 0) {
      if (_roleFilter == 1) {
        // 普通成员：role <= 2（成员+嘉宾）
        list = list.where((m) => m.role <= 2).toList();
      } else {
        list = list.where((m) => m.role == _roleFilter).toList();
      }
    }
    // 关键字搜索
    final kw = _keyword.trim().toLowerCase();
    if (kw.isNotEmpty) {
      list = list.where((m) {
        return m.nickname.toLowerCase().contains(kw) ||
            m.alias.toLowerCase().contains(kw);
      }).toList();
    }
    return list;
  }

  /// 构建角色标签
  Widget _buildRoleBadge(int role) {
    String label;
    Color color;

    switch (role) {
      case 4:
        label = t.group.groupOwner;
        color = AppColors.iosOrange;
        break;
      case 3:
        label = t.group.groupAdmin;
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
        style: context.textStyle(
          FontSizeType.tiny,
          color: color,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
        child: Row(
          children: [
            // 头像
            Avatar(imgUri: member.avatar, width: 48, height: 48),
            const SizedBox(width: AppSpacing.medium),
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
                            FontSizeType.body,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isGroupAdmin(member.role))
                        _buildRoleBadge(member.role),
                      // 禁言剩余时间徽章
                      MuteRemainingBadge(
                        muteUntilMs: member.muteUntilMs,
                        nowMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    ],
                  ),
                  if (member.sign.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.tiny),
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
              CupertinoIcons.chevron_right,
              size: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
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
    final brightness = theme.brightness;
    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: '${t.group.groupMembers} (${_memberList.length})',
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.small,
            ),
            child: CupertinoSearchTextField(
              placeholder: t.common.search,
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          // 角色筛选分段控件
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
            ).copyWith(bottom: AppSpacing.small),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _roleFilter,
                thumbColor: AppColors.getIosBlue(brightness),
                padding: const EdgeInsets.all(3),
                children: {
                  0: _segmentLabel(t.groupList.attrAll, _roleFilter == 0),
                  4: _segmentLabel(t.group.groupOwner, _roleFilter == 4),
                  3: _segmentLabel(t.group.groupAdmin, _roleFilter == 3),
                  // TODO(i18n): t.group.memberOrdinary
                  1: _segmentLabel('成员', _roleFilter == 1),
                },
                onValueChanged: (v) {
                  if (v != null) setState(() => _roleFilter = v);
                },
              ),
            ),
          ),
          // 列表
          Expanded(
            child: _isLoading && _memberList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _memberList.isEmpty
                ? NoDataView(text: t.common.noData)
                : filtered.isEmpty
                ? NoDataView(
                    text: t.common.searchNoResults,
                    icon: CupertinoIcons.search,
                  )
                : EasyRefresh(
                    controller: _refreshController,
                    onRefresh: () async {
                      await _loadData(refresh: true);
                    },
                    onLoad: _hasMore ? _loadMore : null,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final member = filtered[index];
                        return Column(
                          children: [
                            _buildListItem(context, member),
                            if (index < filtered.length - 1)
                              Divider(
                                height: 1,
                                indent: 76,
                                endIndent: 16,
                                color: colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 分段控件标签
  Widget _segmentLabel(String text, bool selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: context.textStyle(
          FontSizeType.caption2,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? AppColors.onPrimary : AppColors.iosGray,
        ),
      ),
    );
  }
}
