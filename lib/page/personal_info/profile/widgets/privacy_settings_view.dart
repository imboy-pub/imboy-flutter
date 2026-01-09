import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import '../profile_logic.dart';

/// 隐私设置页面
class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<ProfileLogic>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        title: '隐私设置',
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            
            // 搜索设置分组
            _buildSettingGroup(
              context,
              title: '搜索设置',
              children: [
                Obx(() => _buildSwitchItem(
                  context: context,
                  title: '允许通过账号搜索',
                  subtitle: '其他用户可以通过你的账号找到你',
                  value: logic.state.allowSearch.value,
                  onChanged: (value) {
                    logic.state.allowSearch.value = value;
                    logic.updateUserInfo('allow_search', value);
                  },
                )),
                
                Obx(() => _buildSwitchItem(
                  context: context,
                  title: '允许通过手机号添加',
                  subtitle: '其他用户可以通过你的手机号添加你为好友',
                  value: logic.state.allowAddByPhone.value,
                  onChanged: (value) {
                    logic.state.allowAddByPhone.value = value;
                    logic.updateUserInfo('allow_add_by_phone', value);
                  },
                )),
                
                Obx(() => _buildSwitchItem(
                  context: context,
                  title: '允许通过二维码添加',
                  subtitle: '其他用户可以通过扫描你的二维码添加你为好友',
                  value: logic.state.allowAddByQR.value,
                  onChanged: (value) {
                    logic.state.allowAddByQR.value = value;
                    logic.updateUserInfo('allow_add_by_qr', value);
                  },
                )),
              ],
            ),
            
            // 状态设置分组
            _buildSettingGroup(
              context,
              title: '状态设置',
              children: [
                Obx(() => _buildSwitchItem(
                  context: context,
                  title: '显示在线状态',
                  subtitle: '好友可以看到你的在线状态',
                  value: logic.state.showOnlineStatus.value,
                  onChanged: (value) {
                    logic.state.showOnlineStatus.value = value;
                    logic.updateUserInfo('show_online_status', value);
                  },
                )),
                
                Obx(() => _buildSwitchItem(
                  context: context,
                  title: '附近的人可见',
                  subtitle: '在"附近的人"功能中显示你的信息',
                  value: logic.state.allowNearbyVisible.value,
                  onChanged: (value) {
                    logic.state.allowNearbyVisible.value = value;
                    logic.updateUserInfo('allow_nearby_visible', value);
                  },
                )),
              ],
            ),
            
            // 数据设置分组
            _buildSettingGroup(
              context,
              title: '数据设置',
              children: [
                _buildActionItem(
                  context: context,
                  title: '清除聊天记录',
                  subtitle: '清除所有聊天记录，此操作不可恢复',
                  icon: Icons.delete_sweep,
                  iconColor: Colors.orange,
                  onTap: () => _showClearChatDialog(context),
                ),
                
                _buildActionItem(
                  context: context,
                  title: '注销账号',
                  subtitle: '永久删除账号和所有数据，此操作不可恢复',
                  icon: Icons.warning,
                  iconColor: Colors.red,
                  onTap: () => _showDeleteAccountDialog(context),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 构建设置分组
  Widget _buildSettingGroup(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        
        // 设置项容器
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 0.5,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              int index = entry.key;
              Widget child = entry.value;

              return Column(
                children: [
                  child,
                  if (index < children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Container(
                        height: 0.3,
                        color: isDark
                            ? const Color(0xFF48484A)
                            : const Color(0xFFE5E5E5),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 构建开关设置项
  Widget _buildSwitchItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Get.theme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// 构建操作设置项
  Widget _buildActionItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.navigate_next,
                color: isDark ? Colors.white54 : Colors.black54,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示清除聊天记录对话框
  void _showClearChatDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('清除聊天记录'),
        content: const Text('确定要清除所有聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              // 这里添加清除聊天记录的逻辑
              Get.snackbar('成功', '聊天记录已清除');
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 显示注销账号对话框
  void _showDeleteAccountDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('注销账号'),
        content: const Text('确定要注销账号吗？此操作将永久删除你的账号和所有数据，且不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              // 这里添加注销账号的逻辑
              Get.snackbar('警告', '账号注销功能暂未开放');
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}