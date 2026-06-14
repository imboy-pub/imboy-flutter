import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 联系人名片组件 - iOS 17 Premium 风格
class ContactCard extends StatelessWidget {
  final String? id;
  final String? nickname;
  final String? avatar;
  final String? account;
  final int gender;
  final String region;
  final String? remark;
  final String? heroTag;
  final EdgeInsets? padding;

  const ContactCard({
    super.key,
    required this.id,
    this.nickname,
    required this.avatar,
    required this.account,
    required this.gender,
    this.region = '',
    this.remark = '',
    this.heroTag,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    String displayTitle = parseModelString(remark);
    String? subNickname = nickname;
    if (strEmpty(displayTitle)) {
      displayTitle = nickname ?? '';
      subNickname = '';
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.large),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 头像
          GestureDetector(
            onTap: () {
              if (isNetWorkImg(avatar ?? '')) {
                zoomInPhotoView(context, avatar!);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(t.common.noAvatar)));
              }
            },
            child: Avatar(
              imgUri: avatar ?? '',
              width: 72,
              height: 72,
              heroTag: heroTag,
            ),
          ),
          const SizedBox(width: 18),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    genderIcon(gender),
                  ],
                ),
                const SizedBox(height: 4),
                if (strNoEmpty(subNickname))
                  Text(
                    "${t.account.nickname}: $subNickname",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.iosGray,
                    ),
                  ),
                Text(
                  "ID: $account",
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.iosGray,
                  ),
                ),
                if (strNoEmpty(region))
                  Text(
                    "${t.account.region}: $region",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.iosGray,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
