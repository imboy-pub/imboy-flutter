import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:get/get.dart';
import 'chat_setting_logic.dart';

class ChatSettingView extends StatelessWidget {
  final logic = Get.find<ChatSettingLogic>();
  final state = Get.find<ChatSettingLogic>().state;

  ChatSettingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text('chatSettings'.tr),
      ),
      body: Obx(() => _buildContent()),
    );
  }

  Widget _buildContent() {
    if (state.isLoading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        _buildSettingSection(
          children: [
            _buildSwitchTile(
              icon: Icons.push_pin,
              title: 'chatSettingPin'.tr,
              subtitle: 'chatSettingPinDesc'.tr,
              value: state.isPinned.value,
              onChanged: (_) => logic.togglePin(),
            ),
            _buildSwitchTile(
              icon: Icons.notifications_off,
              title: 'chatSettingMute'.tr,
              subtitle: 'chatSettingMuteDesc'.tr,
              value: state.isMuted.value,
              onChanged: (_) => logic.toggleMute(),
            ),
          ],
        ),
        _buildSettingSection(
          children: [
            _buildNavigationTile(
              icon: Icons.image,
              title: 'chatSettingBackground'.tr,
              subtitle: state.chatBackground.value.isEmpty
                  ? 'chatSettingBackgroundDefault'.tr
                  : 'chatSettingBackgroundCustom'.tr,
              onTap: () {
                Get.snackbar(
                  'tipTips'.tr,
                  'chatSettingBackgroundSelectorTip'.tr,
                  snackPosition: SnackPosition.bottom,
                );
              },
            ),
          ],
        ),
        _buildSettingSection(
          children: [
            _buildActionTile(
              icon: Icons.delete_outline,
              title: 'chatSettingClearHistory'.tr,
              subtitle: 'chatSettingClearHistoryDesc'.tr,
              textColor: Colors.red,
              onTap: () => logic.clearChatHistory(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingSection({required List<Widget> children}) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          color: Colors.white,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Get.theme.primaryColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Get.theme.primaryColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: textColor?.withOpacity(0.7)))
          : null,
      onTap: onTap,
    );
  }
}
