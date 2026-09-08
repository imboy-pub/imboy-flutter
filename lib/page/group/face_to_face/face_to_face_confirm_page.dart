import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_shadows.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 面对面建群确认页面 - 极致 iOS 17 Premium 风格
class FaceToFaceConfirmPage extends ConsumerStatefulWidget {
  final String gid;
  final String code;
  final List<PeopleModel> memberList;

  const FaceToFaceConfirmPage({
    super.key,
    required this.gid,
    required this.code,
    required this.memberList,
  });

  @override
  ConsumerState<FaceToFaceConfirmPage> createState() =>
      FaceToFaceConfirmPageState();
}

class FaceToFaceConfirmPageState extends ConsumerState<FaceToFaceConfirmPage> {
  List<PeopleModel> memberList = [];
  StreamSubscription<dynamic>? ssMsg;
  StreamSubscription<dynamic>? _localeSubscription;
  bool _isJoiningGroup = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    initData();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    _wasOffline = !NetworkMonitorService.to.hasNetwork;
    NetworkMonitorService.to.addNetworkChangeListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    // 此处曾无条件 AppLoading.dismiss()：失败路径刚弹出的服务端错误 toast
    // 会被页面卸载兜底清掉（用户永远看不到失败原因），且在 deactivated
    // widget 状态下 dismiss 会在 EasyLoading overlay 上抛
    // "Looking up a deactivated widget's ancestor is unsafe" 未捕获异常
    // （批次123 GF8 实证崩测试绑定）。loading 的收尾已由按钮回调的
    // finally 负责（成功 dismiss / 失败靠 toast 自身 duration），这里不能再碰。
    ssMsg?.cancel();
    _localeSubscription?.cancel();
    NetworkMonitorService.to.removeNetworkChangeListener(_onNetworkChanged);
    super.dispose();
  }

  void _onNetworkChanged(NetworkType oldType, NetworkType networkType) {
    final isOnline = networkType != NetworkType.none;
    if (isOnline && _wasOffline) _syncMembersFromServer();
    _wasOffline = !isOnline;
  }

  Future<void> _syncMembersFromServer() async {
    if (widget.gid.isEmpty) return;
    try {
      final payload = await GroupMemberApi().page(
        gid: widget.gid,
        page: 1,
        size: 200,
      );
      if (payload == null || !mounted) return;
      final list = payload['list'];
      if (list is! List) return;
      final existingIds = memberList.map((m) => m.id).toSet();
      bool hasNewMembers = false;
      for (final item in list) {
        if (item is! Map) continue;
        final uid = parseModelInt(item['user_id']);
        if (uid == 0 || existingIds.contains(uid)) continue;
        memberList.insert(
          0,
          PeopleModel(
            id: uid,
            account: item['account']?.toString() ?? '',
            avatar: item['avatar']?.toString() ?? '',
            nickname:
                item['alias']?.toString() ?? item['nickname']?.toString() ?? '',
          ),
        );
        existingIds.add(uid);
        hasNewMembers = true;
      }
      if (hasNewMembers && mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> initData() async {
    memberList = List.from(widget.memberList);
    memberList.add(PeopleModel(id: -1, account: ''));
    ssMsg ??= AppEventBus.on<ChatExtendEvent>().listen((
      ChatExtendEvent obj,
    ) async {
      if (obj.type == 'join_group') {
        // S2C 链的 payload['userId'] 是 String（parseModelString 产物），
        // memberList 的 PeopleModel.id 是 int——`int == String` 恒 false，
        // 去重恒失效：服务端对同一次加入的重复推送（实测一次 B 加入连推
        // 3 条不同 msgId）会把对端成员重复插入，人数膨胀（批次127 GF5
        // 实测 1→4 而非 1→2，且曾被误判为「确认页消失」）。统一转 int 再比。
        final i = memberList.indexWhere(
          (e) =>
              e.id == parseModelInt(obj.payload['userId']) &&
              widget.gid == obj.payload['groupId'],
        );
        if (i == -1) {
          memberList.insert(0, obj.payload['people'] as PeopleModel);
          if (mounted) setState(() {});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: t.chat.createGroupF2f,
      useLargeTitle: false,
      backgroundColor: isDark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      bottomWidget: _buildBottomButton(context, theme),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xLarge),
          _buildCodeChip(context),
          const SizedBox(height: AppSpacing.medium),
          _buildNumberDisplay(context, widget.code, isDark, brightness),
          const SizedBox(height: AppSpacing.regular),
          _buildLiveMemberCount(context, brightness),
          const SizedBox(height: AppSpacing.large),
          Text(
            t.common.createGroupF2fConfirmTips,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.iosGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
            padding: const EdgeInsets.all(AppSpacing.large),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceGroupedTertiary
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: AvatarList(
              memberList: memberList,
              column: (MediaQuery.of(context).size.width - 72) ~/ 64,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxLarge),
        ],
      ),
    );
  }

  Widget _buildCodeChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.lock_fill, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            t.common.f2fSecretCode,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberDisplay(
    BuildContext context,
    String code,
    bool isDark,
    Brightness brightness,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: code.split('').map((char) {
        return Container(
          width: 64,
          height: 72,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.cardForBrightness(brightness),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            char,
            style: context.textStyle(
              FontSizeType.extraLargeTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveMemberCount(BuildContext context, Brightness brightness) {
    final count = memberList.where((m) => m.id != -1).length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _LiveDot(),
        const SizedBox(width: 6),
        Text(
          t.common.f2fEnteringGroup(count: count),
          style: context.textStyle(
            FontSizeType.footnote,
            color: AppColors.getIosGreen(brightness),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          minimumSize: const Size(0, 50),
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(14),
          onPressed: _isJoiningGroup
              ? null
              : () async {
                  setState(() => _isJoiningGroup = true);
                  // 失败时不能走 finally 的 dismiss：API 层已把服务端失败
                  // 原因（如 gid not exist）作为 error toast 弹出，dismiss
                  // 会把它立刻清掉，用户永远看不到失败提示（批次123 GF8）。
                  // toast 自带 duration 会自动消失，故失败路径跳过 dismiss。
                  var failed = false;
                  try {
                    AppLoading.show(status: t.common.loading);
                    final res = await ref
                        .read(faceToFaceProvider.notifier)
                        .faceToFaceSave(widget.gid, widget.code);
                    List<PeopleModel> memberList =
                        res['memberList'] as List<PeopleModel>? ?? [];
                    Map<String, dynamic> group =
                        res['group'] as Map<String, dynamic>;
                    // groupFace2faceSave 对服务端失败（如匹配码失效 gid not
                    // exist）吞错返回空 map——空 group 意味着建群未成功，
                    // 必须留在本页（错误 toast 已由 API 层弹出），否则会
                    // 带着空群信息跳进聊天页并向本地库插 id=0 脏行。
                    if (group.isEmpty) {
                      failed = true;
                      iPrint('[FaceToFaceConfirm] save 返回空 group，视为失败');
                      return;
                    }
                    await GroupRepo().save('', group);
                    // `?? ''` 只挡得住 null —— 无名群后端返回的 title 就是**空字符串**，
                    // 于是空串一路传到聊天页，标题栏整个是空的（QA#60，比显示 gid 还糟）。
                    // 兜底策略与 GroupModel.displayTitle 保持一致：回退「未命名」，
                    // 且绝不回退到 gid。
                    // 注意不要写成 `group['title'] as String?` —— 后端返回的
                    // title 未必是 String，`as` 会抛 TypeError 并被下面的
                    // catch(_) 吞掉，表现为「点进入该群完全没反应」（实测踩过）。
                    final rawTitle = (group['title'] ?? '').toString().trim();
                    final chatTitle = rawTitle.isNotEmpty
                        ? rawTitle
                        : t.main.unnamed;
                    if (context.mounted) {
                      context.pushReplacement(
                        '/chat/${widget.gid}',
                        extra: {
                          'type': 'C2G',
                          'title': chatTitle,
                          'avatar': group['avatar'] ?? '',
                          'sign': group['introduction'] ?? '',
                          'memberCount': memberList.length,
                        },
                      );
                    }
                  } catch (e) {
                    failed = true;
                    iPrint('[FaceToFaceConfirm] 入群失败: $e');
                    AppLoading.showError(t.common.tipFailed);
                  } finally {
                    if (!failed) AppLoading.dismiss();
                    if (mounted) setState(() => _isJoiningGroup = false);
                  }
                },
          child: _isJoiningGroup
              ? CupertinoActivityIndicator(color: AppColors.onPrimary)
              : Text(
                  t.group.enterTheGroup,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    child: Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.iosGreen,
        shape: BoxShape.circle,
      ),
    ),
  );
}
