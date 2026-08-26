import 'package:flutter/cupertino.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 联系人菜单入口（朋友圈 / 附近的人 / 新的朋友 / 群聊 / 标签）的视觉装饰。
///
/// 这些纯 presentation 关注点（背景色 + 图标）已从数据模型 [ContactModel]
/// 中剥离，避免领域/数据层耦合 `flutter/material`。装饰按菜单入口的负值
/// `peerId` sentinel（见 contact_provider.dart 的 `kPeerId*` 常量）派生。
class ContactMenuDecoration {
  const ContactMenuDecoration({required this.bgColor, required this.iconData});

  final Color bgColor;
  final Widget iconData;
}

/// 按菜单入口 `peerId`（负值 sentinel）返回对应装饰。
///
/// 真实联系人（`peerId > 0`）不是菜单入口，返回 `null`，调用方据此回退到
/// 头像渲染分支。
ContactMenuDecoration? contactMenuDecorationOf(int peerId) {
  switch (peerId) {
    case kPeerIdMomentFeed:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosOrange,
        iconData: Center(
          child: Icon(
            CupertinoIcons.rectangle_stack,
            size: 24,
            color: AppColors.onPrimary,
          ),
        ),
      );
    case kPeerIdPeopleNearby:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosOrange,
        iconData: Center(
          child: Icon(
            CupertinoIcons.person_crop_circle,
            size: 24,
            color: AppColors.onPrimary,
          ),
        ),
      );
    case kPeerIdNewFriend:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosOrange,
        iconData: Center(
          child: Icon(CupertinoIcons.person_badge_plus, size: 24),
        ),
      );
    case kPeerIdGroup:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosGreen,
        iconData: Icon(
          CupertinoIcons.person_2,
          size: 24,
          color: AppColors.onPrimary,
        ),
      );
    case kPeerIdTag:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosBlue,
        iconData: Icon(
          CupertinoIcons.tag,
          size: 24,
          color: AppColors.onPrimary,
        ),
      );
    case kPeerIdAssistantPlaza:
      return const ContactMenuDecoration(
        bgColor: AppColors.tertiary,
        iconData: Icon(
          CupertinoIcons.rectangle_stack_badge_person_crop,
          size: 24,
          color: AppColors.onPrimary,
        ),
      );
    default:
      return null;
  }
}
