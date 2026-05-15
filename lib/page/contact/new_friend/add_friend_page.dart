import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_page.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_page.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/page/qrcode/qrcode_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'new_friend_provider.dart';

class AddFriendPage extends ConsumerWidget {
  const AddFriendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        title: t.common.addFriend,
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
                borderRadius: AppRadius.borderRadiusMedium,
                // DESIGN.md §5.2 + §8.3：容器靠 surface 对比，不用投影
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
                                EdgeInsets.symmetric(horizontal: 16.0),
                              ),
                              onTap: () => controller.openView(),
                              onChanged: (_) => controller.openView(),
                              leading: const Icon(Icons.search),
                              hintText: t.account.hintLoginAccount,
                              elevation: const WidgetStatePropertyAll<double>(
                                0,
                              ),
                              backgroundColor: WidgetStatePropertyAll<Color>(
                                isDark
                                    ? colorScheme.surface
                                    : AppColors.lightPageBackground,
                              ),
                            );
                          },
                      suggestionsBuilder:
                          (
                            BuildContext context,
                            SearchController controller,
                          ) async {
                            final results = await ref
                                .read(newFriendProvider.notifier)
                                .userSearch(kwd: controller.text);
                            if (!context.mounted) return [];
                            return _buildSearchResults(context, results);
                          },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${t.account.myAccount}：",
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
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<dynamic>(
                                builder: (context) => UserQrCodePage(),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.qr_code_2,
                            color: AppColors.primary,
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
                borderRadius: AppRadius.borderRadiusRegular,
                // DESIGN.md §5.2 + §8.3：容器靠 surface 对比，不用投影
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
                    title: t.discovery.peopleNearby,
                    subtitle: t.common.nearbyPeopleTips,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<dynamic>(
                          builder: (context) => const PeopleNearbyPage(),
                        ),
                      );
                    },
                    showDivider: true,
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.group,
                    iconColor: Colors.purple,
                    title: t.chat.createGroupF2f,
                    subtitle: t.group.enterSameGroup,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<dynamic>(
                          builder: (context) => FaceToFacePage(),
                        ),
                      );
                    },
                    showDivider: true,
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.qr_code_scanner_outlined,
                    iconColor: AppColors.iosBlue,
                    title: t.account.scanQrCode,
                    subtitle: t.chat.scanQrCodeBusinessCard,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<dynamic>(
                          builder: (context) => const ScannerPage(),
                        ),
                      );
                    },
                    showDivider: true,
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.person,
                    iconColor: Colors.lightGreen,
                    title: t.account.newlyRegisteredPeople,
                    subtitle: t.common.allowedBeSearched,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<dynamic>(
                          builder: (context) => RecentlyRegisteredUserPage(),
                        ),
                      );
                    },
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
        ClipRRect(
          borderRadius: AppRadius.borderRadiusMedium,
          child: CellPressable(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusMedium,
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

  List<Widget> _buildSearchResults(BuildContext context, List<dynamic> items) {
    if (items.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.only(top: 10, left: 0, right: 0, bottom: 0),
          padding: const EdgeInsets.only(
            top: 40,
            left: 0,
            right: 0,
            bottom: 40,
          ),
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black87
              : Colors.white,
          child: Center(
            child: Text(
              t.common.userNotExist,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ];
    }

    return items.map((item) {
      var model = item;
      bool isSelf = model.id == UserRepoLocal.to.currentUid;

      return Container(
        margin: const EdgeInsets.only(top: 10, left: 0, right: 0, bottom: 0),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black87
            : Colors.white,
        child: ListTile(
          leading: ClipRRect(
            borderRadius: AppRadius.borderRadiusSmall,
            child: Image(
              image: cachedImageProvider(model.avatar as String? ?? '', w: 56),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey[300],
                  child: const Icon(Icons.person),
                );
              },
            ),
          ),
          title: Text(model.title as String),
          subtitle: Row(
            children: [
              genderIcon(model.gender as int),
              const Space(width: 10),
              if (model.region.isNotEmpty == true) Text(model.region as String),
            ],
          ),
          trailing: isSelf
              ? null
              : Container(
                  width: 80,
                  alignment: Alignment.centerRight,
                  child: ((model.isFriend ?? false) as bool)
                      ? Text(t.common.added)
                      : Text(t.common.buttonAdd),
                ),
          onTap: () {
            if (isSelf) {
              return;
            }
            context.push(
              '/people_info/${model.id}',
              extra: {'scene': 'user_search'},
            );
          },
        ),
      );
    }).toList();
  }
}
