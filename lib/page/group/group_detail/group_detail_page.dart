import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/component/ui/line.dart';
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
import 'package:imboy/component/ui/easy_dialog.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:synchronized/synchronized.dart';

import 'package:imboy/config/enum.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'change_info_page.dart';
import 'group_detail_provider.dart';
import 'group_detail_service.dart';
import 'group_notice_disabled_tile.dart';

/// 群组详情服务 Provider
final groupDetailServiceProvider = Provider<GroupDetailService>((ref) {
  return GroupDetailService();
});

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

  /// slice-7 (C6 UI) — 群消息免打扰本地偏好（KV 存储，见 `group_notice_config.dart`）。
  /// widget.groupId 是 String（TSID），KV key 内部按字符串插值，数值大小无关。
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
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    ssMsgExt?.cancel();
    _localeSubscription?.cancel();
    super.dispose();
  }

  Future<void> initData() async {
    final notifier = ref.read(groupDetailProvider.notifier);
    final service = ref.read(groupDetailServiceProvider);

    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    bool connected =
        connectivityResult.contains(ConnectivityResult.none) == false;

    // 初始化状态
    notifier.setTitle(widget.title);
    notifier.setMemberCount(widget.memberCount);

    // 获取群成员信息
    List<PeopleModel> memberList = await service.listGroupMember(
      gid: widget.groupId,
      sync: false,
      limit: 18,
    );

    memberList.add(PeopleModel(id: -1, account: 'add'));
    int role = await service.role(
      gid: widget.groupId,
      userId: UserRepoLocal.to.currentUid,
    );
    // isGroupAdmin 覆盖 admin(3)/owner(4)/vice_owner(5)，修复原 role==3||4 漏掉副群主的 bug
    bool isAdmin = isGroupAdmin(role);
    notifier.setRoleInfo(role, isAdmin);

    if (isAdmin) {
      memberList.add(PeopleModel(id: -2, account: 'remove'));
    }
    notifier.setMemberList(memberList);

    // 获取我在本群的别名
    GroupMemberModel? m = await service.getMyGroupMemberInfo(widget.groupId);
    if (m != null) {
      notifier.setMyGroupAlias(m.alias);
    }

    // 在有网络的情况下，异步更新群信息详情
    service.detail(gid: widget.groupId, sync: connected).then((
      GroupModel? g,
    ) async {
      iPrint("logic.detail then connected $connected, gid=${widget.groupId}");
      if (g != null) {
        notifier.setMemberCount(g.memberCount);
        notifier.setTitle(g.title);

        if (connected && widget.memberCount != g.memberCount) {
          memberList = await service.listGroupMember(
            gid: widget.groupId,
            sync: true,
            limit: 1000,
          );
          if (memberList.length > 18) memberList = memberList.sublist(0, 18);
          notifier.setMemberList(memberList);
        }
        if (mounted) {
          setState(() {});
        }
      }
    });

    setState(() {});

    // 监听事件
    ssMsgExt ??= AppEventBus.on<ChatExtendEvent>().listen((
      ChatExtendEvent obj,
    ) async {
      iPrint("group_detail ChatExtendEvent type=${obj.type}");
      if (obj.type == 'join_group' &&
          obj.payload['groupId'] == widget.groupId &&
          (obj.payload['isFirst'] ?? false) == true) {
        await _lock.synchronized(() async {
          notifier.addMember(obj.payload['people']);
          backDoRefresh = true;
          if (mounted) {
            setState(() {});
          }
        });
      } else if (obj.type == 'leave_group' &&
          obj.payload['groupId'] == widget.groupId) {
        await _lock.synchronized(() async {
          final payloadUserId = obj.payload['userId'];
          notifier.removeMember(
            payloadUserId is int
                ? payloadUserId
                : int.tryParse(payloadUserId?.toString() ?? '0') ?? 0,
          );
          backDoRefresh = true;
          if (mounted) {
            setState(() {});
          }
        });
        backDoRefresh = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(groupDetailProvider);
    final service = ref.read(groupDetailServiceProvider);

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: colorScheme.primary,
            size: 20,
          ),
          onPressed: () {
            context.pop({'memberCount': state.memberCount});
          },
        ),
        title:
            "${state.title.isEmpty ? t.chatMessage : state.title} (${state.memberCount})",
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 群成员头像区域
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.groupMembers,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AvatarList(
                    memberList: state.memberList,
                    titleMaxLines: 1,
                    titleStyle: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    width: 56,
                    height: 56,
                    column: (MediaQuery.of(context).size.width - 72) ~/ 56,
                    onTapAvatar: (PeopleModel p) {
                      context.push(
                        '/people_info/${p.id}',
                        extra: {'scene': 'group_member'},
                      );
                    },
                    onTapAdd: () {
                      context.push(
                        '/group/add_member',
                        extra: {'groupId': widget.groupId},
                      );
                    },
                    onTapRemove: () async {
                      final result = await context.push<List<GroupMemberModel>>(
                        '/group/remove_member',
                        extra: {'groupId': widget.groupId},
                      );
                      if (result != null) {
                        iPrint(
                          "RemoveMemberPage removed ${result.length} members",
                        );
                        for (var gm in result) {
                          ref
                              .read(groupDetailProvider.notifier)
                              .removeMember(gm.userId);
                        }
                        backDoRefresh = true;
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    },
                  ),
                  // 查看全部成员按钮
                  if (state.memberCount > 20) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => context.push(
                          '/group/member',
                          extra: {'groupId': widget.groupId},
                        ),
                        icon: Icon(
                          Icons.people_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          t.viewAllGroupMember,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadiusSmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 群组信息区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.borderRadiusRegular,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 群名称
                  _buildModernListTile(
                    context: context,
                    title: t.groupName,
                    value: state.title.isEmpty ? t.unnamed : state.title,
                    icon: Icons.group_outlined,
                    onTap: () async {
                      GroupModel? group = await service.find(widget.groupId);
                      if (group != null && mounted) {
                        // 导航到修改群名页面
                        Navigator.push(
                          context,
                          CupertinoPageRoute<dynamic>(
                            builder: (_) => ChangeInfoPage(
                              group: group,
                              title: t.groupName,
                              subtitle: t.pleaseEnterContent,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  ModernDivider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  // 群二维码
                  _buildModernListTile(
                    context: context,
                    title: t.groupQrcode,
                    icon: Icons.qr_code_2_outlined,
                    onTap: () async {
                      GroupModel? group = await service.find(widget.groupId);
                      if (!mounted) return;
                      if (group != null) {
                        if (context.mounted) {
                          context.push(
                            '/qrcode/group',
                            extra: {'group': group},
                          );
                        }
                      }
                    },
                  ),
                  ModernDivider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  // 群公告
                  _buildModernListTile(
                    context: context,
                    title: t.groupAnnouncement,
                    icon: Icons.announcement_outlined,
                    onTap: () {
                      context.push(
                        '/group/announcement',
                        extra: {'groupId': widget.groupId},
                      );
                    },
                  ),
                  ModernDivider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  _buildModernListTile(
                    context: context,
                    title: t.groupFile,
                    icon: Icons.insert_drive_file_outlined,
                    onTap: () {
                      context.push('/group/${widget.groupId}/file');
                    },
                  ),
                  ModernDivider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  _buildModernListTile(
                    context: context,
                    title: t.groupAlbum,
                    icon: Icons.photo_album_outlined,
                    onTap: () {
                      context.push('/group/${widget.groupId}/album');
                    },
                  ),
                ],
              ),
            ),
            // 搜索功能区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildModernListTile(
                context: context,
                title: t.searchChatContent,
                icon: Icons.search_outlined,
                onTap: () {
                  context.push(
                    '/search_chat',
                    extra: {
                      'type': 'C2G',
                      'peerId': widget.groupId,
                      'peerTitle': widget.title,
                      'peerAvatar': widget.options?['peerAvatar'],
                      'peerSign': widget.options?['peerSign'],
                      'conversationUk3': widget.options?['conversationUk3'],
                    },
                  );
                },
              ),
            ),
            // 群组设置区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.borderRadiusRegular,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildModernListTile(
                    context: context,
                    title: t.groupAlias,
                    value: strEmpty(state.myGroupAlias)
                        ? UserRepoLocal.to.current.nickname
                        : state.myGroupAlias,
                    icon: Icons.edit_note_outlined,
                    onTap: () async {
                      final result = await context.push<String>(
                        '/group/remark',
                        extra: {
                          'groupInfoType': GroupInfoType.cardName,
                          'text': state.myGroupAlias ?? '',
                          'groupId': widget.groupId,
                        },
                      );
                      if (result != null) {
                        bool res = await service.updateMyGroupAlias(
                          widget.groupId,
                          result,
                        );
                        if (res) {
                          ref
                              .read(groupDetailProvider.notifier)
                              .setMyGroupAlias(result);
                          setState(() {});
                        }
                      }
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: Theme.of(context).colorScheme.outline.withAlpha(30),
                  ),
                  _buildModernListTile(
                    context: context,
                    title: t.remark,
                    value: strEmpty(state.groupRemark)
                        ? state.group?.title ?? ''
                        : state.groupRemark,
                    icon: Icons.label_outline,
                    onTap: () async {
                      final result = await context.push<String>(
                        '/group/remark',
                        extra: {
                          'groupInfoType': GroupInfoType.remark,
                          'text': state.groupRemark ?? '',
                          'groupId': widget.groupId,
                        },
                      );
                      if (result != null) {
                        final success = await GroupApi().updateRemark(
                          gid: widget.groupId,
                          remark: result,
                        );
                        if (success) {
                          ref
                              .read(groupDetailProvider.notifier)
                              .setGroupRemark(result);
                        }
                      }
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: Theme.of(context).colorScheme.outline.withAlpha(30),
                  ),
                  // slice-7 (C6 UI) — 群消息免打扰开关
                  GroupNoticeDisabledTile(
                    label: t.muteNotifications,
                    value: _noticeDisabled,
                    onChanged: _gidInt <= 0
                        ? null
                        : (v) async {
                            // 乐观更新 + 持久化；失败回滚
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
                                EasyLoading.showError(t.tipFailed);
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            // 危险操作区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 清空聊天记录
                  _buildModernListTile(
                    context: context,
                    title: t.clearChatRecord,
                    icon: Icons.delete_sweep_outlined,
                    onTap: () {
                      String tips = t.confirmDeleteChatRecord;
                      EasyDialog.showWarning<void>(
                        context: context,
                        title: t.warning,
                        content: Text(tips),
                        confirmText: t.buttonConfirm,
                        cancelText: t.buttonCancel,
                        onConfirm: () async {
                          int cid = await service.cleanMessageByPeerId(
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
                            EasyLoading.showSuccess(t.tipSuccess);
                          } else {
                            EasyLoading.showError(t.tipFailed);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            // 投诉功能
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.borderRadiusRegular,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildModernListTile(
                context: context,
                title: t.complaint,
                icon: Icons.flag_outlined,
                onTap: () => _showComplaintDialog(context),
              ),
            ),
            // 底部操作按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.borderRadiusRegular,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.getIosRed(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.1),
                      AppColors.getIosRed(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(
                    color: AppColors.getIosRed(
                      Theme.of(context).brightness,
                    ).withValues(alpha: 0.2),
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    String tips =
                        "${isGroupOwner(state.role) ? t.sureToDissolveGroup : t.sureToLeaveGroup}\n${t.sureDeleteGroupChatRecord}";

                    EasyDialog.showWarning<void>(
                      context: context,
                      title: t.tipTips,
                      content: Text(tips),
                      confirmText: t.buttonConfirm,
                      cancelText: t.buttonCancel,
                      onConfirm: () async {
                        var nav = Navigator.of(context);
                        bool res = false;
                        if (isGroupOwner(state.role)) {
                          res = await service.dissolve(widget.groupId);
                        } else {
                          res = await service.leave(widget.groupId);
                        }
                        if (res) {
                          EasyLoading.showSuccess(t.tipSuccess);
                          nav.pop();
                          nav.pop();
                        }
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusRegular,
                    ),
                  ),
                  child: Text(
                    isGroupOwner(state.role) ? t.groupDissolve : t.groupLeave,
                    style: TextStyle(
                      color: AppColors.getIosRed(Theme.of(context).brightness),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 现代化的ListTile构建方法
  Widget _buildModernListTile({
    required BuildContext context,
    required String title,
    String? value,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusRegular,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示投诉对话框
  void _showComplaintDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String? selectedReason;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t.complaint),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.pleaseSelect,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              // 投诉原因选项
              _buildComplaintOption(
                context,
                'spam',
                t.complaintReason.spam,
                selectedReason,
                (value) => setState(() => selectedReason = value),
              ),
              _buildComplaintOption(
                context,
                'harassment',
                t.complaintReason.harassment,
                selectedReason,
                (value) => setState(() => selectedReason = value),
              ),
              _buildComplaintOption(
                context,
                'inappropriate',
                t.complaintReason.inappropriate,
                selectedReason,
                (value) => setState(() => selectedReason = value),
              ),
              _buildComplaintOption(
                context,
                'other',
                t.complaintReason.other,
                selectedReason,
                (value) => setState(() => selectedReason = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.buttonCancel),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.of(context).pop();

                      final success = await ReportApi().create(
                        targetType: 'group',
                        targetId: widget.groupId,
                        reason: selectedReason!,
                      );
                      if (success) {
                        EasyLoading.showSuccess(t.complaintSuccess);
                      } else {
                        EasyLoading.showError(t.complaintFailed);
                      }
                    },
              child: Text(t.buttonConfirm),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建投诉选项
  Widget _buildComplaintOption(
    BuildContext context,
    String value,
    String label,
    String? selectedValue,
    void Function(String) onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedValue == value
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
              color: selectedValue == value
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: selectedValue == value
                ? Icon(Icons.check, size: 14, color: colorScheme.primary)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
