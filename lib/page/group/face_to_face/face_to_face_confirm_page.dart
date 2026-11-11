import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 展示匹配成员，并复用资料页的好友申请流程。
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
  bool _syncing = false;
  int _memberRevision = 0;
  Timer? _refreshTimer;
  String _error = '';
  String _memberError = '';

  @override
  void initState() {
    super.initState();
    initData();
    _syncMembersFromServer();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _syncMembersFromServer(),
    );
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    _wasOffline = !NetworkMonitorService.to.hasNetwork;
    NetworkMonitorService.to.addNetworkChangeListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
    if (_syncing || widget.gid.isEmpty) return;
    _syncing = true;
    final revision = _memberRevision;
    try {
      final members = <String, PeopleModel>{};
      for (var page = 1; ; page++) {
        final payload = await GroupMemberApi().page(
          gid: widget.gid,
          page: page,
          size: 200,
        );
        if (!mounted) return;
        final list = payload?['list'];
        if (list is! List) throw const FormatException('missing members');
        for (final item in list.whereType<Map<String, dynamic>>()) {
          if ('${item['status'] ?? 1}' != '1') continue;
          final uid = '${item['user_id'] ?? ''}';
          if (uid.isEmpty || uid == '0') continue;
          final alias = '${item['alias'] ?? ''}'.trim();
          final nickname = '${item['nickname'] ?? ''}'.trim();
          members[uid] = PeopleModel(
            id: uid,
            account: '${item['account'] ?? ''}',
            avatar: '${item['avatar'] ?? ''}',
            nickname: alias.isNotEmpty
                ? alias
                : nickname.isNotEmpty
                ? nickname
                : t.main.unnamed,
          );
        }
        final total = int.tryParse('${payload?['total'] ?? ''}');
        if (list.length < 200 || total != null && page * 200 >= total) break;
      }
      if (revision != _memberRevision) return;
      setState(() {
        memberList = members.values.toList();
        _memberError = '';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _memberError = t.common.retryFailedPleaseCheckNetwork);
      }
    } finally {
      _syncing = false;
    }
  }

  void initData() {
    memberList = List.of(widget.memberList);
    ssMsg = AppEventBus.on<ChatExtendEvent>().listen((event) {
      if (event.type != 'join_group' ||
          '${event.payload['groupId']}' != widget.gid) {
        return;
      }
      final people = event.payload['people'];
      if (people is! PeopleModel || people.id.isEmpty || people.id == '0') {
        return;
      }
      if (memberList.any((member) => member.id == people.id)) return;
      if (mounted) {
        setState(() {
          _memberRevision++;
          memberList = [people, ...memberList];
        });
      }
    });
  }

  Future<void> _enterGroup() async {
    if (_isJoiningGroup) return;
    setState(() {
      _isJoiningGroup = true;
      _error = '';
    });
    try {
      final result = await ref
          .read(faceToFaceProvider.notifier)
          .faceToFaceSave(widget.gid, widget.code);
      final group = result['group'] as Map<String, dynamic>;
      if ('${group['id'] ?? ''}' != widget.gid) {
        throw const FormatException('mismatched group');
      }
      await GroupRepo().save('', group);
      if (!mounted) return;
      final title = '${group['title'] ?? ''}'.trim();
      context.pushReplacement(
        '/chat/${widget.gid}',
        extra: {
          'type': 'C2G',
          'title': title.isEmpty ? t.main.unnamed : title,
          'avatar': group['avatar'] ?? '',
          'sign': group['introduction'] ?? '',
          'memberCount': (result['memberList'] as List<PeopleModel>).length,
        },
      );
    } catch (error) {
      iPrint('[FaceToFaceConfirm] 入群失败: $error');
      if (mounted) {
        setState(
          () => _error = error is HttpException
              ? error.message
              : t.common.tipFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isJoiningGroup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: t.chat.createGroupF2f,
      useLargeTitle: false,
      contentMaxWidth: 480,
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
            t.common.f2fMemberHint,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.getTextSecondary(brightness),
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
            child: LayoutBuilder(
              builder: (context, constraints) => AvatarList(
                memberList: memberList,
                column: (constraints.maxWidth / 72).floor().clamp(1, 5),
                onTapAvatar: (person) =>
                    person.id == UserRepoLocal.to.currentUid
                    ? context.push('/personal_info/profile')
                    : context.push(
                        '/people_info/${person.id}',
                        extra: {'scene': 'group_member'},
                      ),
              ),
            ),
          ),
          if (_error.isNotEmpty || _memberError.isNotEmpty)
            Padding(
              padding: AppSpacing.allRegular,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error.isEmpty ? _memberError : _error,
                  textAlign: TextAlign.center,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.getDestructiveText(brightness),
                  ),
                ),
              ),
            ),
          CupertinoButton(
            onPressed: _syncing ? null : _syncMembersFromServer,
            child: Text(t.common.retry),
          ),
          const SizedBox(height: AppSpacing.xxxLarge),
        ],
      ),
    );
  }

  Widget _buildCodeChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.tiny,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.lock_fill,
            size: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.getIosBlue(Brightness.dark)
                : AppColors.primaryDark,
          ),
          const SizedBox(width: AppSpacing.tiny),
          Text(
            t.common.f2fSecretCode,
            style: context.textStyle(
              FontSizeType.footnote,
              color: Theme.of(context).colorScheme.onSurface,
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
    final boxSize =
        ((MediaQuery.sizeOf(context).width - AppSpacing.xxLarge) / 4 -
                AppSpacing.regular)
            .clamp(40.0, 64.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: code.split('').map((char) {
        return Container(
          width: boxSize,
          constraints: BoxConstraints(minHeight: boxSize),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
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
              color: AppColors.getIosBlue(brightness),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveMemberCount(BuildContext context, Brightness brightness) {
    final count = memberList.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          CupertinoIcons.person_2,
          size: 16,
          color: AppColors.getTextSecondary(brightness),
        ),
        const SizedBox(width: AppSpacing.small),
        Flexible(
          child: Text(
            t.common.f2fEnteringGroup(count: count),
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.getTextSecondary(brightness),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(BuildContext context, ThemeData theme) {
    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: AppSpacing.allRegular,
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                minimumSize: const Size(0, 50),
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(AppSpacing.medium),
                onPressed: _isJoiningGroup ? null : _enterGroup,
                child: _isJoiningGroup
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(
                            color: AppColors.onPrimary,
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Text(t.common.loading),
                        ],
                      )
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
          ),
        ),
      ),
    );
  }
}
