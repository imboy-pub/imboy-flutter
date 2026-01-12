import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/widget/user_online_status_widget.dart';

import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_view.dart';
import 'package:imboy/page/contact/contact_setting/contact_setting_view.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_view.dart';
import 'package:imboy/page/contact/people_info_more/people_info_more_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'people_info_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

// ignore: must_be_immutable
class PeopleInfoPage extends StatelessWidget {
  final String id; // 用户ID
  final String scene; // denylist or other value

  PeopleInfoPage({
    super.key,
    required this.id,
    required this.scene,
  });

  final logic = Get.put(PeopleInfoLogic());
  final state = Get.find<PeopleInfoLogic>().state;

  /// 初始化数据
  Future<void> initData() async {
    logic.initData(id, scene);
  }

  /// 构建操作卡片
  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark
            ? Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
                width: 0.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标签卡片
  Widget _buildTagCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark
            ? Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
                width: 0.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Get.to(
              () => ContactSettingTagPage(
                peerId: id,
                peerAvatar: state.avatar.value,
                peerAccount: state.account.value,
                peerNickname: state.nickname.value,
                peerGender: state.gender.value,
                peerTitle: state.title.value,
                peerSign: state.sign.value,
                peerRegion: state.region.value,
                peerSource: state.source.value,
                peerRemark: state.remark.value,
                peerTag: state.tag,
              ),
              transition: Transition.rightToLeft,
              popGesture: true,
            )?.then((value) {
              debugPrint("PeopleInfoPage_ContactSettingTagPage_back then $value");
              if (value != null && value is String && value.isNotEmpty) {
                state.remark.value = value.toString();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.tag.value.isEmpty ? t.remarksTags : t.tags,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
                if (state.tag.value.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.tag.value.endsWith(',')
                        ? state.tag.value.substring(0, state.tag.value.length - 1)
                        : state.tag.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建添加好友按钮
  Widget _buildAddFriendButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => Get.to(
          () => ApplyFriendPage(
            id,
            state.nickname.value,
            state.avatar.value,
            state.region.value,
            source: state.source.value,
          ),
          transition: Transition.rightToLeft,
          popGesture: true,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          t.addToContacts,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 构建警告提示
  Widget _buildWarningTip(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.addedToDenylistTips,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    initData();
    bool isSelf = UserRepoLocal.to.currentUid == id;
    bool showApplyFriendBtn = !isSelf;
    if (scene == 'denylist' || id == 'bot_qian_fan') {
      showApplyFriendBtn = false;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: '',
        rightDMActions: isSelf || id == 'bot_qian_fan'
            ? []
            : [
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Get.to(
                          () => ContactSettingPage(
                            peerId: id,
                            peerAvatar: state.avatar.value,
                            peerAccount: state.account.value,
                            peerNickname: state.nickname.value,
                            peerGender: state.gender.value,
                            peerTitle: state.title.value,
                            peerSign: state.sign.value,
                            peerRegion: state.region.value,
                            peerSource: state.source.value,
                            peerRemark: state.remark.value,
                            peerTag: state.tag.value,
                          ),
                          transition: Transition.rightToLeft,
                          popGesture: true,
                        )?.then((value) {
                          initData();
                        });
                      },
                      child: Icon(
                        Icons.more_horiz,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 24,
                      ),
                    ),
                  ),
                )
              ],
      ),
      body: SingleChildScrollView(
        child: Obx(
          () => Column(
            children: [
              // 用户信息卡片
              Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
            color: isDark
                ? Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
                  ],
                  border: isDark 
                      ? Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                          width: 0.5,
                        )
                      : null,
                ),
                child: ContactCard(
                  id: id,
                  remark: state.remark.value,
                  nickname: state.nickname.value,
                  account: state.account.value,
                  avatar: state.avatar.value,
                  gender: state.gender.value,
                  region: state.region.value,
                  isBorder: false,
                  lineWidth: 0,
                  padding: const EdgeInsets.all(20.0),
                ),
              ),

              // 在线状态显示（非本人）
              if (!isSelf && id != 'bot_qian_fan')
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: isDark 
                        ? Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                            width: 0.5,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
            color: isDark
                ? Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
                    ],
                  ),
                  child: UserOnlineStatusDetailWidget(
                    isOnline: state.status.value == 'online',
                    lastSeenTimestamp: state.lastSeenAt.value,
                    hideOnlineStatus: false,
                  ),
                ),

              // 标签设置（非本人且非机器人）
              if (!isSelf && id != 'bot_qian_fan')
                _buildTagCard(context, isDark),

              // 更多信息（好友或黑名单）
              if (state.isFriend.value == 1 || scene == 'denylist')
                _buildActionCard(
                  context: context,
                  title: t.moreInfo,
                  icon: Icons.info_outline,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => PeopleInfoMorePage(id: id),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // 功能按钮区域
              if (state.isFriend.value == 1 || scene == 'denylist') ...[
                // 发消息
                if (!isSelf)
                  _buildActionCard(
                    context: context,
                    title: t.messageCall,
                    icon: Icons.message_outlined,
                    isDark: isDark,
                    onTap: () {
                      String peerTitle = state.remark.value;
                      if (peerTitle.isEmpty) {
                        peerTitle = state.nickname.value;
                      }
                      if (peerTitle.isEmpty) {
                        peerTitle = state.account.value;
                      }
                      Get.to(
                        () => ChatPage(
                          peerId: id,
                          peerTitle: peerTitle,
                          peerAvatar: state.avatar.value,
                          peerSign: state.sign.value,
                          type: 'C2C',
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),

                // 语音通话
                if (state.isFriend.value == 1 && !isSelf)
                  _buildActionCard(
                    context: context,
                    title: t.voiceCall,
                    icon: Icons.call_outlined,
                    isDark: isDark,
                    onTap: () {
                      openCallScreen(
                        ContactModel.fromMap({
                          "id": id,
                          "nickname": state.nickname.value,
                          "avatar": state.avatar.value,
                          "sign": state.sign.value,
                        }),
                        {'media': 'audio'},
                      );
                    },
                  ),

                // 视频通话
                if (state.isFriend.value == 1 && !isSelf)
                  _buildActionCard(
                    context: context,
                    title: t.videoCall,
                    icon: Icons.videocam_outlined,
                    isDark: isDark,
                    onTap: () {
                      openCallScreen(
                        ContactModel.fromMap({
                          "id": id,
                          "nickname": state.nickname.value,
                          "avatar": state.avatar.value,
                          "sign": state.sign.value,
                        }),
                        {},
                      );
                    },
                  ),
              ] else if (showApplyFriendBtn) ...[
                // 添加好友按钮
                const SizedBox(height: 16),
                _buildAddFriendButton(context),
              ],

              // 黑名单提示
              if (scene == 'denylist')
                _buildWarningTip(context),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}