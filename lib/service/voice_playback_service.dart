import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:imboy/component/helper/func.dart';

part 'voice_playback_service.g.dart';

/// 语音播放状态
class VoicePlaybackState {
  final String currentAudioPath;
  final String currentMessageId;
  final bool isPlaying;
  final bool isPaused;
  final int currentPosition;
  final int currentDuration;

  const VoicePlaybackState({
    this.currentAudioPath = '',
    this.currentMessageId = '',
    this.isPlaying = false,
    this.isPaused = false,
    this.currentPosition = 0,
    this.currentDuration = 0,
  });

  VoicePlaybackState copyWith({
    String? currentAudioPath,
    String? currentMessageId,
    bool? isPlaying,
    bool? isPaused,
    int? currentPosition,
    int? currentDuration,
  }) {
    return VoicePlaybackState(
      currentAudioPath: currentAudioPath ?? this.currentAudioPath,
      currentMessageId: currentMessageId ?? this.currentMessageId,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      currentPosition: currentPosition ?? this.currentPosition,
      currentDuration: currentDuration ?? this.currentDuration,
    );
  }
}

/// 语音播放服务
@riverpod
class VoicePlaybackService extends _$VoicePlaybackService {
  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  // 播放完成回调，用于自动连播
  Future<void> Function(String currentMessageId)? onPlaybackCompleted;

  @override
  VoicePlaybackState build() {
    // 初始化音频播放器
    _audioPlayer = AudioPlayer();
    _initAudioSession();
    _setupListeners();

    // 当 Provider 被释放时清理资源
    ref.onDispose(() {
      _playerStateSubscription?.cancel();
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _audioPlayer?.dispose();
    });

    return const VoicePlaybackState();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      iPrint('VoicePlaybackService: AudioSession configuration failed: $e');
    }
  }

  void _setupListeners() {
    if (_audioPlayer == null) return;

    _playerStateSubscription = _audioPlayer!.playerStateStream.listen((
      playerState,
    ) async {
      state = state.copyWith(
        isPlaying: playerState.playing,
        isPaused:
            playerState.processingState == ProcessingState.ready &&
            !playerState.playing,
      );

      if (playerState.processingState == ProcessingState.completed) {
        final finishedId = state.currentMessageId;
        await stop();
        if (onPlaybackCompleted != null) {
          await onPlaybackCompleted!(finishedId);
        }
      }
    });

    _positionSubscription = _audioPlayer!.positionStream.listen((pos) {
      state = state.copyWith(currentPosition: pos.inMilliseconds);
    });

    _durationSubscription = _audioPlayer!.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(currentDuration: dur.inMilliseconds);
      }
    });
  }

  Future<void> play({
    required String path,
    required String messageId,
    int? durationMs,
  }) async {
    if (_audioPlayer == null) return;

    try {
      if (path.isEmpty) return;

      // 如果是同一个音频且正在播放，则暂停
      if (state.currentAudioPath == path && state.isPlaying) {
        await pause();
        return;
      }

      // 如果是同一个音频且处于暂停，则恢复
      if (state.currentAudioPath == path && state.isPaused) {
        await resume();
        return;
      }

      // 停止当前播放
      await _audioPlayer!.stop();

      final file = File(path);
      if (!await file.exists()) {
        iPrint('VoicePlaybackService: File not found: $path');
        return;
      }

      final session = await AudioSession.instance;
      await session.setActive(true);

      state = state.copyWith(
        currentAudioPath: path,
        currentMessageId: messageId,
        currentDuration: durationMs ?? state.currentDuration,
      );

      await _audioPlayer!.setFilePath(path);
      await _audioPlayer!.play();
    } catch (e) {
      iPrint('VoicePlaybackService: Play error: $e');
      await stop();
    }
  }

  Future<void> pause() async {
    await _audioPlayer?.pause();
  }

  Future<void> resume() async {
    await _audioPlayer?.play();
  }

  Future<void> stop() async {
    await _audioPlayer?.stop();
    state = const VoicePlaybackState();
  }
}

/// 向后兼容的辅助类
/// 用于支持仍在使用 GetX 单例模式的旧代码
/// 新代码应该直接使用 voicePlaybackServiceProvider
class VoicePlaybackHelper {
  VoicePlaybackHelper._();

  static ProviderContainer? _container;

  /// 初始化容器（需要在应用启动时调用）
  static void init(ProviderContainer container) {
    _container = container;
  }

  /// 获取当前播放的音频路径
  String get currentAudioPath {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    return _container!.read(voicePlaybackServiceProvider).currentAudioPath;
  }

  /// 获取当前播放的消息ID
  String get currentMessageId {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    return _container!.read(voicePlaybackServiceProvider).currentMessageId;
  }

  /// 检查是否正在播放
  bool get isPlaying {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    return _container!.read(voicePlaybackServiceProvider).isPlaying;
  }

  /// 检查是否暂停
  bool get isPaused {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    return _container!.read(voicePlaybackServiceProvider).isPaused;
  }

  /// 获取当前播放位置
  int get currentPosition {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    return _container!.read(voicePlaybackServiceProvider).currentPosition;
  }

  /// 获取当前音频时长
  int get currentDuration {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    return _container!.read(voicePlaybackServiceProvider).currentDuration;
  }

  /// 单例访问（向后兼容）
  static final VoicePlaybackHelper to = VoicePlaybackHelper._();

  /// 播放音频
  Future<void> play({
    required String audioPath,
    required String messageId,
    int? durationMs,
    Future<void> Function(String)? onPlaybackCompleted,
  }) async {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    final notifier = _container!.read(voicePlaybackServiceProvider.notifier);
    notifier.onPlaybackCompleted = onPlaybackCompleted;
    await notifier.play(
      path: audioPath,
      messageId: messageId,
      durationMs: durationMs,
    );
  }

  /// 暂停播放
  Future<void> pause() async {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    await _container!.read(voicePlaybackServiceProvider.notifier).pause();
  }

  /// 恢复播放
  Future<void> resume() async {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    await _container!.read(voicePlaybackServiceProvider.notifier).resume();
  }

  /// 停止播放
  Future<void> stop() async {
    if (_container == null) {
      throw Exception(
        'VoicePlaybackHelper not initialized. Call init() first.',
      );
    }
    await _container!.read(voicePlaybackServiceProvider.notifier).stop();
  }
}

/// 向后兼容：VoicePlaybackService.to 访问方式
/// 旧代码可以使用 VoicePlaybackService.to 来访问服务
extension VoicePlaybackServiceExtension on VoicePlaybackService {
  static VoicePlaybackHelper get to => VoicePlaybackHelper.to;
}
