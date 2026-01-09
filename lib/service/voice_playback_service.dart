import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:imboy/component/helper/func.dart';

class VoicePlaybackService extends GetxService {
  static VoicePlaybackService get to => Get.find();

  final AudioPlayer _audioPlayer = AudioPlayer();

  // 响应式状态
  final RxString currentAudioPath = ''.obs;
  final RxString currentMessageId = ''.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isPaused = false.obs;
  final RxInt currentPosition = 0.obs;
  final RxInt currentDuration = 0.obs;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  // 播放完成回调，用于自动连播
  Future<void> Function(String currentMessageId)? onPlaybackCompleted;

  @override
  void onInit() {
    super.onInit();
    _initAudioSession();
    _setupListeners();
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
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((
      state,
    ) async {
      isPlaying.value = state.playing;
      isPaused.value =
          state.processingState == ProcessingState.ready && !state.playing;

      if (state.processingState == ProcessingState.completed) {
        final finishedId = currentMessageId.value;
        stop();
        if (onPlaybackCompleted != null) {
          await onPlaybackCompleted!(finishedId);
        }
      }
    });

    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      currentPosition.value = pos.inMilliseconds;
    });

    _durationSubscription = _audioPlayer.durationStream.listen((dur) {
      if (dur != null) {
        currentDuration.value = dur.inMilliseconds;
      }
    });
  }

  Future<void> play({
    required String path,
    required String messageId,
    int? durationMs,
  }) async {
    try {
      if (path.isEmpty) return;

      // 如果是同一个音频且正在播放，则暂停
      if (currentAudioPath.value == path && isPlaying.value) {
        await pause();
        return;
      }

      // 如果是同一个音频且处于暂停，则恢复
      if (currentAudioPath.value == path && isPaused.value) {
        await resume();
        return;
      }

      // 停止当前播放
      await _audioPlayer.stop();

      final file = File(path);
      if (!await file.exists()) {
        iPrint('VoicePlaybackService: File not found: $path');
        return;
      }

      final session = await AudioSession.instance;
      await session.setActive(true);

      currentAudioPath.value = path;
      currentMessageId.value = messageId;
      if (durationMs != null) {
        currentDuration.value = durationMs;
      }

      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
    } catch (e) {
      iPrint('VoicePlaybackService: Play error: $e');
      stop();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    currentAudioPath.value = '';
    currentMessageId.value = '';
    currentPosition.value = 0;
    currentDuration.value = 0;
    isPlaying.value = false;
    isPaused.value = false;
  }

  @override
  void onClose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.onClose();
  }
}
