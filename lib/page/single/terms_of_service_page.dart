import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 服务条款页面
///
/// 展示应用服务条款的法律文本。
class TermsOfServicePage extends ConsumerWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: GlassAppBar(title: t.main.termsOfService),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.main.termsOfService,
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
              '1. 服务说明',
              'IMBoy 是一款即时通讯应用，为用户提供安全、私密的通讯服务。\n'
                  '使用本服务即表示您同意遵守以下条款。',
            ),
            _buildSection(
              theme,
              '2. 用户责任',
              '• 您应对账号下的所有活动负责\n'
                  '• 不得利用本服务传播违法、有害信息\n'
                  '• 不得干扰或破坏服务的正常运行\n'
                  '• 不得未经授权访问其他用户的数据',
            ),
            _buildSection(
              theme,
              '3. 知识产权',
              '本应用及其内容（包括但不限于软件、图标、界面设计）'
                  '的知识产权归开发者所有。\n'
                  '用户发送的内容版权归用户本人所有。',
            ),
            _buildSection(
              theme,
              '4. 服务变更与终止',
              '• 我们保留随时修改或中断服务的权利\n'
                  '• 重大变更将提前通知用户\n'
                  '• 违反条款的账号可能被限制或终止',
            ),
            _buildSection(
              theme,
              '5. 免责声明',
              '• 服务按「现状」提供，不做任何明示或暗示的担保\n'
                  '• 因不可抗力导致的服务中断，我们不承担责任\n'
                  '• 用户间的纠纷由用户自行协商解决',
            ),
            _buildSection(theme, '6. 适用法律', '本条款受中华人民共和国法律管辖。'),
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
