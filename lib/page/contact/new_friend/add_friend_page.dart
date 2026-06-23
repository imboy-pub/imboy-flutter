import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_page.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_page.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/page/qrcode/qrcode_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'new_friend_provider.dart';

/// 添加朋友页面 - iOS 17 Premium 风格重构
class AddFriendPage extends ConsumerWidget {
  const AddFriendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.addFriend,
      useLargeTitle: false,
      child: Column(
        children: [
          // 搜索 Section
          _buildSearchSection(context, ref, brightness),

          // 功能列表 Section
          ImBoySettingsSection(
            children: [
              _buildFeatureTile(
                context,
                icon: CupertinoIcons.location_fill,
                color: AppColors.iosBlue,
                title: t.discovery.peopleNearby,
                subtitle: t.common.nearbyPeopleTips,
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => const PeopleNearbyPage(),
                  ),
                ),
              ),
              _buildFeatureTile(
                context,
                icon: CupertinoIcons.group_solid,
                color: AppColors.iosGreen,
                title: t.chat.createGroupF2f,
                subtitle: t.group.enterSameGroup,
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(builder: (_) => FaceToFacePage()),
                ),
              ),
              _buildFeatureTile(
                context,
                icon: CupertinoIcons.qrcode_viewfinder,
                color: AppColors.iosPurple,
                title: t.account.scanQrCode,
                subtitle: t.chat.scanQrCodeBusinessCard,
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(builder: (_) => const ScannerPage()),
                ),
              ),
              _buildFeatureTile(
                context,
                icon: CupertinoIcons.person_fill,
                color: AppColors.iosOrange,
                title: t.account.newlyRegisteredPeople,
                subtitle: t.common.allowedBeSearched,
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => RecentlyRegisteredUserPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(
    BuildContext context,
    WidgetRef ref,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: AppSpacing.allLarge,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            CupertinoSearchTextField(
              placeholder: t.account.hintLoginAccount,
              onSubmitted: (v) async {
                final results = await ref
                    .read(newFriendProvider.notifier)
                    .userSearch(kwd: v);
                if (context.mounted && results.isNotEmpty) {
                  // 处理搜索结果跳转或显示逻辑
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${t.account.myAccount}：",
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: AppColors.iosGray,
                  ),
                ),
                Text(
                  UserRepoLocal.to.current.account,
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute<void>(builder: (_) => UserQrCodePage()),
                  ),
                  child: const Icon(
                    CupertinoIcons.qrcode,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ImBoySettingsTile(
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.onPrimary, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
