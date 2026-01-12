import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'group_announcement_logic.dart';

class GroupAnnouncementView extends StatelessWidget {
  final logic = Get.find<GroupAnnouncementLogic>();
  final state = Get.find<GroupAnnouncementLogic>().state;

  GroupAnnouncementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        title: '群公告',
        rightDMActions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => _showPublishDialog(context),
          ),
        ],
      ),
      body: Obx(() {
        if (state.announcements.isEmpty && !state.isLoading.value) {
          return _buildEmptyView(context);
        }

        return RefreshIndicator(
          onRefresh: logic.onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: state.announcements.length + (state.hasMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              // 加载更多指示器
              if (index == state.announcements.length) {
                logic.onLoadMore();
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final announcement = state.announcements[index];
              return _buildAnnouncementItem(context, announcement);
            },
          ),
        );
      }),
    );
  }

  // 构建公告项
  Widget _buildAnnouncementItem(BuildContext context, dynamic announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark 
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                width: 0.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 发布者信息
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  // backgroundColor: AppColors.primaryElement.withValues(alpha: 0.1),
                  child: Text(
                    announcement.publisherName.isNotEmpty 
                        ? announcement.publisherName[0].toUpperCase() 
                        : '?',
                    style: TextStyle(
                      fontSize: 16,
                      // color: AppColors.primaryElement,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.publisherName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      logic.formatTime(announcement.createdAt),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 如果是当前用户发布的，显示删除按钮
                // 这里假设 announcement 包含 creatorId 或者类似字段判断是否自己发布的
                // 暂时用 TextButton.icon 替换为更简洁的 PopupMenu 或者 Icon
                 IconButton(
                    icon: Icon(
                      Icons.delete_outline, 
                      size: 20,
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      _showDeleteDialog(context, announcement);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 公告内容
            Text(
              announcement.content,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
            if (announcement.expiredAt != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy_outlined, 
                      size: 14, 
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '有效期至: ${logic.formatTime(announcement.expiredAt)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 空视图
  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.announcement_outlined, 
              size: 48, 
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无群公告',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 显示发布公告对话框
  void _showPublishDialog(BuildContext context) {
    final contentController = TextEditingController();
    final expiredDateNotifier = ValueNotifier<DateTime?>(null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('发布公告'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '请输入公告内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    expiredDateNotifier.value = date;
                  }
                },
                child: ValueListenableBuilder<DateTime?>(
                  valueListenable: expiredDateNotifier,
                  builder: (context, expiredDate, child) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            expiredDate != null
                                ? '${expiredDate.year}-${expiredDate.month.toString().padLeft(2, '0')}-${expiredDate.day.toString().padLeft(2, '0')}'
                                : '选择有效期（可选）',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (contentController.text.trim().isNotEmpty) {
                  logic.publishAnnouncement(
                    contentController.text.trim(),
                    expiredAt: expiredDateNotifier.value?.millisecondsSinceEpoch,
                  );
                  Get.back();
                }
              },
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
  }

  // 显示删除确认对话框
  void _showDeleteDialog(BuildContext context, dynamic announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条公告吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              logic.deleteAnnouncement(announcement.id);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
