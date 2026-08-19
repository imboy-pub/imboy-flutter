import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/widget/user_online_status_widget.dart';

import 'package:go_router/go_router.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_page.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_page.dart';
import 'package:imboy/page/contact/people_info_more/people_info_more_page.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/user_events.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'people_info_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 用户详情页面 - iOS 17 Premium 风格重构
class PeopleInfoPage extends ConsumerStatefulWidget {
  final String id;
  final String scene;

  const PeopleInfoPage({super.key, required this.id, required this.scene});

  @override
  ConsumerState<PeopleInfoPage> createState() => _PeopleInfoPageState();
}

class _PeopleInfoPageState extends ConsumerState<PeopleInfoPage> {
  /// 订阅实时在线状态变更（S2C online/offline/hide → UserStatusChangeEvent）。
  /// 进入页面后对方上下线会实时刷新"在线/最后上线时间"，无需重新进页面。
  StreamSubscription<UserStatusChangeEvent>? _statusSub;

  @override
  void initState() {
    super.initState();
    // 初始化数据（仅注册一次，避免 build 内重复注册回调）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(peopleInfoProvider.notifier).initData(widget.id, widget.scene);
    });
    // 订阅状态变更：仅处理当前页面 peer 的事件，避免串台
    _statusSub = AppEventBus.on<UserStatusChangeEvent>().listen((event) {
      if (event.userId != widget.id) return;
      if (!mounted) return;
      ref.read(peopleInfoProvider.notifier).applyStatusChange(event.status);
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final scene = widget.scene;
    final state = ref.watch(peopleInfoProvider);
    bool isSelf = UserRepoLocal.to.currentUid == id;
    bool isBot = id == 'bot_qian_fan';
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: '',
      useLargeTitle: false,
      actions: isSelf || isBot
          ? null
          : [
              Semantics(
                button: true,
                label: t.common.contactSetting,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.ellipsis, size: 22),
                  onPressed: () => context.push(
                    '/contact_setting/$id',
                    // 统一走 go_router（路由已注册，extra 传参对齐原生构造）：
                    // 原生 push 时页内「删除联系人」成功后 context.go 失灵。
                    // 这里曾把除 peerId 外的 10 个参数全传空串，下游
                    // ContactSettingTagPage 靠 peerTag/peerRemark 回显，
                    // 于是「设置备注和标签」页永远显示「添加标签」+ 空备注，
                    // 哪怕这个联系人明明已有标签。同文件 _openTagPage 的
                    // 传参才是对的，这里对齐。
                    extra: {
                      'peerAvatar': state.avatar,
                      'peerAccount': state.account,
                      'peerNickname': state.nickname,
                      'peerGender': state.gender,
                      'peerTitle': state.title,
                      'peerSign': state.sign,
                      'peerRegion': state.region,
                      'peerSource': state.source,
                      'peerRemark': state.remark,
                      'peerTag': state.tag,
                    },
                  ),
                ),
              ),
            ],
      slivers: [
        // 用户名片 Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.small,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceGroupedTertiary
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContactCard(
                    id: id,
                    remark: state.remark,
                    nickname: state.nickname,
                    account: state.account,
                    avatar: state.avatar,
                    gender: state.gender,
                    region: state.region,
                    heroTag: 'avatar_$id',
                    padding: const EdgeInsets.all(AppSpacing.large),
                    accountType: state.accountType,
                  ),
                  // 在线状态并入信息卡（原独占 Section 合并，提升信息密度）
                  if (!isSelf && !isBot)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        0,
                        AppSpacing.large,
                        AppSpacing.medium,
                      ),
                      child: UserOnlineStatusDetailWidget(
                        isOnline: state.status == 'online',
                        lastSeenTimestamp: state.lastSeenAt,
                        hideOnlineStatus: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 标签设置 Section
        if (!isSelf && !isBot)
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              children: [
                ImBoySettingsTile(
                  title: Text(
                    state.tag.isEmpty ? t.contact.remarksTags : t.contact.tags,
                  ),
                  subtitle: state.tag.isNotEmpty
                      ? Text(
                          state.tag.endsWith(',')
                              ? state.tag.substring(0, state.tag.length - 1)
                              : state.tag,
                        )
                      : null,
                  leading: Icon(
                    CupertinoIcons.tag_fill,
                    color: AppColors.getIosBlue(brightness),
                    size: 20,
                  ),
                  onTap: () => _editTags(context, ref, state),
                ),
              ],
            ),
          ),

        // 更多信息 Section
        if (state.isFriend == 1 || scene == 'denylist')
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              children: [
                ImBoySettingsTile(
                  title: Text(t.common.moreInfo),
                  leading: const Icon(
                    CupertinoIcons.info_circle,
                    color: AppColors.iosGray,
                    size: 20,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) => PeopleInfoMorePage(id: id),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 核心操作 Section
        if (state.isFriend == 1 || scene == 'denylist')
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.regular,
                AppSpacing.xLarge,
                AppSpacing.regular,
                0,
              ),
              children: [
                if (!isSelf)
                  ImBoySettingsTile(
                    title: Text(t.common.messageCall),
                    leading: Icon(
                      CupertinoIcons.chat_bubble_fill,
                      color: AppColors.getIosBlue(brightness),
                      size: 20,
                    ),
                    onTap: () => _goToChat(context, state),
                  ),
                if (state.isFriend == 1 && !isSelf) ...[
                  ImBoySettingsTile(
                    title: Text(t.common.voiceCall),
                    leading: Icon(
                      CupertinoIcons.phone_fill,
                      color: AppColors.getIosGreen(brightness),
                      size: 20,
                    ),
                    onTap: () => _startCall(context, state, 'audio'),
                  ),
                  ImBoySettingsTile(
                    title: Text(t.common.videoCall),
                    leading: Icon(
                      CupertinoIcons.videocam_fill,
                      color: AppColors.getIosGreen(brightness),
                      size: 20,
                    ),
                    onTap: () => _startCall(context, state, 'video'),
                  ),
                ],
              ],
            ),
          ),

        // 添加好友按钮
        if (state.isFriend != 1 && !isSelf && !isBot && scene != 'denylist')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.regular,
                AppSpacing.xxLarge,
                AppSpacing.regular,
                AppSpacing.xxLarge,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: AppColors.primary,
                  disabledColor: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) => ApplyFriendPage(
                        id,
                        state.nickname,
                        state.avatar,
                        state.region,
                        source: state.source,
                      ),
                    ),
                  ),
                  child: Text(
                    t.common.addToContacts,
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

        // 黑名单警告
        if (scene == 'denylist')
          SliverToBoxAdapter(child: _buildWarningTip(context, brightness)),
      ],
    );
  }

  void _editTags(BuildContext context, WidgetRef ref, PeopleInfoState state) {
    Navigator.push(
      context,
      CupertinoPageRoute<String?>(
        builder: (_) => ContactSettingTagPage(
          peerId: widget.id,
          peerAvatar: state.avatar,
          peerAccount: state.account,
          peerNickname: state.nickname,
          peerGender: state.gender,
          peerTitle: state.title,
          peerSign: state.sign,
          peerRegion: state.region,
          peerSource: state.source,
          peerRemark: state.remark,
          peerTag: state.tag,
          onRemarkChanged: (r) =>
              ref.read(peopleInfoProvider.notifier).updateRemark(r),
        ),
      ),
    ).then((v) {
      if (v != null && v.isNotEmpty) {
        ref.read(peopleInfoProvider.notifier).updateRemark(v);
      }
    });
  }

  void _goToChat(BuildContext context, PeopleInfoState state) {
    String title = state.remark.isNotEmpty
        ? state.remark
        : (state.nickname.isNotEmpty ? state.nickname : state.account);
    // 统一走 go_router（/chat/:peerId 路由已支持 extra 双通道传参）：
    // 原生 push 的 ChatPage 内点频道卡片/名片消息、token 失效重登都会失灵
    context.push(
      '/chat/${widget.id}',
      extra: {
        'type': 'C2C',
        'title': title,
        'avatar': state.avatar,
        'sign': state.sign,
      },
    );
  }

  void _startCall(BuildContext context, PeopleInfoState state, String mode) {
    openCallScreen(
      context,
      ContactModel.fromMap({
        "id": widget.id,
        "nickname": state.nickname,
        "avatar": state.avatar,
        "sign": state.sign,
      }),
      mode == 'audio' ? {'media': 'audio'} : {},
    );
  }

  Widget _buildWarningTip(BuildContext context, Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.regular),
        decoration: BoxDecoration(
          color: AppColors.getIosRed(brightness).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.getIosRed(brightness).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: AppColors.getIosRed(brightness),
              size: 24,
            ),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Text(
                t.common.addedToDenylistTips,
                style: context.textStyle(
                  FontSizeType.normal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
