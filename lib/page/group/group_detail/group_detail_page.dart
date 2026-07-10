import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/group_notice_config.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/report_api.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:synchronized/synchronized.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'package:imboy/page/group/group_detail/widgets/group_app_grid.dart';
import 'package:imboy/page/group/group_detail/widgets/group_info_card.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';
import 'package:imboy/page/personal_info/update/update_page.dart';
import 'change_info_page.dart';
import 'group_detail_provider.dart';
import 'group_detail_service.dart';
import 'group_notice_disabled_tile.dart';

/// 群组详情页面 - iOS 17 Premium 风格
///
/// 信息架构（自上而下，对标微信群设置 + QQ 群应用）：
///   1. 群信息卡片（头像/群名/简介/成员数 → 编辑）
///   2. 群成员横滑区（头像列表 + 添加/移除 + 查看全部）
///   3. 群应用九宫格（公告/文件/相册/投票/日程/任务/标签/分类/二维码）
///   4. 偏好设置（免打扰/群昵称/群备注/搜索）
///   5. 危险操作（清空记录/投诉）
///   6. 退出/解散按钮
class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final String title;
  final int memberCount;
  final Function? callBack;
  final Map<String, dynamic>? options;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.title,
    required this.memberCount,
    this.callBack,
    this.options,
  });

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  bool backDoRefresh = false;
  final Lock _lock = Lock();
  StreamSubscription<dynamic>? ssMsgExt;
  StreamSubscription<dynamic>? _localeSubscription;
  bool _noticeDisabled = false;

  int get _gidInt => int.tryParse(widget.groupId) ?? 0;

  @override
  void initState() {
    super.initState();
    _noticeDisabled = readNoticeDisabled(
      _gidInt,
      readBool: StorageService.to.getBool,
    );
    unawaited(initData());
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    ssMsgExt?.cancel();
    _localeSubscription?.cancel();
    super.dispose();
  }

  Future<void> initData() async {
    final notifier = ref.read(groupDetailProvider.notifier);
    final service = GroupDetailService();
    notifier.setLoading(true);
    bool connected = false;
    List<PeopleModel> memberList = [];
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      connected = !connectivityResult.contains(ConnectivityResult.none);

      notifier.setTitle(widget.title);
      notifier.setMemberCount(widget.memberCount);

      memberList = await service.listGroupMember(
        gid: widget.groupId,
        sync: false,
        limit: 18,
      );
      memberList.add(PeopleModel(id: -1, account: 'add'));
      int role = await service.role(
        gid: widget.groupId,
        userId: UserRepoLocal.to.currentUid,
      );
      bool isAdmin = isGroupAdmin(role);
      notifier.setRoleInfo(role, isAdmin);
      if (isAdmin) memberList.add(PeopleModel(id: -2, account: 'remove'));
      notifier.setMemberList(memberList);

      GroupMemberModel? m = await service.getMyGroupMemberInfo(widget.groupId);
      if (m != null) notifier.setMyGroupAlias(m.alias);
    } finally {
      notifier.setLoading(false);
    }

    service.detail(gid: widget.groupId, sync: connected).then((g) async {
      if (g != null) {
        notifier.setMemberCount(g.memberCount);
        notifier.setTitle(g.title);
        // 补全群信息，供 GroupInfoCard 展示头像/简介
        notifier.setGroup(g);
        if (connected && widget.memberCount != g.memberCount) {
          memberList = await service.listGroupMember(
            gid: widget.groupId,
            sync: true,
            limit: 1000,
          );
          if (memberList.length > 18) memberList = memberList.sublist(0, 18);
          notifier.setMemberList(memberList);
        }
        if (mounted) setState(() {});
      }
    });

    ssMsgExt ??= AppEventBus.on<ChatExtendEvent>().listen((obj) async {
      if (obj.type == 'join_group' &&
          obj.payload['groupId'] == widget.groupId &&
          ((obj.payload['isFirst'] as bool?) ?? false)) {
        await _lock.synchronized(() async {
          notifier.addMember(obj.payload['people'] as PeopleModel);
          backDoRefresh = true;
          if (mounted) setState(() {});
        });
      } else if (obj.type == 'leave_group' &&
          obj.payload['groupId'] == widget.groupId) {
        await _lock.synchronized(() async {
          final uid = obj.payload['userId'];
          notifier.removeMember(
            uid is int ? uid : int.tryParse(uid?.toString() ?? '0') ?? 0,
          );
          backDoRefresh = true;
          if (mounted) setState(() {});
        });
      }
    });
  }

  /// 编辑群信息（群名/头像/简介）。
  Future<void> _editGroupInfo(GroupModel? group) async {
    if (group == null || !context.mounted) return;
    await Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => ChangeInfoPage(
          group: group,
          title: t.group.groupName,
          subtitle: t.common.pleaseEnterContent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupDetailProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: state.title.isEmpty ? t.chat.chatMessage : state.title,
      useLargeTitle: false,
      child: state.isLoading && state.group == null
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                // 1. 群信息卡片
                GroupInfoCard(
                  group:
                      state.group ??
                      GroupModel(
                        groupId: int.tryParse(widget.groupId) ?? 0,
                        type: 2,
                        joinLimit: 1,
                        contentLimit: 1,
                        userIdSum: 0,
                        ownerUid: 0,
                        creatorUid: 0,
                        memberMax: 0,
                        memberCount: state.memberCount,
                        title: state.title,
                        createdAt: 0,
                      ),
                  onTap: () async => _editGroupInfo(
                    await GroupDetailService().find(widget.groupId),
                  ),
                ),

                // 2. 群成员横滑区
                _GroupMemberSection(
                  groupId: widget.groupId,
                  onMemberRemoved: () => backDoRefresh = true,
                ),

                // 3. 群应用九宫格
                GroupAppGrid(items: _buildAppItems(state.group)),

                // 4. 偏好设置 Section
                ImBoySettingsSection(
                  children: [
                    ImBoySettingsTile(
                      title: Text(t.group.groupAlias),
                      trailing: Text(
                        strEmpty(state.myGroupAlias)
                            ? UserRepoLocal.to.current.nickname
                            : state.myGroupAlias!,
                        style: context.textStyle(
                          FontSizeType.subheadline,
                          color: AppColors.iosGray,
                        ),
                      ),
                      // 复用通用文本编辑页 UpdatePage（callback 内落库）。
                      // 原先推送的 /group/remark 是未注册路由，点击必抛 no-routes。
                      onTap: () async {
                        await Navigator.push(
                          context,
                          CupertinoPageRoute<void>(
                            builder: (_) => UpdatePage(
                              title: t.group.groupAlias,
                              value: state.myGroupAlias ?? '',
                              field: 'input',
                              maxLength: 56,
                              callback: (val) async {
                                final ok = await GroupDetailService()
                                    .updateMyGroupAlias(widget.groupId, val);
                                if (ok) {
                                  ref
                                      .read(groupDetailProvider.notifier)
                                      .setMyGroupAlias(val);
                                }
                                return ok;
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    ImBoySettingsTile(
                      title: Text(t.contact.remark),
                      trailing: Text(
                        strEmpty(state.groupRemark)
                            ? state.group?.title ?? ''
                            : state.groupRemark!,
                        style: context.textStyle(
                          FontSizeType.subheadline,
                          color: AppColors.iosGray,
                        ),
                      ),
                      // 同上：/group/remark 未注册，改用 UpdatePage。
                      onTap: () async {
                        await Navigator.push(
                          context,
                          CupertinoPageRoute<void>(
                            builder: (_) => UpdatePage(
                              title: t.contact.remark,
                              value: state.groupRemark ?? '',
                              field: 'input',
                              maxLength: 56,
                              callback: (val) async {
                                final ok = await GroupApi().updateRemark(
                                  gid: widget.groupId,
                                  remark: val,
                                );
                                if (ok) {
                                  ref
                                      .read(groupDetailProvider.notifier)
                                      .setGroupRemark(val);
                                }
                                return ok;
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    GroupNoticeDisabledTile(
                      label: t.common.muteNotifications,
                      value: _noticeDisabled,
                      onChanged: _gidInt <= 0
                          ? null
                          : (v) async {
                              final prev = _noticeDisabled;
                              setState(() => _noticeDisabled = v);
                              try {
                                await setNoticeDisabled(
                                  _gidInt,
                                  v,
                                  writeBool: (k, val) async =>
                                      StorageService.to.setBool(k, val),
                                );
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _noticeDisabled = prev);
                                  AppLoading.showError(t.common.tipFailed);
                                }
                              }
                            },
                    ),
                    ImBoySettingsTile(
                      title: Text(t.common.searchChatContent),
                      leading: const Icon(
                        CupertinoIcons.search,
                        color: AppColors.iosBlue,
                        size: 20,
                      ),
                      onTap: () => context.push(
                        '/search_chat',
                        extra: {
                          'type': 'C2G',
                          'peerId': widget.groupId,
                          'peerTitle': widget.title,
                          'peerAvatar': widget.options?['peerAvatar'],
                          'peerSign': widget.options?['peerSign'],
                          'conversationUk3': widget.options?['conversationUk3'],
                        },
                      ),
                    ),
                  ],
                ),

                // 5. 危险操作 Section
                ImBoySettingsSection(
                  children: [
                    ImBoySettingsTile(
                      title: Text(t.common.clearChatRecord),
                      destructive: true,
                      onTap: () => _confirmClearChat(),
                    ),
                    ImBoySettingsTile(
                      title: Text(t.complaint.complaint),
                      onTap: () => _showComplaintDialog(context),
                    ),
                  ],
                ),

                // 6. 退出/解散按钮（与危险操作区留白隔离，强调最高危操作）
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.regular,
                    AppSpacing.xxxLarge,
                    AppSpacing.regular,
                    AppSpacing.xxLarge,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppColors.getIosRed(
                          brightness,
                        ).withValues(alpha: 0.1),
                        foregroundColor: AppColors.getIosRed(brightness),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: AppColors.getIosRed(
                              brightness,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      onPressed: () => _confirmExitGroup(state),
                      child: Text(
                        isGroupOwner(state.role)
                            ? t.group.groupDissolve
                            : t.group.groupLeave,
                        style: context.textStyle(
                          FontSizeType.body,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 构建群应用九宫格入口。每项跳转对应协作子页面路由。
  List<GroupAppItem> _buildAppItems(GroupModel? group) {
    final gid = widget.groupId;
    return [
      GroupAppItem(
        icon: CupertinoIcons.speaker_2_fill,
        label: t.common.groupAnnouncement,
        color: AppColors.iosOrange,
        onTap: () =>
            context.push('/group/announcement', extra: {'groupId': gid}),
      ),
      GroupAppItem(
        icon: CupertinoIcons.folder_fill,
        label: t.chat.groupFile,
        color: AppColors.iosBlue,
        onTap: () => context.push('/group/$gid/file'),
      ),
      GroupAppItem(
        icon: CupertinoIcons.photo_fill,
        label: t.group.groupAlbum,
        color: AppColors.iosGreen,
        onTap: () => context.push('/group/$gid/album'),
      ),
      GroupAppItem(
        icon: CupertinoIcons.chart_bar_square_fill,
        label: t.groupVote.title,
        color: AppColors.iosPurple,
        onTap: () => context.push('/group/$gid/vote'),
      ),
      GroupAppItem(
        icon: CupertinoIcons.calendar,
        label: t.groupSchedule.title,
        color: AppColors.iosRed,
        onTap: () => context.push('/group/$gid/schedule'),
      ),
      GroupAppItem(
        icon: CupertinoIcons.checkmark_seal_fill,
        label: t.groupTask.title,
        color: AppColors.iosTeal,
        onTap: () => context.push('/group/$gid/task'),
      ),
      GroupAppItem(
        icon: CupertinoIcons.tag_fill,
        label: t.groupTag.title,
        color: AppColors.iosSkyBlue,
        onTap: () => context.push('/group/$gid/tag'),
      ),
      GroupAppItem(
        icon: CupertinoIcons.folder_open,
        label: t.groupCategory.title,
        color: AppColors.iosYellow,
        onTap: () => context.push('/group/category'),
      ),
      GroupAppItem(
        icon: CupertinoIcons.qrcode,
        label: t.account.groupQrcode,
        color: AppColors.iosGray,
        onTap: () async {
          final g = group ?? await GroupDetailService().find(gid);
          if (g != null && mounted) {
            context.push('/qrcode/group', extra: {'group': g});
          }
        },
      ),
    ];
  }

  void _confirmClearChat() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.warning),
        content: Text(t.common.confirmDeleteChatRecord),
        actions: [
          CupertinoDialogAction(
            child: Text(t.common.buttonCancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(t.common.buttonConfirm),
            onPressed: () async {
              Navigator.pop(ctx);
              int cid = await GroupDetailService().cleanMessageByPeerId(
                'C2G',
                widget.groupId,
              );
              if (cid > 0) {
                backDoRefresh = true;
                await ref
                    .read(conversationProvider.notifier)
                    .hideConversation(cid);
                await ref
                    .read(conversationProvider.notifier)
                    .conversationsList();
                AppLoading.showSuccess(t.common.tipSuccess);
              } else {
                AppLoading.showError(t.common.tipFailed);
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmExitGroup(GroupDetailState state) {
    String tips =
        "${isGroupOwner(state.role) ? t.group.sureToDissolveGroup : t.group.sureToLeaveGroup}\n${t.common.sureDeleteGroupChatRecord}";
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.tipTips),
        content: Text(tips),
        actions: [
          CupertinoDialogAction(
            child: Text(t.common.buttonCancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(t.common.buttonConfirm),
            onPressed: () async {
              var nav = Navigator.of(context);
              bool res = isGroupOwner(state.role)
                  ? await GroupDetailService().dissolve(widget.groupId)
                  : await GroupDetailService().leave(widget.groupId);
              if (res) {
                AppLoading.showSuccess(t.common.tipSuccess);
                nav.pop();
                nav.pop();
              } else {
                // 失败必须给反馈+关弹窗，否则用户点确认后界面像卡死
                AppLoading.showError(t.common.tipFailed);
                nav.pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showComplaintDialog(BuildContext context) {
    GroupDialogs.actionSheet(
      context,
      title: t.complaint.complaint,
      actions: [
        (
          label: t.complaintReason.spam,
          destructive: false,
          onPressed: () => _submitComplaint('spam'),
        ),
        (
          label: t.complaintReason.harassment,
          destructive: false,
          onPressed: () => _submitComplaint('harassment'),
        ),
        (
          label: t.complaintReason.inappropriate,
          destructive: false,
          onPressed: () => _submitComplaint('inappropriate'),
        ),
        (
          label: t.complaintReason.other,
          destructive: false,
          onPressed: () => _submitComplaint('other'),
        ),
      ],
    );
  }

  Future<void> _submitComplaint(String reason) async {
    if (await ReportApi().create(
      targetType: 'group',
      targetId: widget.groupId,
      reason: reason,
    )) {
      AppLoading.showSuccess(t.common.complaintSuccess);
    } else {
      AppLoading.showError(t.common.complaintFailed);
    }
  }
}

/// 群成员 Section：独立 ConsumerWidget，只 select memberCount/memberList，
/// 避免 GroupDetailPage 其余字段变化（如 myGroupAlias/title）连带重建
/// 头像列表布局。
class _GroupMemberSection extends ConsumerWidget {
  const _GroupMemberSection({
    required this.groupId,
    required this.onMemberRemoved,
  });

  final String groupId;
  final VoidCallback onMemberRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberCount = ref.watch(
      groupDetailProvider.select((s) => s.memberCount),
    );
    final memberList = ref.watch(
      groupDetailProvider.select((s) => s.memberList),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.group.groupMembers,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$memberCount',
                style: context.textStyle(
                  FontSizeType.subheadline,
                  color: AppColors.iosGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.regular),
          AvatarList(
            memberList: memberList,
            width: 52,
            height: 52,
            column: (MediaQuery.sizeOf(context).width - 72) ~/ 64,
            onTapAvatar: (p) => context.push(
              '/people_info/${p.id}',
              extra: {'scene': 'group_member'},
            ),
            onTapAdd: () =>
                context.push('/group/add_member', extra: {'groupId': groupId}),
            onTapRemove: () async {
              final res = await context.push<List<GroupMemberModel>>(
                '/group/remove_member',
                extra: {'groupId': groupId},
              );
              if (res != null) {
                for (var gm in res) {
                  ref
                      .read(groupDetailProvider.notifier)
                      .removeMember(gm.userId);
                }
                onMemberRemoved();
              }
            },
          ),
          if (memberCount > 20) ...[
            const SizedBox(height: AppSpacing.medium),
            Center(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(
                  t.common.viewAllGroupMember,
                  style: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getIosBlue(Theme.of(context).brightness),
                  ),
                ),
                onPressed: () =>
                    context.push('/group/member', extra: {'groupId': groupId}),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
