import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_view.dart';

import 'package:imboy/page/contact/people_nearby/people_nearby_view.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

import '../new_friend/new_friend_logic.dart';

// ignore: must_be_immutable
class AddFriendPage extends StatelessWidget {
  bool isSearch = false;
  final NewFriendLogic logic = Get.put(NewFriendLogic());

  AddFriendPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: 'addFriend'.tr,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          children: [
            // 搜索框
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? colorScheme.shadow.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SearchAnchor(
                      builder:
                          (BuildContext context, SearchController controller) {
                        return SearchBar(
                          controller: controller,
                          padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(horizontal: 16.0)),
                          onTap: () => controller.openView(),
                          onChanged: (_) => controller.openView(),
                          leading: const Icon(Icons.search),
                          hintText: 'hintLoginAccount'.tr,
                          elevation: const WidgetStatePropertyAll<double>(0),
                          backgroundColor: WidgetStatePropertyAll<Color>(
                            isDark
                                ? colorScheme.surface
                                : const Color(0xFFF5F5F5),
                          ),
                        );
                      },
                      suggestionsBuilder: (BuildContext context,
                          SearchController controller) async {
                        final results =
                            await logic.userSearch(kwd: controller.text);
                        return [
                          await logic.doBuildUserSearchResults(context, results)
                        ];
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${'myAccount'.tr}：",
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          UserRepoLocal.to.current.account,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => Get.to(() => UserQrCodePage()),
                          child: Icon(
                            Icons.qr_code_2,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 功能列表
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? colorScheme.shadow.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark
                    ? Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 0.5,
                      )
                    : null,
              ),
              child: Column(
                children: [
                  _buildListTile(
                    context,
                    icon: Icons.explore_rounded,
                    iconColor: Colors.lightBlue,
                    title: 'peopleNearby'.tr,
                    subtitle: 'nearbyPeopleTips'.tr,
                    onTap: () => Get.to(() => PeopleNearbyPage()),
                    showDivider: true,
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.group,
                    iconColor: Colors.purple,
                    title: 'createGroupF2f'.tr,
                    subtitle: 'enterSameGroup'.tr,
                    onTap: () => Get.to(() => FaceToFacePage()),
                    showDivider: true,
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.qr_code_scanner_outlined,
                    iconColor: Colors.blue,
                    title: 'scanQrCode'.tr,
                    subtitle: 'scanQrCodeBusinessCard'.tr,
                    onTap: () => Get.to(() => const ScannerPage()),
                    showDivider: true,
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.person,
                    iconColor: Colors.lightGreen,
                    title: 'newlyRegisteredPeople'.tr,
                    subtitle: 'allowedBeSearched'.tr,
                    onTap: () => Get.to(() => RecentlyRegisteredUserPage()),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建列表项
  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 80, right: 16),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
      ],
    );
  }
}
