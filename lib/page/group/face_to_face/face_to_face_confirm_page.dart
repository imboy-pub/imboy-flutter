import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/component/helper/func.dart';
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
import 'package:imboy/theme/default/app_radius.dart';

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
  ConsumerState<FaceToFaceConfirmPage> createState() => FaceToFaceConfirmPageState();
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
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) => mounted ? setState(() {}) : null);
    _wasOffline = !NetworkMonitorService.to.hasNetwork;
    NetworkMonitorService.to.addNetworkChangeListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
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
      final payload = await GroupMemberApi().page(gid: widget.gid, page: 1, size: 200);
      if (payload == null || !mounted) return;
      final list = payload['list'];
      if (list is! List) return;
      final existingIds = memberList.map((m) => m.id).toSet();
      bool hasNewMembers = false;
      for (final item in list) {
        if (item is! Map) continue;
        final uid = parseModelInt(item['user_id']);
        if (uid == 0 || existingIds.contains(uid)) continue;
        memberList.insert(0, PeopleModel(id: uid, account: item['account']?.toString() ?? '', avatar: item['avatar']?.toString() ?? '', nickname: item['alias']?.toString() ?? item['nickname']?.toString() ?? ''));
        existingIds.add(uid);
        hasNewMembers = true;
      }
      if (hasNewMembers && mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> initData() async {
    memberList = List.from(widget.memberList);
    memberList.add(PeopleModel(id: -1, account: ''));
    ssMsg ??= AppEventBus.on<ChatExtendEvent>().listen((ChatExtendEvent obj) async {
      if (obj.type == 'join_group') {
        final i = memberList.indexWhere((e) => e.id == obj.payload['userId'] && widget.gid == obj.payload['groupId']);
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
      title: '',
      useLargeTitle: false,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      bottomWidget: _buildBottomButton(context, theme),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildNumberDisplay(context, widget.code),
          const SizedBox(height: 12),
          Text(t.common.createGroupF2fConfirmTips, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.iosGray, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: AvatarList(
              memberList: memberList,
              column: (MediaQuery.of(context).size.width - 72) ~/ 64,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNumberDisplay(BuildContext context, String code) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: code.split('').map((char) {
        return Container(
          width: 56, height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Text(char, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary)),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isJoiningGroup ? null : () async {
            setState(() => _isJoiningGroup = true);
            try {
              EasyLoading.show(status: t.common.loading);
              final res = await ref.read(faceToFaceProvider.notifier).faceToFaceSave(widget.gid, widget.code);
              List<PeopleModel> memberList = res['memberList'] as List<PeopleModel>? ?? [];
              Map<String, dynamic> group = res['group'] as Map<String, dynamic>;
              await GroupRepo().save('', group);
              if (context.mounted) context.pushReplacement('/chat/${widget.gid}', extra: {'type': 'C2G', 'title': group['title'] ?? '', 'avatar': group['avatar'] ?? '', 'sign': group['introduction'] ?? '', 'memberCount': memberList.length});
            } catch (_) { EasyLoading.showError(t.common.tipFailed); }
            finally { EasyLoading.dismiss(); if (mounted) setState(() => _isJoiningGroup = false); }
          },
          child: _isJoiningGroup ? const CupertinoActivityIndicator(color: Colors.white) : Text(t.group.enterTheGroup, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
