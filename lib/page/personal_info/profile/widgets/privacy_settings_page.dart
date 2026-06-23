import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import '../profile_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

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
        title: t.common.privacySettings,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 搜索设置分组
            _buildSettingGroup(
              context,
              title: t.common.searchSettings,
              children: [
                _buildSwitchItem(
                  context: context,
                  title: t.common.allowSearchByAccount,
                  subtitle: t.common.allowSearchByAccountDesc,
                  value: profileState.allowSearch,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo('allow_search', value);
                  },
                ),

                _buildSwitchItem(
                  context: context,
                  title: t.common.allowAddByPhone,
                  subtitle: t.common.allowAddByPhoneDesc,
                  value: profileState.allowAddByPhone,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo('allow_add_by_phone', value);
                  },
                ),

                _buildSwitchItem(
                  context: context,
                  title: t.common.allowAddByQR,
                  subtitle: t.common.allowAddByQRDesc,
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
              title: t.common.statusSettings,
              children: [
                _buildSwitchItem(
                  context: context,
                  title: t.common.showOnlineStatus,
                  subtitle: t.common.showOnlineStatusDesc,
                  value: profileState.showOnlineStatus,
                  onChanged: (value) {
                    profileNotifier.updateUserInfo('show_online_status', value);
                  },
                ),

                _buildSwitchItem(
                  context: context,
                  title: t.common.allowNearbyVisible,
                  subtitle: t.discovery.nearbyPeopleExplain,
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
              title: t.common.dataSettings,
              children: [
                _buildActionItem(
                  context: context,
                  title: t.common.clearChatRecords,
                  subtitle: t.common.clearChatRecordsDesc,
                  icon: Icons.delete_sweep,
                  iconColor: AppColors.iosOrange,
                  onTap: () => _showClearChatDialog(context),
                ),

                _buildActionItem(
                  context: context,
                  title: t.common.deleteAccountAction,
                  subtitle: t.common.deleteAccountActionDesc,
                  icon: Icons.warning,
                  iconColor: AppColors.iosRed,
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
              fontSize: FontSizeType.normal.size,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextColor(
                Theme.of(context).brightness,
                isSecondary: true,
              ),
            ),
          ),
        ),

        // 设置项容器
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceGroupedTertiary
                : AppColors.lightSurface,
            borderRadius: AppRadius.borderRadiusMedium,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? AppColors.lightTextPrimary.withValues(alpha: 0.2)
                    : AppColors.lightTextPrimary.withValues(alpha: 0.03),
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: FontSizeType.medium.size,
                    fontWeight: FontWeight.w400,
                    color: AppColors.getTextColor(Theme.of(context).brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: FontSizeType.footnote.size,
                    color: AppColors.getTextColor(
                      Theme.of(context).brightness,
                      isSecondary: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.regular),
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
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.small),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: FontSizeType.medium.size,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.tiny),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: FontSizeType.footnote.size,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.navigate_next,
                color: AppColors.getTextColor(
                  Theme.of(context).brightness,
                  isSecondary: true,
                ),
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.privacyClearChatHistory),
        content: Text(t.common.privacyClearChatHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 这里添加清除聊天记录的逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.common.chatHistoryCleared)),
              );
            },
            child: Text(
              t.common.buttonConfirm,
              style: const TextStyle(color: AppColors.iosRed),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示注销账号对话框
  void _showDeleteAccountDialog(BuildContext parentContext) {
    showDialog<void>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.account.privacyLogoutAccount),
        content: Text(t.common.privacyLogoutAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              parentContext.push('/logout_account');
            },
            child: Text(
              t.common.buttonConfirm,
              style: const TextStyle(color: AppColors.iosRed),
            ),
          ),
        ],
      ),
    );
  }
}
