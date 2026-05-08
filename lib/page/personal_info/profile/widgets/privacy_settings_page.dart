import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import '../profile_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 隐私设置页面
class PrivacySettingsPage extends ConsumerWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.privacySettings,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 搜索设置分组
            _buildSettingGroup(
              context,
              title: t.searchSettings,
              children: [
                _buildSwitchItem(
                  context: context,
                  title: t.allowSearchByAccount,
                  subtitle: t.allowSearchByAccountDesc,
                  value: profileState.allowSearch,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo('allow_search', value);
                  },
                ),

                _buildSwitchItem(
                  context: context,
                  title: t.allowAddByPhone,
                  subtitle: t.allowAddByPhoneDesc,
                  value: profileState.allowAddByPhone,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo('allow_add_by_phone', value);
                  },
                ),

                _buildSwitchItem(
                  context: context,
                  title: t.allowAddByQR,
                  subtitle: t.allowAddByQRDesc,
                  value: profileState.allowAddByQR,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo('allow_add_by_qr', value);
                  },
                ),
              ],
            ),

            // 状态设置分组
            _buildSettingGroup(
              context,
              title: t.statusSettings,
              children: [
                _buildSwitchItem(
                  context: context,
                  title: t.showOnlineStatus,
                  subtitle: t.showOnlineStatusDesc,
                  value: profileState.showOnlineStatus,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo('show_online_status', value);
                  },
                ),

                _buildSwitchItem(
                  context: context,
                  title: t.allowNearbyVisible,
                  subtitle: t.nearbyPeopleExplain,
                  value: profileState.allowNearbyVisible,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo(
                      'allow_nearby_visible',
                      value,
                    );
                  },
                ),
              ],
            ),

            // 数据设置分组
            _buildSettingGroup(
              context,
              title: t.dataSettings,
              children: [
                _buildActionItem(
                  context: context,
                  title: t.clearChatRecords,
                  subtitle: t.clearChatRecordsDesc,
                  icon: Icons.delete_sweep,
                  iconColor: Colors.orange,
                  onTap: () => _showClearChatDialog(context),
                ),

                _buildActionItem(
                  context: context,
                  title: t.deleteAccountAction,
                  subtitle: t.deleteAccountActionDesc,
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
            color: isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white,
            borderRadius: AppRadius.borderRadiusMedium,
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
                            ? AppColors.iosGray3Dark
                            : AppColors.lightDivider,
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
            activeThumbColor: Theme.of(context).primaryColor,
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
                  borderRadius: AppRadius.borderRadiusSmall,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.privacyClearChatHistory),
        content: Text(t.privacyClearChatHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 这里添加清除聊天记录的逻辑
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(t.chatHistoryCleared)));
            },
            child: Text(
              t.buttonConfirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示注销账号对话框
  void _showDeleteAccountDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.privacyLogoutAccount),
        content: Text(t.privacyLogoutAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              parentContext.push('/logout_account');
            },
            child: Text(
              t.buttonConfirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
