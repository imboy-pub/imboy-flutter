import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'confirm_new_friend_provider.dart';

/// 确认新好友页面
class ConfirmNewFriendPage extends ConsumerStatefulWidget {
  final String from;
  final String to;
  final String msg;
  final String nickname;
  final String payload;

  const ConfirmNewFriendPage({
    super.key,
    required this.from,
    required this.to,
    required this.msg,
    required this.nickname,
    required this.payload,
  });

  @override
  ConsumerState<ConfirmNewFriendPage> createState() =>
      _ConfirmNewFriendPageState();
}

class _ConfirmNewFriendPageState extends ConsumerState<ConfirmNewFriendPage> {
  final TextEditingController _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _remarkController.text = widget.nickname;
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  /// 构建验证消息卡片
  Widget _buildMessageCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        // DESIGN.md §5.2 + §8.3：Cell 用边框区分而非投影
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(
                    Icons.message_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    t.verificationMessage,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 消息内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: AppRadius.borderRadiusMedium,
              ),
              child: Text(
                '"${widget.msg}"',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建备注输入卡片
  Widget _buildRemarkCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        // DESIGN.md §5.2 + §8.3：Cell 用边框区分而非投影
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    t.setParam(param: t.remark),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 输入框
            TextField(
              controller: _remarkController,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: t.enterRemark,
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
                counterStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建设置项卡片
  Widget _buildSettingCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusRegular,
        child: CellPressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
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
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(confirmNewFriendProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: GlassAppBar(
        title: t.acceptFriendRequest,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 验证消息显示
            _buildMessageCard(context),
            // 备注设置
            _buildRemarkCard(context),
            // 标签设置
            _buildSettingCard(
              context: context,
              title: t.tags,
              subtitle: providerState.peerTag.isEmpty
                  ? t.addTag
                  : providerState.peerTag,
              icon: Icons.local_offer_outlined,
              onTap: () async {
                final result = await Navigator.of(context).push(
                  CupertinoPageRoute<dynamic>(
                    builder: (context) => UserTagRelationPage(
                      peerId: widget.from,
                      peerTag: providerState.peerTag.isEmpty
                          ? ''
                          : providerState.peerTag,
                      scene: 'friend',
                    ),
                  ),
                );
                if (result != null && result is String) {
                  ref.read(confirmNewFriendProvider.notifier).updateTag(result);
                }
              },
            ),
            const SizedBox(height: 100), // 为底部按钮留出空间
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          // DESIGN.md §5.2 例外：bottom bar 顶推阴影（toolbar 上浮）alpha 0.1→0.08
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> p2 = json.decode(widget.payload) as Map<String, dynamic>;
                p2['to'] = {
                  "remark": _remarkController.text,
                  "account": UserRepoLocal.to.current.account,
                  "nickname": UserRepoLocal.to.current.nickname,
                  "avatar": UserRepoLocal.to.current.avatar,
                  "sign": UserRepoLocal.to.current.sign,
                  "gender": UserRepoLocal.to.current.gender,
                  "role": providerState.role,
                  "donotlookhim": providerState.donotlookhim,
                  "donotlethimlook": providerState.donotlethimlook,
                  "tag": providerState.peerTag.isEmpty
                      ? ''
                      : "${providerState.peerTag},",
                };

                final success = await ref
                    .read(confirmNewFriendProvider.notifier)
                    .confirm(from: widget.from, to: widget.to, payload: p2);

                if (success && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusXLarge,
                ),
              ),
              child: Text(
                t.buttonAccomplish,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
