import 'package:flutter/material.dart';
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
        bgColor: Colors.deepOrange,
        iconData: Center(
          child: Icon(Icons.dynamic_feed, size: 24, color: Colors.white),
        ),
      );
    case kPeerIdPeopleNearby:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosOrange,
        iconData: Center(
          child: Icon(Icons.person_pin_circle, size: 24, color: Colors.white),
        ),
      );
    case kPeerIdNewFriend:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosOrange,
        iconData: Center(child: Icon(Icons.person_add, size: 24)),
      );
    case kPeerIdGroup:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosGreen,
        iconData: Icon(Icons.people, size: 24, color: Colors.white),
      );
    case kPeerIdTag:
      return const ContactMenuDecoration(
        bgColor: AppColors.iosBlue,
        iconData: Icon(Icons.local_offer, size: 24, color: Colors.white),
      );
    default:
      return null;
  }
}
