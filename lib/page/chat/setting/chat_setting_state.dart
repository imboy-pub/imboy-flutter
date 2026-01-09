part of 'chat_setting_logic.dart';

class ChatSettingState {
  /// 聊天对象ID
  final RxString chatId = ''.obs;

  /// 聊天类型（单聊/群聊）
  final RxString chatType = ''.obs;

  /// 是否置顶
  final RxBool isPinned = false.obs;

  /// 是否免打扰
  final RxBool isMuted = false.obs;

  /// 聊天背景
  final RxString chatBackground = ''.obs;

  /// 加载状态
  final RxBool isLoading = false.obs;
}
