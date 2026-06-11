import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
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
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

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
        // DESIGN.md §8.6 Modal Sheet：圆角 10pt（iOS 标准）+ 移除 boxShadow
        // （iOS BottomSheet 自带 scrim 制造层级，不需要上浮投影）
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.cell),
          topRight: Radius.circular(AppRadius.cell),
        ),
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
              t.common.operationOptions,
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
                title: t.common.buttonCopy,
                subtitle: t.common.copyTextContent,
                onTap: () async {
                  Navigator.pop(context);
                  final String txt =
                      obj.info['payload']['text'] as String? ?? '';
                  if (txt.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: txt));
                    EasyLoading.showToast(t.main.copied);
                  }
                },
                iconColor: Theme.of(context).colorScheme.primary,
              ),

            // 转发给朋友
            _buildActionButton(
              context: context,
              icon: Icons.share,
              title: t.chat.forwardToFriend,
              subtitle: t.common.shareWithOtherFriends,
              onTap: () async {
                Navigator.pop(context);

                // 确保 obj.info 有正确的数据结构
                final Map<String, dynamic> info = Map<String, dynamic>.from(
                  obj.info,
                );

                // 多种方式尝试获取 msg_type
                String? msgType = info['msg_type']?.toString();

                // 方式1：如果顶层没有 msg_type，从 payload 中获取
                if (msgType == null || msgType.isEmpty) {
                  if (info['payload'] is Map) {
                    final payload = info['payload'] as Map<String, dynamic>;
                    msgType = payload['msg_type']?.toString();
                  }
                }

                // 方式2：根据 kind 字段推断类型（kind 定义：1 文本 2 图片 3 语音 4 视频 5 文件 6 位置 7 名片）
                if (msgType == null || msgType.isEmpty) {
                  switch (obj.kind) {
                    case 1:
                      msgType = 'text';
                      break;
                    case 2:
                      msgType = 'image';
                      break;
                    case 3:
                      msgType = 'audio';
                      break;
                    case 4:
                      msgType = 'video';
                      break;
                    case 5:
                      msgType = 'file';
                      break;
                    case 6:
                      msgType = 'location';
                      break;
                    case 7:
                      msgType = 'visitCard';
                      break;
                    default:
                      msgType = 'text';
                  }
                }

                // 确保 msg_type 在顶层（msgType 在此处已确保非空）
                info['msg_type'] = msgType;
                info['type'] = info['type'] ?? 'C2C';

                // 生成新的消息 ID
                info['id'] = Xid().toString();

                if (info['payload'] is Map) {
                  final payload = info['payload'] as Map<String, dynamic>;
                }

                try {
                  var msg = await MessageModel.fromJson(info).toTypeMessage();

                  // 使用 Navigator.push 替代 Get.to
                  Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (context) => SendToPage(msg: msg),
                    ),
                  ).then((value) {
                    // 调用 Provider 的 change 方法
                    notifier.change(obj.kindId.toString());
                  });
                } catch (e) {
                  EasyLoading.showError(t.common.operationFailedAgainLater);
                }
              },
              iconColor: Theme.of(context).colorScheme.secondary,
            ),

            // 编辑标签
            _buildActionButton(
              context: context,
              icon: Icons.local_offer,
              title: t.common.editTag,
              subtitle: t.common.addTagsToFavorites,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (context) => TagRelationPage(
                      peerId: obj.kindId.toString(),
                      peerTag: obj.tag,
                      scene: 'collect',
                      title: t.common.editTag,
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
                    if (context.mounted) Navigator.pop(context);
                  }
                });
              },
              iconColor: Theme.of(context).colorScheme.tertiary,
            ),

            // 设置备注
            _buildActionButton(
              context: context,
              icon: Icons.edit_note,
              title: t.main.setParam(param: t.contact.remark),
              subtitle: t.common.addRemarkToFavorites,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (context) => UpdatePage(
                      title: t.main.setParam(param: t.contact.remark),
                      value: obj.remark,
                      field: 'text',
                      maxLength: 100,
                      callback: (remarkNew) async {
                        // 调用 Provider 的 remark 方法
                        bool ok = await notifier.remark(
                          obj.kindId.toString(),
                          remarkNew,
                        );
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
              title: t.common.buttonDelete,
              subtitle: t.common.deleteThisCollection,
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
                  if (context.mounted) Navigator.pop(context);
                }
              },
              iconColor: AppColors.getIosRed(Theme.of(context).brightness),
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
                  t.common.buttonCancel,
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
      // ClipRRect 让 CellPressable 高亮按 menu item 圆角裁切
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusMedium,
        child: CellPressable(
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
                              ? AppColors.getIosRed(
                                  Theme.of(context).brightness,
                                )
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
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.common.details,
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
                  showModalBottomSheet<void>(
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
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusMedium,
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
                      "${t.main.from} ${obj.source} ${DateTimeHelper.lastTimeFmt(obj.createdAt)}",
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
                      : AppColors.infoBlueContainer,
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
                          "${t.contact.remark}:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Theme.of(context).colorScheme.onSurface
                                : AppColors.infoBlue,
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
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
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
