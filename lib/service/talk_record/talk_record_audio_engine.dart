/// 面聊记录（talk_record）T09 —— 录音音频引擎抽象与 flutter_sound 实现。
///
/// 抽象边界：service 层只依赖 [TalkRecordAudioEngine] 接口，生产走
/// [FlutterSoundTalkRecordEngine]（flutter_sound 9.30.0，与现有
/// voice_widget 同一插件），host 单测注入 fake（无麦克风副作用）。
///
/// 段文件形态：每段一个独立明文临时文件（AAC-ADTS），由 service 层
/// 在段结束时加密搬运到会话目录。段间 stop→start 有平台级停顿
/// （典型 <1s，属真机验证项）。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';

import 'talk_record_recorder_config.dart';
import 'talk_record_foreground.dart';

/// 引擎单帧进度（段内相对时间）。
class TalkRecordEngineDisposition {
  final int elapsedMs;
  final double? decibels;

  const TalkRecordEngineDisposition({required this.elapsedMs, this.decibels});
}

/// 引擎异常（启动失败/编码器不支持/IO 失败统一出口）。
class TalkRecordEngineException implements Exception {
  final String message;
  final Object? cause;
  TalkRecordEngineException(this.message, {this.cause});
  @override
  String toString() => 'TalkRecordEngineException: $message';
}

/// 音频引擎抽象。
abstract class TalkRecordAudioEngine {
  /// 进度流（段内 elapsed + 电平；暂停期间不发声）。
  Stream<TalkRecordEngineDisposition> get dispositions;

  /// 打开引擎（申请编码器资源）。
  Future<void> open();

  /// 开始录制一段到 [targetFilePath]（绝对路径）。
  Future<void> startSegment(
    String targetFilePath,
    TalkRecordEncoderSettings settings,
  );

  /// 真实暂停（段文件保持打开，时长停止累计）。
  Future<void> pause();

  Future<void> resume();

  /// 结束当前段；返回引擎侧时长（ms，可能为 null——由 service 以
  /// 累计 dispositions 为权威兜底）。
  Future<int?> stopSegment();

  Future<void> close();
}

/// flutter_sound 生产实现。
///
/// 平台能力假设（待真机验证，T09 报告「平台能力假设清单」）：
/// 1. sampleRate 对 AAC 由平台编码器决定，可能不等于 settings 值；
/// 2. aacADTS 双平台可用（对齐 voice_widget 现网路径，T03 取证 C2）；
/// 3. decibels 在 setSubscriptionDuration 后按周期上报，可能为 null；
/// 4. Android 在前台服务确认后才采集；后台持续与厂商电源限制仍需真机验证。
class FlutterSoundTalkRecordEngine implements TalkRecordAudioEngine {
  FlutterSoundTalkRecordEngine({
    FlutterSoundRecorder? recorder,
    TalkRecordForeground? foreground,
  }) : _recorder = recorder ?? FlutterSoundRecorder(),
       _foreground = foreground ?? TalkRecordForeground() {
    _foreground.onLost = () {
      unawaited(_foregroundLost());
    };
  }

  final FlutterSoundRecorder _recorder;
  final TalkRecordForeground _foreground;
  bool _foregroundFailed = false;

  Future<void> _foregroundLost() async {
    if (_foregroundFailed) return;
    _foregroundFailed = true;
    // Stop only this recorder. The service preserves its lease until close confirms it.
    try {
      await _recorder.stopRecorder();
    } catch (_) {
      // closeRecorder remains mandatory, and the service receives a failure event.
    }
    if (!_dispositions.isClosed) {
      _dispositions.addError(TalkRecordEngineException('录音前台服务已停止，请返回应用重新开始'));
    }
  }

  StreamSubscription<RecordingDisposition>? _sub;
  final StreamController<TalkRecordEngineDisposition> _dispositions =
      StreamController<TalkRecordEngineDisposition>.broadcast();
  bool _opened = false;
  bool _closeRequired = false;

  static final Codec _codec = Codec.aacADTS;
  static const String _mime = 'audio/aac';

  /// 引擎产物的 MIME（service 层封段时带进加密元数据）。
  static String get segmentMime => _mime;

  @override
  Stream<TalkRecordEngineDisposition> get dispositions => _dispositions.stream;

  @override
  Future<void> open() async {
    if (_opened) return;
    try {
      _closeRequired =
          true; // even a partially failed open needs confirmed close
      await _recorder.openRecorder();
      // 电平/时长上报周期（voice_widget 同款 100ms 先例）。
      await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );
      _opened = true;
    } catch (e) {
      throw TalkRecordEngineException('打开录音器失败: $e');
    }
  }

  @override
  Future<void> startSegment(
    String targetFilePath,
    TalkRecordEncoderSettings settings,
  ) async {
    if (!_opened) {
      throw TalkRecordEngineException('引擎未打开');
    }
    try {
      await _sub?.cancel();
      _sub = null;
      if (_foregroundFailed) throw StateError('录音前台服务已中断');
      await _foreground.start();
      await _foreground.update(paused: false);
      if (_foregroundFailed) throw StateError('录音前台服务已中断');
      await _recorder.startRecorder(
        toFile: targetFilePath,
        codec: _codec,
        numChannels: settings.numChannels,
        bitRate: settings.bitRate,
        sampleRate: settings.sampleRateHz,
        audioSource: AudioSource.microphone,
      );
      if (_foregroundFailed) throw StateError('录音前台服务已中断');
      _sub = _recorder.onProgress?.listen((d) {
        _dispositions.add(
          TalkRecordEngineDisposition(
            elapsedMs: d.duration.inMilliseconds,
            decibels: d.decibels,
          ),
        );
      });
    } catch (e) {
      // Keep the foreground lifetime until this recorder confirms shutdown.
      if (_closeRequired) {
        await _recorder.closeRecorder();
        _closeRequired = false;
        _opened = false;
      }
      await _foreground.stop();
      throw TalkRecordEngineException('startRecorder 失败: $e', cause: e);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _recorder.pauseRecorder();
      await _foreground.update(paused: true);
    } catch (e) {
      throw TalkRecordEngineException('pauseRecorder 失败: $e');
    }
  }

  @override
  Future<void> resume() async {
    try {
      if (_foregroundFailed) throw StateError('录音前台服务已中断');
      await _foreground.update(paused: false);
      await _recorder.resumeRecorder();
    } catch (e) {
      throw TalkRecordEngineException('resumeRecorder 失败: $e');
    }
  }

  @override
  Future<int?> stopSegment() async {
    try {
      await _sub?.cancel();
      _sub = null;
      final path = await _recorder.stopRecorder();
      if (!_foregroundFailed) await _foreground.update(paused: true);
      if (path == null) return null;
      // L1：不再按字节数伪造时长（原 bytes*8 数学错误且 ADTS 无全局
      // 时长字段）——时长权威是 onProgress dispositions 的累计，
      // service 层对缺失场景按引擎返回值兜底，本层只报告文件存在性。
      return File(path).existsSync() ? 0 : null;
    } catch (e) {
      throw TalkRecordEngineException('stopRecorder 失败: $e');
    }
  }

  @override
  Future<void> close() async {
    // The caller must retain its capture lease if the platform cannot confirm
    // close. Ending a Dart stream is not evidence that the microphone stopped.
    try {
      await _sub?.cancel();
    } finally {
      _sub = null;
      if (_closeRequired) {
        await _recorder.closeRecorder();
        _closeRequired = false;
        _opened = false;
      }
      await _foreground.stop();
      await _dispositions.close();
    }
  }
}
