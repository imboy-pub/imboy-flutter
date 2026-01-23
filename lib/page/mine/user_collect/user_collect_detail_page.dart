import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_relation_page.dart'
    show TagRelationPage;

import 'package:imboy/page/chat/send_to/send_to_page.dart';
import 'package:imboy/page/personal_info/update/update_page.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:xid/xid.dart';

import 'user_collect_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 用户收藏详情页面
///
/// 从 GetX 迁移到 Riverpod
class UserCollectDetailPage extends ConsumerWidget {
  final int pageIndex;
  final UserCollectModel obj;

  const UserCollectDetailPage({
    super.key,
    required this.obj,
    required this.pageIndex,
  });

  /// 构建操作菜单
  Widget _buildActionMenu(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(userCollectProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部指示器
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 16, bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: AppRadius.borderRadiusTiny,
              ),
            ),

            // 标题
            Text(
              t.operationOptions,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),

            // 复制按钮（仅文本类型）
            if (obj.kind == 1)
              _buildActionButton(
                context: context,
                icon: Icons.copy,
                title: t.buttonCopy,
                subtitle: t.copyTextContent,
                onTap: () async {
                  Navigator.pop(context);
                  final String txt = obj.info['payload']['text'] ?? '';
                  if (txt.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: txt));
                    EasyLoading.showToast(t.copied);
                  }
                },
                iconColor: Theme.of(context).colorScheme.primary,
              ),

            // 转发给朋友
            _buildActionButton(
              context: context,
              icon: Icons.share,
              title: t.forwardToFriend,
              subtitle: t.shareWithOtherFriends,
              onTap: () async {
                Navigator.pop(context);
                obj.info['id'] = Xid().toString();
                var msg = await MessageModel.fromJson(obj.info).toTypeMessage();
                // 使用 Navigator.push 替代 Get.to
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SendToPage(msg: msg)),
                ).then((value) {
                  // 调用 Provider 的 change 方法
                  notifier.change(obj.kindId);
                });
              },
              iconColor: Theme.of(context).colorScheme.secondary,
            ),

            // 编辑标签
            _buildActionButton(
              context: context,
              icon: Icons.local_offer,
              title: t.editTag,
              subtitle: t.addTagsToFavorites,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TagRelationPage(
                      peerId: obj.kindId,
                      peerTag: obj.tag,
                      scene: 'collect',
                      title: t.editTag,
                    ),
                  ),
                ).then((value) {
                  if (value != null && value is String) {
                    // 更新本地对象
                    final updatedObj = UserCollectModel(
                      userId: obj.userId,
                      kind: obj.kind,
                      kindId: obj.kindId,
                      source: obj.source,
                      remark: obj.remark,
                      tag: value.toString(),
                      updatedAt: obj.updatedAt,
                      createdAt: obj.createdAt,
                      info: obj.info,
                    );
                    // 调用 Provider 的 updateItem 方法
                    notifier.updateItem(updatedObj);
                    Navigator.pop(context);
                  }
                });
              },
              iconColor: Theme.of(context).colorScheme.tertiary,
            ),

            // 设置备注
            _buildActionButton(
              context: context,
              icon: Icons.edit_note,
              title: t.setParam(param: t.remark),
              subtitle: t.addRemarkToFavorites,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpdatePage(
                      title: t.setParam(param: t.remark),
                      value: obj.remark,
                      field: 'text',
                      maxLength: 100,
                      callback: (remarkNew) async {
                        // 调用 Provider 的 remark 方法
                        bool ok = await notifier.remark(obj.kindId, remarkNew);
                        return ok;
                      },
                    ),
                  ),
                );
              },
              iconColor: Theme.of(context).colorScheme.primary,
            ),

            // 删除
            _buildActionButton(
              context: context,
              icon: Icons.delete_outline,
              title: t.buttonDelete,
              subtitle: t.deleteThisCollection,
              onTap: () async {
                Navigator.pop(context);
                // 调用 Provider 的 remove 方法
                bool res = await notifier.remove(obj);
                if (res) {
                  // 从列表中移除
                  final currentState = ref.read(userCollectProvider);
                  final updatedItems = currentState.items
                      .where((item) => item.kindId != obj.kindId)
                      .toList();
                  notifier.updateState(
                    currentState.copyWith(items: updatedItems),
                  );
                  Navigator.pop(context);
                }
              },
              iconColor: Theme.of(context).colorScheme.error,
              isDestructive: true,
            ),

            const SizedBox(height: 16),

            // 取消按钮
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                ),
                child: Text(
                  t.buttonCancel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusMedium,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
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
                          fontWeight: FontWeight.w600,
                          color: isDestructive
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(userCollectProvider.notifier);

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.details,
        rightDMActions: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.borderRadiusXLarge,
                onTap: () {
                  // 使用 showModalBottomSheet 替代 Get.bottomSheet
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => _buildActionMenu(context, ref),
                  );
                },
                child: Icon(
                  Icons.more_horiz,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 来源信息卡片
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusMedium,
                border: isDark
                    ? Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.15),
                        width: 0.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${t.from} ${obj.source} ${DateTimeHelper.lastTimeFmt(obj.createdAt)}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 备注信息卡片
            if (obj.remark.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.1)
                      : const Color(0xFFE1F5FE),
                  borderRadius: AppRadius.borderRadiusMedium,
                  border: isDark
                      ? Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          width: 0.5,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          color: isDark
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${t.remark}:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Theme.of(context).colorScheme.onSurface
                                : const Color(0xFF0277BD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      obj.remark,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Theme.of(context).colorScheme.onSurface
                            : const Color(0xFF01579B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

            // 内容卡片
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusRegular,
                border: isDark
                    ? Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.15),
                        width: 0.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: notifier.buildItemBody(context, obj, 'detail'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
