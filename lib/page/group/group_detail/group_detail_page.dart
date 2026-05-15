import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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
import 'package:synchronized/synchronized.dart';

import 'package:imboy/config/enum.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'change_info_page.dart';
import 'group_detail_provider.dart';
import 'group_detail_service.dart';
import 'group_notice_disabled_tile.dart';

/// 群组详情页面 - iOS 17 Premium 风格重构
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
    var connectivityResult = await Connectivity().checkConnectivity();
    bool connected = !connectivityResult.contains(ConnectivityResult.none);

    notifier.setTitle(widget.title);
    notifier.setMemberCount(widget.memberCount);

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
    bool isAdmin = isGroupAdmin(role);
    notifier.setRoleInfo(role, isAdmin);
    if (isAdmin) memberList.add(PeopleModel(id: -2, account: 'remove'));
    notifier.setMemberList(memberList);

    GroupMemberModel? m = await service.getMyGroupMemberInfo(widget.groupId);
    if (m != null) notifier.setMyGroupAlias(m.alias);

    service.detail(gid: widget.groupId, sync: connected).then((g) async {
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
        if (mounted) setState(() {});
      }
    });

    ssMsgExt ??= AppEventBus.on<ChatExtendEvent>().listen((obj) async {
      if (obj.type == 'join_group' &&
          obj.payload['groupId'] == widget.groupId &&
          (obj.payload['isFirst'] ?? false)) {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupDetailProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: state.title.isEmpty ? t.chat.chatMessage : state.title,
      useLargeTitle: false,
      child: Column(
        children: [
          // 成员列表 Section
          _buildMemberSection(state),

          // 基本设置 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.group.groupName),
                trailing: Text(
                  state.title.isEmpty ? t.main.unnamed : state.title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () async {
                  GroupModel? group = await GroupDetailService().find(
                    widget.groupId,
                  );
                  if (group != null && mounted)
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => ChangeInfoPage(
                          group: group,
                          title: t.group.groupName,
                          subtitle: t.common.pleaseEnterContent,
                        ),
                      ),
                    );
                },
              ),
              ImBoySettingsTile(
                title: Text(t.account.groupQrcode),
                leading: const Icon(
                  CupertinoIcons.qrcode,
                  color: AppColors.iosGray,
                  size: 20,
                ),
                onTap: () async {
                  GroupModel? group = await GroupDetailService().find(
                    widget.groupId,
                  );
                  if (group != null && mounted)
                    context.push('/qrcode/group', extra: {'group': group});
                },
              ),
              ImBoySettingsTile(
                title: Text(t.common.groupAnnouncement),
                onTap: () => context.push(
                  '/group/announcement',
                  extra: {'groupId': widget.groupId},
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.chat.groupFile),
                onTap: () => context.push('/group/${widget.groupId}/file'),
              ),
              ImBoySettingsTile(
                title: Text(t.group.groupAlbum),
                onTap: () => context.push('/group/${widget.groupId}/album'),
              ),
            ],
          ),

          // 搜索 Section
          ImBoySettingsSection(
            children: [
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

          // 偏好设置 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.group.groupAlias),
                trailing: Text(
                  strEmpty(state.myGroupAlias)
                      ? UserRepoLocal.to.current.nickname
                      : state.myGroupAlias!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
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
                    await GroupDetailService().updateMyGroupAlias(
                      widget.groupId,
                      result,
                    );
                    ref
                        .read(groupDetailProvider.notifier)
                        .setMyGroupAlias(result);
                  }
                },
              ),
              ImBoySettingsTile(
                title: Text(t.contact.remark),
                trailing: Text(
                  strEmpty(state.groupRemark)
                      ? state.group?.title ?? ''
                      : state.groupRemark!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () async {
                  final result = await context.push<String>(
                    '/group/remark',
                    extra: {
                      'groupInfoType': GroupInfoType.remark,
                      'text': state.groupRemark ?? '',
                      'groupId': widget.groupId,
                    },
                  );
                  if (result != null &&
                      await GroupApi().updateRemark(
                        gid: widget.groupId,
                        remark: result,
                      ))
                    ref
                        .read(groupDetailProvider.notifier)
                        .setGroupRemark(result);
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
                            EasyLoading.showError(t.common.tipFailed);
                          }
                        }
                      },
              ),
            ],
          ),

          // 聊天操作 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.common.clearChatRecord),
                destructive: true,
                onTap: () => _confirmClearChat(),
              ),
            ],
          ),

          // 投诉 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.complaint.complaint),
                onTap: () => _showComplaintDialog(context),
              ),
            ],
          ),

          // 退出/解散按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSection(dynamic state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white,
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
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${state.memberCount}',
                style: const TextStyle(fontSize: 15, color: AppColors.iosGray),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AvatarList(
            memberList: state.memberList,
            width: 52,
            height: 52,
            column: (MediaQuery.of(context).size.width - 72) ~/ 64,
            onTapAvatar: (p) => context.push(
              '/people_info/${p.id}',
              extra: {'scene': 'group_member'},
            ),
            onTapAdd: () => context.push(
              '/group/add_member',
              extra: {'groupId': widget.groupId},
            ),
            onTapRemove: () async {
              final res = await context.push<List<GroupMemberModel>>(
                '/group/remove_member',
                extra: {'groupId': widget.groupId},
              );
              if (res != null) {
                for (var gm in res)
                  ref
                      .read(groupDetailProvider.notifier)
                      .removeMember(gm.userId);
                backDoRefresh = true;
              }
            },
          ),
          if (state.memberCount > 20) ...[
            const SizedBox(height: 12),
            Center(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(
                  t.common.viewAllGroupMember,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => context.push(
                  '/group/member',
                  extra: {'groupId': widget.groupId},
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmClearChat() {
    showCupertinoDialog(
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
                EasyLoading.showSuccess(t.common.tipSuccess);
              } else
                EasyLoading.showError(t.common.tipFailed);
            },
          ),
        ],
      ),
    );
  }

  void _confirmExitGroup(dynamic state) {
    String tips =
        "${isGroupOwner(state.role) ? t.group.sureToDissolveGroup : t.group.sureToLeaveGroup}\n${t.common.sureDeleteGroupChatRecord}";
    showCupertinoDialog(
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
                EasyLoading.showSuccess(t.common.tipSuccess);
                nav.pop();
                nav.pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showComplaintDialog(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.complaint.complaint),
        actions: [
          _action(ctx, 'spam', t.complaintReason.spam),
          _action(ctx, 'harassment', t.complaintReason.harassment),
          _action(ctx, 'inappropriate', t.complaintReason.inappropriate),
          _action(ctx, 'other', t.complaintReason.other),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(t.common.buttonCancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _action(
    BuildContext ctx,
    String val,
    String label,
  ) {
    return CupertinoActionSheetAction(
      onPressed: () async {
        Navigator.pop(ctx);
        if (await ReportApi().create(
          targetType: 'group',
          targetId: widget.groupId,
          reason: val,
        ))
          EasyLoading.showSuccess(t.common.complaintSuccess);
        else
          EasyLoading.showError(t.common.complaintFailed);
      },
      child: Text(label),
    );
  }
}
