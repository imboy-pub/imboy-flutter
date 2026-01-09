import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

part 'chat_setting_state.dart';

class ChatSettingLogic extends GetxController {
  final ChatSettingState state = ChatSettingState();

  final ConversationRepo conversationRepo = ConversationRepo();

  @override
  void onInit() {
    super.onInit();
    _initParams();
    loadChatInfo();
  }

  /// 初始化参数
  void _initParams() {
    final args = Get.arguments;
    if (args is Map) {
      state.chatId.value = args['chatId'] ?? '';
      state.chatType.value = args['chatType'] ?? '';
    }
  }

  /// 加载聊天信息
  Future<void> loadChatInfo() async {
    if (state.chatId.value.isEmpty) {
      return;
    }

    state.isLoading.value = true;
    try {
      // TODO: 实现加载聊天信息逻辑
      // final conversation = await conversationRepo.findById(int.parse(state.chatId.value));
      // if (conversation != null) {
      //   state.isPinned.value = conversation.isPinned == 1;
      //   state.isMuted.value = conversation.isMuted == 1;
      //   state.chatBackground.value = conversation.background ?? '';
      // }
    } catch (e) {
      debugPrint('Failed to load chat info: $e');
    } finally {
      state.isLoading.value = false;
    }
  }

  /// 切换置顶状态
  Future<void> togglePin() async {
    try {
      final newValue = !state.isPinned.value;
      // TODO: 实现置顶切换逻辑
      // await conversationRepo.updateById(
      //   int.parse(state.chatId.value),
      //   {'is_pinned': newValue ? 1 : 0},
      // );
      state.isPinned.value = newValue;
      Get.snackbar(
        newValue ? 'chatSettingPinnedSuccess'.tr : 'chatSettingUnpinnedSuccess'.tr,
        '',
        snackPosition: SnackPosition.bottom,
      );
    } catch (e) {
      Get.snackbar(
        'tipFailed'.tr,
        e.toString(),
        snackPosition: SnackPosition.bottom,
      );
    }
  }

  /// 切换免打扰状态
  Future<void> toggleMute() async {
    try {
      final newValue = !state.isMuted.value;
      // TODO: 实现免打扰切换逻辑
      // await conversationRepo.updateById(
      //   int.parse(state.chatId.value),
      //   {'is_muted': newValue ? 1 : 0},
      // );
      state.isMuted.value = newValue;
      Get.snackbar(
        newValue ? 'chatSettingMuted'.tr : 'chatSettingUnmuted'.tr,
        '',
        snackPosition: SnackPosition.bottom,
      );
    } catch (e) {
      Get.snackbar(
        'tipFailed'.tr,
        e.toString(),
        snackPosition: SnackPosition.bottom,
      );
    }
  }

  /// 设置聊天背景
  Future<void> setChatBackground(String imagePath) async {
    try {
      // TODO: 实现设置聊天背景逻辑
      // await conversationRepo.updateById(
      //   int.parse(state.chatId.value),
      //   {'background': imagePath},
      // );
      state.chatBackground.value = imagePath;
      Get.snackbar(
        'chatSettingBackgroundSuccess'.tr,
        '',
        snackPosition: SnackPosition.bottom,
      );
    } catch (e) {
      Get.snackbar(
        'tipFailed'.tr,
        e.toString(),
        snackPosition: SnackPosition.bottom,
      );
    }
  }

  /// 清空聊天记录
  Future<void> clearChatHistory() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('chatSettingClearHistory'.tr),
        content: Text('chatSettingClearHistoryConfirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('buttonCancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('buttonOk'.tr),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: 实现清空聊天记录逻辑
      Get.snackbar(
        'chatSettingClearedSuccess'.tr,
        '',
        snackPosition: SnackPosition.bottom,
      );
    }
  }

  @override
  void onClose() {
    super.onClose();
  }
}
