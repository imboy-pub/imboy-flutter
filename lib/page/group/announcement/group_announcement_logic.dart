import 'package:get/get.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/routes.dart' as Routes;
import 'package:flutter_easyloading/flutter_easyloading.dart';

part 'group_announcement_state.dart';

class GroupAnnouncementLogic extends GetxController {
  final GroupAnnouncementState state = GroupAnnouncementState();

  // 获取路由参数中的 groupId
  String get groupId => Get.arguments['groupId'] ?? '';

  int page = 1;
  final int pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    if (groupId.isEmpty) {
      Get.snackbar('提示', '群组ID不能为空');
      Get.back();
      return;
    }
    loadAnnouncements(isRefresh: true);
  }

  @override
  void onClose() {
    // 清理资源
    super.onClose();
  }

  // 加载公告列表
  Future<void> loadAnnouncements({bool isRefresh = false}) async {
    if (isRefresh) {
      page = 1;
      state.hasMore.value = true;
    }

    if (!state.hasMore.value) {
      return;
    }

    state.isLoading.value = true;

    try {
      final response = await HttpClient.client.get(
        '/api/group/$groupId/announcements',
        queryParameters: {
          'page': page,
          'size': pageSize,
        },
      );

      if (response.code == 0) {
        final payload = response.payload;
        final list = (payload['list'] as List)
            .map((e) => AnnouncementModel.fromJson(e))
            .toList();

        if (isRefresh) {
          state.announcements.clear();
        }
        state.announcements.addAll(list);

        final pagination = payload['pagination'];
        state.hasMore.value = pagination['has_next'] ?? false;
        page++;
      } else {
        Get.snackbar('错误', response.msg);
      }
    } catch (e) {
      Get.snackbar('错误', e.toString());
    } finally {
      state.isLoading.value = false;
    }
  }

  // 下拉刷新
  Future<void> onRefresh() async {
    await loadAnnouncements(isRefresh: true);
  }

  // 加载更多
  Future<void> onLoadMore() async {
    if (!state.isLoading.value && state.hasMore.value) {
      await loadAnnouncements();
    }
  }

  // 发布公告
  Future<void> publishAnnouncement(String content, {int? expiredAt}) async {
    if (content.trim().isEmpty) {
      Get.snackbar('提示', '公告内容不能为空');
      return;
    }

    try {
      EasyLoading.show(status: '发布中...');

      final response = await HttpClient.client.post(
        '/api/group/$groupId/announcement',
        data: {
          'content': content,
          if (expiredAt != null) 'expired_at': expiredAt,
        },
      );

      EasyLoading.dismiss();

      if (response.code == 0) {
        Get.snackbar('成功', '公告发布成功');
        // 刷新列表
        await loadAnnouncements(isRefresh: true);
      } else {
        Get.snackbar('失败', response.msg);
      }
    } catch (e) {
      EasyLoading.dismiss();
      Get.snackbar('错误', e.toString());
    }
  }

  // 删除公告
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      final response = await HttpClient.client.delete(
        '/api/group/$groupId/announcement/$announcementId',
      );

      if (response.code == 0) {
        Get.snackbar('成功', '删除成功');
        // 从列表中移除
        state.announcements.removeWhere((a) => a.id == announcementId);
      } else {
        Get.snackbar('失败', response.msg);
      }
    } catch (e) {
      Get.snackbar('错误', e.toString());
    }
  }

  // 格式化时间
  String formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond());
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}
