/// 音频播放处理器
///
/// 负责语音消息的播放、暂停、继续、停止等操作
/// 遵循单一职责原则（SRP）
library;

import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// 音频播放处理器
///
/// 封装所有语音播放相关逻辑，与 ChatNotifier 解耦
class ChatAudioHandler {
  final VoicePlaybackHelper _voicePlaybackService;

  /// 全局播放控制器（用于波形显示）
  PlayerController? globalPlayerController;

  /// 播放状态订阅
  StreamSubscription<PlayerState>? _playerStateSubscription;

  /// 播放位置订阅
  StreamSubscription<int>? _positionSubscription;

  /// 当前聊天服务（用于获取消息列表）
  List<Message> Function()? _getMessages;

  ChatAudioHandler({
    VoicePlaybackHelper? voicePlaybackService,
  }) : _voicePlaybackService = voicePlaybackService ?? VoicePlaybackHelper.to;

  /// 设置消息获取回调
  void setMessagesGetter(List<Message> Function() getter) {
    _getMessages = getter;
  }

  /// 获取语音播放状态
  /// 注意：实际使用时应通过 Riverpod 的 ref.read(voicePlaybackServiceProvider) 获取
  VoicePlaybackState get voicePlaybackState {
    // 返回默认状态，实际使用时应该通过 Riverpod Provider 获取
    return const VoicePlaybackState(
      currentAudioPath: '',
      currentMessageId: '',
      isPlaying: false,
      isPaused: false,
      currentPosition: 0,
      currentDuration: 0,
    );
  }

  /// 初始化播放控制器
  void initPlayerController() {
    globalPlayerController ??= PlayerController();
  }

  /// 播放语音
  Future<void> playVoice({
    required String voiceUrlOrPath,
    required String messageId,
    required int duration,
  }) async {
    await _voicePlaybackService.play(
      audioPath: voiceUrlOrPath,
      messageId: messageId,
      durationMs: duration,
    );
  }

  /// 暂停播放
  Future<void> pauseVoice() async {
    await _voicePlaybackService.pause();
  }

  /// 继续播放
  Future<void> resumeVoice() async {
    await _voicePlaybackService.resume();
  }

  /// 停止播放
  Future<void> stopCurrentVoice() async {
    await _voicePlaybackService.stop();
  }

  /// 查找下一条语音消息
  Future<MessageModel?> findNextAudioMessage(String messageId) async {
    final messages = _getMessages?.call();
    if (messages == null || messages.isEmpty) return null;

    int currentIndex = messages.indexWhere((m) => m.id == messageId);
    if (currentIndex == -1) return null;

    for (int i = currentIndex + 1; i < messages.length; i++) {
      final message = messages[i];
      if (message is CustomMessage) {
        final customType = message.metadata?['custom_type']?.toString();
        if (customType == 'audio') {
          // 在数据库中查找完整消息
          for (final tableType in ['C2C', 'C2G', 'C2S']) {
            final tb = MessageRepo.getTableName(tableType);
            final repo = MessageRepo(tableName: tb);
            final msg = await repo.find(message.id);
            if (msg != null) return msg;
          }
        }
      }
    }

    return null;
  }

  /// 播放下一条语音消息
  Future<void> playNextAudioMessage(
    String currentMessageId, {
    required void Function(String messageId, String path, int duration)
        onPlayNext,
  }) async {
    if (currentMessageId.isEmpty) return;

    final nextMessage = await findNextAudioMessage(currentMessageId);
    if (nextMessage == null) return;

    final customMessage = await nextMessage.toTypeMessage() as CustomMessage;
    final audioUri = customMessage.metadata?['uri'];
    if (audioUri == null) return;

    final messageId = customMessage.id;
    final duration = customMessage.metadata?['duration_ms'] ?? 0;

    try {
      final audioFile = await IMBoyCacheManager().getSingleFile(
        audioUri,
        validateImageData: false,
      );
      if (await audioFile.exists()) {
        onPlayNext(messageId, audioFile.path, duration);
      }
    } catch (e) {
      // 记录错误但不中断流程
      _logError('播放下一条语音消息失败', e);
    }
  }

  /// 释放资源
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    globalPlayerController?.dispose();
    globalPlayerController = null;
  }

  void _logError(String message, dynamic error) {
    // 使用统一的日志服务
    // AppLogger.warning(message, error);
  }
}
