/// T09 测试助手：Fake 录音引擎 / 内存 key store / 内存磁盘探测。
///
/// host 级测试（无麦克风副作用、无平台通道）：fake 引擎在 stopSegment
/// 时产出真实明文临时文件（确定性字节），让加密/manifest/恢复链路在
/// 测试里走真实代码路径。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:imboy/service/talk_record/talk_record_audio_engine.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

/// 可编程 fake 引擎。
class FakeTalkRecordEngine implements TalkRecordAudioEngine {
  final StreamController<TalkRecordEngineDisposition> _ctrl =
      StreamController<TalkRecordEngineDisposition>.broadcast();

  /// 调用轨迹（断言用）。
  final List<String> events = <String>[];

  /// 当前段内累计 ms（tick 推进；startSegment 清零）。
  int elapsedMs = 0;

  bool paused = false;
  bool opened = false;

  /// 阻塞 close()（H2 竞态用例：把 _failKeepContent 钉在 teardown 窗口）。
  Completer<void>? closeGate;

  /// startSegment 抛异常开关。
  bool failStartSegment = false;

  /// stopSegment 后删除明文文件（模拟空段/丢失）。
  bool dropSegmentFileOnStop = false;

  /// 每段明文字节数（默认按 elapsed 派生，保证非空）。
  int Function(int elapsedMs)? segmentByteSize;

  String? _currentPath;

  @override
  Stream<TalkRecordEngineDisposition> get dispositions => _ctrl.stream;

  /// 推进 [deltaMs] 并派发一帧（暂停态静默丢弃，模拟真实引擎）。
  void tick(int deltaMs, {double? decibels}) {
    if (paused) return;
    elapsedMs += deltaMs;
    _ctrl.add(
      TalkRecordEngineDisposition(elapsedMs: elapsedMs, decibels: decibels),
    );
  }

  /// 直接派发一帧（不推进内部累计；用于构造异常帧）。
  void emitRaw(int ms, {double? decibels}) {
    _ctrl.add(TalkRecordEngineDisposition(elapsedMs: ms, decibels: decibels));
  }

  /// Platform service loss is surfaced through the actual disposition error path.
  void emitFailure(Object error) => _ctrl.addError(error);

  @override
  Future<void> open() async {
    opened = true;
    events.add('open');
  }

  @override
  Future<void> startSegment(
    String targetFilePath,
    TalkRecordEncoderSettings settings,
  ) async {
    if (failStartSegment) {
      throw TalkRecordEngineException('fake start failure');
    }
    events.add('start:$targetFilePath');
    _currentPath = targetFilePath;
    elapsedMs = 0;
    paused = false;
  }

  @override
  Future<void> pause() async {
    paused = true;
    events.add('pause');
  }

  @override
  Future<void> resume() async {
    paused = false;
    events.add('resume');
  }

  @override
  Future<int?> stopSegment() async {
    events.add('stop');
    final path = _currentPath;
    _currentPath = null;
    if (path == null) return elapsedMs;
    if (dropSegmentFileOnStop) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
      return elapsedMs;
    }
    final size = segmentByteSize?.call(elapsedMs) ?? 200 + elapsedMs;
    final bytes = Uint8List.fromList(
      List<int>.generate(size, (i) => (i + elapsedMs) & 0xFF),
    );
    await File(path).writeAsBytes(bytes, flush: true);
    return elapsedMs;
  }

  @override
  Future<void> close() async {
    events.add('close');
    final gate = closeGate;
    if (gate != null) await gate.future;
    await _ctrl.close();
  }
}

/// 内存 key store。
class MemoryTalkRecordKeyStore implements TalkRecordKeyStore {
  final Map<String, Uint8List> store = <String, Uint8List>{};

  @override
  Future<void> writeRecordKey(String sessionId, Uint8List key) async {
    store[sessionId] = key;
  }

  @override
  Future<Uint8List?> readRecordKey(String sessionId) async => store[sessionId];

  @override
  Future<void> deleteRecordKey(String sessionId) async {
    store.remove(sessionId);
  }
}

/// 可编程磁盘探测。
class FakeDiskSpaceProbe implements DiskSpaceProbe {
  bool ok = true;

  /// 按目录路径禁止（模拟录制中途空间耗尽）。
  final Set<String> failingDirs = <String>{};

  int probeCount = 0;

  @override
  Future<bool> hasAtLeast(Directory dir, int bytes) async {
    probeCount++;
    if (!ok) return false;
    return !failingDirs.contains(dir.path);
  }
}

/// 测试用可注入中断源。
///
/// `started`/`startCount` 用于 H1 断言：service 启动即激活中断源
/// （未 start 的生产源不桥接平台流——来电静默失效）。
class FakeInterruptionSource implements TalkRecordInterruptionSource {
  final StreamController<TalkRecordInterruptionSignal> _ctrl =
      StreamController<TalkRecordInterruptionSignal>.broadcast();

  bool started = false;
  int startCount = 0;

  @override
  Future<void> start() async {
    started = true;
    startCount++;
  }

  @override
  Stream<TalkRecordInterruptionSignal> get interruptions => _ctrl.stream;

  void interrupt(String reason) =>
      _ctrl.add(TalkRecordInterruptionSignal(reason));

  @override
  Future<void> dispose() => _ctrl.close();
}
