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

  @override
  VoicePlaybackState build() {
    // 防止重复初始化：先清理旧的监听器和播放器
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer?.dispose();

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
        await stop();
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
