import 'dart:async';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

/// 聊天页面状态管理
/// 管理消息列表、滚动控制器、网络状态等
class ChatState {
  final int pageSize = 16; // 每页加载消息数量

  /// 网络连接状态
  final RxBool connected = true.obs;

  /// 是否还有更多消息可以加载
  final RxBool hasMoreMessage = true.obs;

  /// 是否正在加载消息
  final RxBool isLoading = false.obs;

  /// 是否正在加载较新的消息
  final RxBool isLoadingNewer = false.obs;

  /// 下一条消息的自动ID（分页用）
  final RxInt nextAutoId = 0.obs;

  /// 上一条消息的自动ID（用于加载较新消息的分页）
  final RxInt prevAutoId = 0.obs;

  /// 群组成员数量（仅群聊有效）
  final RxInt memberCount = 0.obs;

  RxDouble composerHeight = 52.0.obs;

  /// 消息相关的事件订阅
  StreamSubscription? ssMsgExt;    // 扩展消息订阅
  StreamSubscription? ssMsg;       // 普通消息订阅
  StreamSubscription? ssMsgState;  // 消息状态订阅

  // ===== 音频播放状态管理 =====
  
  /// 当前播放的音频路径
  final RxString currentAudioPath = ''.obs;
  
  /// 当前播放状态
  final RxBool isPlaying = false.obs;
  
  /// 当前暂停状态
  final RxBool isPaused = false.obs;
  
  /// 当前播放位置（毫秒）
  final RxInt currentPosition = 0.obs;
  
  /// 当前播放的总时长（毫秒）
  final RxInt currentDuration = 0.obs;
  
  /// 当前播放的音频消息ID
  final RxString currentMessageId = ''.obs;
  
  /// 当前会话ID（用于未读消息计数优化）
  final RxString currentConversationId = ''.obs;

  ChatState();

  /// 清除所有状态
  void clear() {
    nextAutoId.value = 0;
    prevAutoId.value = 0;
    memberCount.value = 0;
    // 清除音频播放状态
    currentAudioPath.value = '';
    isPlaying.value = false;
    isPaused.value = false;
    currentPosition.value = 0;
    currentDuration.value = 0;
    currentMessageId.value = '';
    // 清除当前会话ID
    currentConversationId.value = '';
    // 不要立即 dispose scrollController，否则页面复用时报错
    // scrollController.dispose();
  }

  /// 销毁监听器和控制器
  void dispose() {
    ssMsgExt?.cancel();
    ssMsg?.cancel();
    ssMsgState?.cancel();
    // 清除音频播放状态
    currentAudioPath.value = '';
    isPlaying.value = false;
    isPaused.value = false;
    currentPosition.value = 0;
    currentDuration.value = 0;
    currentMessageId.value = '';
    // 清除当前会话ID
    currentConversationId.value = '';
  }
  
  /// 检查是否是当前正在播放的音频
  bool isCurrentPlayingAudio(String audioPath) {
    return currentAudioPath.value == audioPath && isPlaying.value;
  }
  
  /// 检查是否是当前正在暂停的音频
  bool isCurrentPausedAudio(String audioPath) {
    return currentAudioPath.value == audioPath && isPaused.value;
  }
  
  /// 设置当前播放的音频信息
  void setCurrentPlayingAudio({
    required String audioPath,
    required String messageId,
    required int duration,
  }) {
    iPrint('setCurrentPlayingAudio: path=$audioPath, messageId=$messageId, duration=$duration');
    currentAudioPath.value = audioPath;
    currentMessageId.value = messageId;
    currentDuration.value = duration;
    currentPosition.value = 0;
    isPlaying.value = true;
    isPaused.value = false;
    iPrint('Audio state updated: isPlaying=true, isPaused=false, position=0');
  }
  
  /// 设置当前暂停的音频信息
  void setCurrentPausedAudio({
    required String audioPath,
    required String messageId,
    required int position,
  }) {
    iPrint('setCurrentPausedAudio: path=$audioPath, messageId=$messageId, position=$position');
    currentAudioPath.value = audioPath;
    currentMessageId.value = messageId;
    currentPosition.value = position;
    isPlaying.value = false;
    isPaused.value = true;
    iPrint('Audio state updated: isPlaying=false, isPaused=true, position=$position');
  }
  
  /// 恢复播放当前音频
  void resumeCurrentAudio() {
    if (currentAudioPath.value.isNotEmpty) {
      iPrint('resumeCurrentAudio: path=${currentAudioPath.value}');
      isPlaying.value = true;
      isPaused.value = false;
      iPrint('Audio state updated: isPlaying=true, isPaused=false');
    } else {
      iPrint('resumeCurrentAudio: no current audio to resume');
    }
  }
  
  /// 停止当前音频播放
  void stopCurrentAudio() {
    iPrint('stopCurrentAudio: stopping current audio');
    currentAudioPath.value = '';
    currentMessageId.value = '';
    currentPosition.value = 0;
    currentDuration.value = 0;
    isPlaying.value = false;
    isPaused.value = false;
    iPrint('Audio state updated: all states cleared');
  }
  
  /// 更新播放位置
  void updatePlaybackPosition(int position) {
    currentPosition.value = position;
    // 只在每秒更新一次日志，避免日志过多
    if (position % 1000 == 0) {
      iPrint('updatePlaybackPosition: ${position}ms / ${currentDuration.value}ms');
    }
  }
  
  /// 格式化播放位置为时间字符串 (00:00.000)
  String formatPlaybackPosition() {
    int milliseconds = currentPosition.value;
    int seconds = milliseconds ~/ 1000;
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    int remainingMilliseconds = milliseconds % 1000;
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String threeDigits(int n) => n.toString().padLeft(3, '0');
    
    return '${twoDigits(minutes)}:${twoDigits(remainingSeconds)}.${threeDigits(remainingMilliseconds)}';
  }
}