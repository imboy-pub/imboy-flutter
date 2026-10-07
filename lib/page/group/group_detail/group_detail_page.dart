import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/group_notice_config.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:synchronized/synchronized.dart';

import 'package:imboy/page/group/group_detail/widgets/group_app_grid.dart';
import 'package:imboy/page/group/group_detail/widgets/group_app_items.dart';
import 'package:imboy/page/group/group_detail/widgets/group_danger_zone.dart';
import 'package:imboy/page/group/group_detail/widgets/group_info_card.dart';
import 'package:imboy/page/group/group_detail/widgets/group_member_section.dart';
import 'package:imboy/page/group/group_detail/widgets/group_preferences_section.dart';

import 'change_info_page.dart';
import 'group_detail_provider.dart';
import 'group_detail_service.dart';

/// 群组详情页面 - iOS 17 Premium 风格
///
/// 信息架构（自上而下，对标微信群设置 + QQ 群应用）：
///   1. 群信息卡片（头像/群名/简介/成员数 → 编辑）
///   2. 群成员横滑区（头像列表 + 添加/移除 + 查看全部）
///   3. 群应用九宫格（公告/文件/相册/投票/日程/任务/标签/分类/二维码）
///   4. 偏好设置（免打扰/群昵称/群备注/搜索）
///   5. 危险操作（清空记录/投诉）
///   6. 退出/解散按钮
///
/// ENT-APP-02 等价拆分（799 行 → 编排壳）：本文件只保留页面编排
/// （数据装载/事件订阅/生命周期）；各分区渲染与动作搬至 widgets/：
///   - GroupMemberSection      成员横滑区
///   - GroupPreferencesSection 偏好设置（昵称/备注/免打扰/E2EE/搜索）
///   - GroupDangerZone         清空记录/投诉/退出/解散
///   - buildGroupAppItems      九宫格入口构建
///   - GroupInfoCard           群信息卡片（既有拆分）
/// 权限判定（isGroupAdmin/isGroupOwner）、确认对话与成功/失败路径
/// 与拆分前逐行等价（行为矩阵测试钉死，见
/// test/unit_test/page/group/group_detail/group_detail_behavior_matrix_test.dart）。
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
  bool _groupE2ee = false;

  int get _gidInt => int.tryParse(widget.groupId) ?? 0;

  @override
  void initState() {
    super.initState();
    _noticeDisabled = readNoticeDisabled(
      _gidInt,
      readBool: StorageService.to.getBool,
    );
    // initData 首步即 notifier.setLoading(true) 修改 provider，若在 initState 同步
    // 阶段（widget 树构建中）调用会触发 Riverpod "Tried to modify a provider while
    // the widget tree was building" 错误 → 加载中断、isLoading 卡在 true、group 永久
    // null → 群详情页永久 loading 转圈。延迟到首帧渲染后再启动加载。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(initData());
    });
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

  /// AvatarList 完全靠 `account == 'add'/'remove'` 这两个伪成员来渲染「＋」「－」
  /// 按钮（avatar_list.dart:50-77），而 `/group/add_member`、`/group/remove_member`
  /// **没有任何其他入口**。所以每一次 setMemberList 都必须带上它们——
  /// 曾经网络同步那趟漏了，导致群主打开群详情后加/移成员按钮直接消失。
  List<PeopleModel> _withActionSlots(
    List<PeopleModel> members, {
    required bool isAdmin,
  }) {
    return [
      ...members,
      PeopleModel(id: -1, account: 'add'),
      if (isAdmin) PeopleModel(id: -2, account: 'remove'),
    ];
  }

  /// 把成员数抬到 `count`（仅当更大时）。只用于本地列表条数这类**下界**证据，
  /// 服务端权威值不走这里——那个要能升也能降。
  void _liftMemberCount(int count) {
    if (count > ref.read(groupDetailProvider).memberCount) {
      ref.read(groupDetailProvider.notifier).setMemberCount(count);
    }
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
      int role = await service.role(
        gid: widget.groupId,
        userId: UserRepoLocal.to.currentUid,
      );
      bool isAdmin = isGroupAdmin(role);
      notifier.setRoleInfo(role, isAdmin);
      notifier.setMemberList(_withActionSlots(memberList, isAdmin: isAdmin));
      // 调用方传进来的 memberCount 普遍是陈旧值或硬编码 0（见 group_select_page），
      // 实际拿到的成员条数是可信下界，取较大者兜底。
      _liftMemberCount(memberList.length);

      GroupMemberModel? m = await service.getMyGroupMemberInfo(widget.groupId);
      if (m != null) notifier.setMyGroupAlias(m.alias);
      _groupE2ee = await GroupSessionService.to.isGroupE2EE(widget.groupId);
    } finally {
      notifier.setLoading(false);
    }

    service.detail(gid: widget.groupId, sync: connected).then((g) async {
      if (g != null) {
        // 服务端是权威，有效值直接采信——**可升可降**，群解散成员后要能减下来。
        // 只有 memberCount==0 才拒绝：群必有成员，0 只可能是存量字段没维护住，
        // 拿它覆盖会让头部显示「0 群成员」而下面明明渲染着 2 个人。
        // 聊天页 groupTitle 早有同款 `> 0` 守卫，这里口径对齐。
        if (g.memberCount > 0) {
          ref.read(groupDetailProvider.notifier).setMemberCount(g.memberCount);
        }
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
          notifier.setMemberList(
            _withActionSlots(
              memberList,
              isAdmin: ref.read(groupDetailProvider).isAdmin,
            ),
          );
        }
        // 群详情同步会更新本地 E2EE 旗标（group_api.detail），此处回读刷新开关
        _groupE2ee = await GroupSessionService.to.isGroupE2EE(widget.groupId);
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

  /// 免打扰开关变化（GroupPreferencesSection 上抛）：setState + KV 落库
  /// + 会话列投影 + 失败回滚。与拆分前 build 内联闭包逐行等价。
  Future<void> _onNoticeDisabledChanged(bool v) async {
    final prev = _noticeDisabled;
    setState(() => _noticeDisabled = v);
    try {
      await setNoticeDisabled(
        _gidInt,
        v,
        writeBool: (k, val) async => StorageService.to.setBool(k, val),
      );
    } catch (e) {
      iPrint('[GroupDetail] 设置消息免打扰失败: $e');
      if (mounted) {
        setState(() => _noticeDisabled = prev);
        AppLoading.showError(t.common.tipFailed);
      }
      return;
    }
    // Q09/G1（AC22 免打扰）：KV 真源写入成功后，把状态投影到
    // conversation.is_muted 列（会话列表免打扰角标与通知管线主源读列）。
    // 投影失败只记日志、不回滚开关：通知抑制语义已由管线侧 KV 合并
    // （message.dart isGroupDndActive）兜底，漂移只影响角标显示，
    // 下次开关变化即收敛。
    await _syncMuteColumnProjection(v);
  }

  /// 把群免打扰状态投影到 conversation.is_muted 列（C2G 会话行存在时）。
  ///
  /// 会话行由首条群消息 upsert 创建——行不存在（还没收到过该群消息）
  /// 时直接返回，由管线侧 KV 合并判定兜底。
  Future<void> _syncMuteColumnProjection(bool muted) async {
    try {
      final repo = ConversationRepo();
      final conv = await repo.findByPeerId('C2G', widget.groupId);
      if (conv == null || conv.id == 0) return;
      await repo.updateById(conv.id, {ConversationRepo.isMuted: muted ? 1 : 0});
    } catch (e) {
      iPrint('[GroupDetail] 免打扰列投影同步失败（不影响抑制语义）: $e');
    }
  }

  void _confirmEnableE2ee() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.group.e2eeTitle),
        content: Text(t.group.e2eeEnableConfirm),
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
              final ok = await GroupApi().setE2eeMode(gid: widget.groupId);
              if (ok && mounted) {
                setState(() => _groupE2ee = true);
                AppLoading.showSuccess(t.common.tipSuccess);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupDetailProvider);

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
                GroupMemberSection(
                  groupId: widget.groupId,
                  onMemberRemoved: () => backDoRefresh = true,
                ),

                // 3. 群应用九宫格
                GroupAppGrid(
                  items: buildGroupAppItems(
                    context,
                    widget.groupId,
                    state.group,
                    isMounted: () => mounted,
                  ),
                ),

                // 4. 偏好设置 Section
                GroupPreferencesSection(
                  groupId: widget.groupId,
                  title: widget.title,
                  gidInt: _gidInt,
                  role: state.role,
                  noticeDisabled: _noticeDisabled,
                  groupE2ee: _groupE2ee,
                  onNoticeDisabledChanged: _onNoticeDisabledChanged,
                  onEnableE2ee: _confirmEnableE2ee,
                  options: widget.options,
                ),

                // 5+6. 危险操作 Section + 退出/解散按钮
                GroupDangerZone(
                  groupId: widget.groupId,
                  role: state.role,
                  onDirty: () => backDoRefresh = true,
                ),
              ],
            ),
    );
  }
}
