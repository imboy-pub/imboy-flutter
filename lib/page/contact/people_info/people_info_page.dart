import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/widget/user_online_status_widget.dart';

import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_page.dart';
import 'package:imboy/page/contact/contact_setting/contact_setting_page.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_page.dart';
import 'package:imboy/page/contact/people_info_more/people_info_more_page.dart';
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
  @override
  void initState() {
    super.initState();
    // 初始化数据（仅注册一次，避免 build 内重复注册回调）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(peopleInfoProvider.notifier).initData(widget.id, widget.scene);
    });
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
                  onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) => ContactSettingPage(
                        peerId: id,
                        peerAvatar: '',
                        peerAccount: '',
                        peerNickname: '',
                        peerGender: 0,
                        peerTitle: '',
                        peerSign: '',
                        peerRegion: '',
                        peerSource: '',
                        peerRemark: '',
                        peerTag: '',
                      ),
                    ),
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
              child: ContactCard(
                id: id,
                remark: state.remark,
                nickname: state.nickname,
                account: state.account,
                avatar: state.avatar,
                gender: state.gender,
                region: state.region,
                heroTag: 'avatar_$id',
                padding: const EdgeInsets.all(AppSpacing.large),
              ),
            ),
          ),
        ),

        // 在线状态 Section
        if (!isSelf && !isBot)
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.regular,
                AppSpacing.small,
                AppSpacing.regular,
                0,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.tiny,
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
    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => ChatPage(
          peerId: widget.id,
          peerTitle: title,
          peerAvatar: state.avatar,
          peerSign: state.sign,
          type: 'C2C',
        ),
      ),
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
