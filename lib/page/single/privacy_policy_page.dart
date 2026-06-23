import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 隐私政策页面
///
/// 展示应用隐私政策的法律文本。
class PrivacyPolicyPage extends ConsumerWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: GlassAppBar(title: t.main.privacyPolicy),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.main.privacyPolicy,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.verticalSmall,
            Text(
              '生效日期：2026-01-01',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.verticalXLarge,
            _buildSection(
              theme,
              '1. 信息收集',
              '我们收集以下类型的信息以提供和改善服务：\n'
                  '• 账号信息：手机号码、昵称、头像等注册信息\n'
                  '• 设备信息：设备型号、操作系统版本、唯一设备标识符\n'
                  '• 通讯数据：消息内容通过端到端加密保护，服务器不存储明文\n'
                  '• 日志信息：IP 地址、访问时间、功能使用情况',
            ),
            _buildSection(
              theme,
              '2. 信息使用',
              '我们使用收集的信息用于：\n'
                  '• 提供、维护和改善通讯服务\n'
                  '• 发送服务通知和安全警报\n'
                  '• 防止欺诈和滥用行为\n'
                  '• 遵守法律法规要求',
            ),
            _buildSection(
              theme,
              '3. 信息存储与保护',
              '• 您的消息通过端到端加密（E2EE）保护\n'
                  '• 个人数据存储在安全的服务器中\n'
                  '• 我们采用行业标准的安全措施保护您的数据\n'
                  '• 数据保留期限遵循适用法律法规的要求',
            ),
            _buildSection(
              theme,
              '4. 信息共享',
              '我们不会出售您的个人信息。仅在以下情况下共享：\n'
                  '• 获得您的明确同意\n'
                  '• 法律法规要求\n'
                  '• 保护用户安全或公共利益',
            ),
            _buildSection(
              theme,
              '5. 用户权利',
              '您有权：\n'
                  '• 访问和更正您的个人信息\n'
                  '• 删除您的账号和相关数据\n'
                  '• 撤回同意（不影响撤回前的数据处理）\n'
                  '• 导出您的个人数据',
            ),
            _buildSection(
              theme,
              '6. 账号注销',
              '您可以在「设置 > 账号安全 > 注销账号」中申请注销。\n'
                  '注销申请提交后有 60 天冷静期，期间可随时撤销。\n'
                  '冷静期结束后，您的账号数据将被永久删除。',
            ),
            _buildSection(theme, '7. 联系我们', '如有隐私相关问题，请通过应用内「反馈」功能联系我们。'),
            AppSpacing.verticalXXLarge,
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.verticalSmall,
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
