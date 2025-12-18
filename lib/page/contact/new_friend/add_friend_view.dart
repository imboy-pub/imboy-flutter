import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_view.dart';

import 'package:imboy/page/contact/people_nearby/people_nearby_view.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text('add_friend'.tr),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchAnchor(
              builder: (BuildContext context, SearchController controller) {
                return SearchBar(
                  controller: controller,
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 16.0)),
                  onTap: () => controller.openView(),
                  onChanged: (_) => controller.openView(),
                  leading: const Icon(Icons.search),
                  hintText: 'hint_login_account'.tr,
                );
              },
              suggestionsBuilder: (BuildContext context, SearchController controller) async {
                final results = await logic.userSearch(kwd: controller.text);
                return [await logic.doBuildUserSearchResults(context, results)];
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${'my_account'.tr}："),
                Text(UserRepoLocal.to.current.account),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Get.to(() => UserQrCodePage()),
                  child: Icon(Icons.qr_code_2, color: colorScheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildListTile(
            context,
            icon: Icons.explore_rounded,
            iconColor: Colors.lightBlue,
            title: 'people_nearby'.tr,
            subtitle: 'nearby_people_tips'.tr,
            onTap: () => Get.to(() => PeopleNearbyPage()),
          ),
          _buildListTile(
            context,
            icon: Icons.group,
            iconColor: Colors.purple,
            title: 'create_group_f2f'.tr,
            subtitle: 'enter_same_group'.tr,
            onTap: () => Get.to(() => FaceToFacePage()),
          ),
          _buildListTile(
            context,
            icon: Icons.qr_code_scanner_outlined,
            iconColor: Colors.blue,
            title: 'scan_qr_code'.tr,
            subtitle: 'scan_qr_code_business_card'.tr,
            onTap: () => Get.to(() => const ScannerPage()),
          ),
          _buildListTile(
            context,
            icon: Icons.person,
            iconColor: Colors.lightGreen,
            title: 'newly_registered_people'.tr,
            subtitle: 'allowed_be_searched'.tr,
            onTap: () => Get.to(() => RecentlyRegisteredUserPage()),
          ),
        ],
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
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor, size: 36),
          title: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, // 使用主题文字色
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), // 使用主题文字色
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // 添加12px圆角
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 72),
          child: Divider(height: 1),
        ),
      ],
    );
  }
}
