/// 面聊本机录音：串行控制、加密分段、恢复清单与确认停麦租约。
/// 不做网络上传；录音与恢复规则见 DESIGN §5 / BACKEND-API §3、§11。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:imboy/service/talk_record/talk_record_audio_engine.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

import 'talk_record_recorder_state.dart';
export 'talk_record_recorder_state.dart';

/// 长录音编排服务。一个实例对应一次采集会话生命周期
/// （idle → recording ↔ paused/interrupted → ended）。
class TalkRecordRecorderService {
  TalkRecordRecorderService({
    required this.baseDirectory,
    TalkRecordAudioEngine? engine,
    this.keyStore,
    DiskSpaceProbe? diskProbe,
    this.interruptionSource,
    this.config = const TalkRecordRecorderConfig(),
  }) : _engine = engine ?? FlutterSoundTalkRecordEngine(),
       diskProbe = diskProbe ?? ProbeFileDiskSpaceProbe();

  // All mutating controls share one queue. Internal terminal/failure helpers
  // run inside its current operation and never re-enter the queue.
  Future<void> _controlTail = Future<void>.value();
  bool _boundaryQueued = false;

  Future<T> _control<T>(Future<T> Function() operation) {
    final result = _controlTail.then((_) => operation());
    _controlTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  /// 会话根目录（生产：`<appSupport>/talk_record/`）。
  final Directory baseDirectory;
  final TalkRecordRecorderConfig config;
  final TalkRecordKeyStore? keyStore;
  final DiskSpaceProbe diskProbe;
  final TalkRecordInterruptionSource? interruptionSource;

  final TalkRecordAudioEngine _engine;

  final StreamController<TalkRecordRecorderSnapshot> _snapshots =
      StreamController<TalkRecordRecorderSnapshot>.broadcast();

  StreamSubscription<TalkRecordEngineDisposition>? _dispositionSub;
  StreamSubscription<TalkRecordInterruptionSignal>? _interruptionSub;

  TalkRecordRecorderPhase _phase = TalkRecordRecorderPhase.idle;
  TalkRecordManifest? _manifest;
  Uint8List? _recordKey;
  String? _leasedRecordLocalId;
  int _sealedDurationMs = 0;
  int _currentSegmentElapsedMs = 0;
  int _currentSeq = 0;
  bool _rollingOver = false;
  bool _ending = false;

  /// 结果是否已产出（_failKeepContent/_endInternal 幂等门）。
  bool _finished = false;
  bool _stopUnconfirmed = false;

  /// 会话目录由本实例 start() 新建（abort 时可删；attachRecovered
  /// 续接的既有会话不得删）。
  bool _ownsSessionDir = false;
  String? _lastPlainFilePath;
  double? _lastDecibels;
  TalkRecordRecorderSnapshot _snapshot = const TalkRecordRecorderSnapshot();

  // ───────────────────────────────────────────────────────────────────────
  // 观测面
  // ───────────────────────────────────────────────────────────────────────

  Stream<TalkRecordRecorderSnapshot> get snapshots => _snapshots.stream;
  TalkRecordRecorderSnapshot get snapshot => _snapshot;
  TalkRecordRecorderPhase get phase => _phase;
  String? get sessionId => _manifest?.sessionId;
  Directory? get sessionDir => _manifest == null
      ? null
      : Directory('${baseDirectory.path}/${_manifest!.sessionId}');

  /// 当前有效时长（封段累计 + 当前段）。
  int get effectiveDurationMs => _sealedDurationMs + _currentSegmentElapsedMs;

  // ───────────────────────────────────────────────────────────────────────
  // 生命周期
  // ───────────────────────────────────────────────────────────────────────

  /// 开始一次采集（单 capture 规则 + 磁盘预检 + 引擎打开 + 首段启动）。
  Future<void> start({
    required String recordLocalId,
    required String clientRecordingId,
    void Function()? beforeOpen,
  }) => _control(
    () => _startInternal(
      recordLocalId: recordLocalId,
      clientRecordingId: clientRecordingId,
      beforeOpen: beforeOpen,
    ),
  );

  Future<void> _startInternal({
    required String recordLocalId,
    required String clientRecordingId,
    void Function()? beforeOpen,
  }) async {
    if (_phase != TalkRecordRecorderPhase.idle) {
      throw StateError('start 仅允许 idle 状态（当前 $_phase）');
    }
    TalkRecordCaptureLease.take(recordLocalId);
    _leasedRecordLocalId = recordLocalId;
    final sessionId = TalkRecordIds.newUuidV4();
    try {
      final sessionDir = Directory('${baseDirectory.path}/$sessionId');
      if (!await diskProbe.hasAtLeast(
        sessionDir,
        config.minFreeDiskBytesPerSegment,
      )) {
        throw TalkRecordStartException('disk_space');
      }
      final recordKey = TalkRecordSegmentCrypto.generateRecordKey();
      if (keyStore != null) {
        await keyStore!.writeRecordKey(sessionId, recordKey);
      }
      _ownsSessionDir = true;
      _recordKey = recordKey;
      _manifest = TalkRecordManifest(
        sessionId: sessionId,
        recordLocalId: recordLocalId,
        clientRecordingId: clientRecordingId,
        status: TalkRecordSessionStatus.recording,
        reportedStartedAtIso: DateTime.now().toIso8601String(),
        encoder: config.encoder,
        maxDurationMs: config.effectiveMaxDurationMs,
        maxRecordingBytes: config.effectiveMaxRecordingBytes,
        updatedAtIso: DateTime.now().toIso8601String(),
      );
      await TalkRecordManifestStore(sessionDir).write(_manifest!);

      beforeOpen?.call();
      await _engine.open();
      beforeOpen?.call();
      await _startSegment(0, beforeOpen: beforeOpen);
      await _listenEngine();
      _phase = TalkRecordRecorderPhase.recording;
      _emit();
    } catch (e) {
      await _abortStart();
      if (e is TalkRecordStartException ||
          e is TalkRecordCaptureBusyException) {
        rethrow;
      }
      throw TalkRecordStartException('engine: $e', cause: e);
    }
  }

  Future<void> _abortStart() async {
    await _teardown();
    if (_stopUnconfirmed) {
      _phase = TalkRecordRecorderPhase.failed;
      _emit(savedCleanly: false);
      throw const TalkRecordStopUnconfirmedException();
    }
    final m = _manifest;
    // M1：本会话由 start() 新建（非 attachRecovered 续接的既有会话）时，
    // 启动失败必须清干净——否则每次引擎失败（真机权限拒绝高频形态）
    // 遗留零段 recording 清单 + secure storage 孤儿密钥 + tmp 明文，
    // 下次启动被恢复入口当成可续接的幽灵会话。
    if (m != null && _ownsSessionDir) {
      final keyStore = this.keyStore;
      if (keyStore != null) {
        try {
          await keyStore.deleteRecordKey(m.sessionId);
        } catch (_) {}
      }
      try {
        final dir = Directory('${baseDirectory.path}/${m.sessionId}');
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    }
    final leased = _leasedRecordLocalId;
    if (leased != null) {
      TalkRecordCaptureLease.release(leased);
      _leasedRecordLocalId = null;
    }
    _manifest = null;
    _recordKey = null;
    _ownsSessionDir = false;
    _phase = TalkRecordRecorderPhase.idle;
  }

  /// 用户暂停（真实暂停，计时冻结）。
  Future<void> pause() => _control(_pauseInternal);

  Future<void> _pauseInternal() async {
    if (_phase != TalkRecordRecorderPhase.recording) return;
    await _engine.pause();
    _phase = TalkRecordRecorderPhase.paused;
    await _persistStatus(TalkRecordSessionStatus.paused);
    _emit();
  }

  /// 系统中断（来电/抢占）——真实暂停 + 持久中断原因。
  Future<void> markInterrupted(String reason) =>
      _control(() => _markInterruptedInternal(reason));

  Future<void> _markInterruptedInternal(String reason) async {
    if (_phase != TalkRecordRecorderPhase.recording) return;
    await _engine.pause();
    _phase = TalkRecordRecorderPhase.interrupted;
    _manifest = _manifest!.copyWith(
      status: TalkRecordSessionStatus.interrupted,
      interruption: TalkRecordInterruptionRecord(
        reason: reason,
        occurredAtIso: DateTime.now().toIso8601String(),
      ),
      updatedAtIso: DateTime.now().toIso8601String(),
    );
    await _writeManifest();
    _emit();
  }

  /// 暂停后继续（用户点击）。
  Future<void> resume() => _control(_resumeInternal);

  Future<void> _resumeInternal() async {
    if (_phase != TalkRecordRecorderPhase.paused) return;
    await _engine.resume();
    _phase = TalkRecordRecorderPhase.recording;
    await _persistStatus(TalkRecordSessionStatus.recording);
    _emit();
  }

  /// 中断后恢复——必须用户显式点击（§5.2）。
  Future<void> userResumeAfterInterruption() =>
      _control(_userResumeAfterInterruptionInternal);

  Future<void> _userResumeAfterInterruptionInternal() async {
    if (_phase != TalkRecordRecorderPhase.interrupted) return;
    await _engine.resume();
    _phase = TalkRecordRecorderPhase.recording;
    await _persistStatus(TalkRecordSessionStatus.recording);
    _emit();
  }

  /// 写本地重点标记（位置=当前有效时长；§11.1 mark 绑定有效音频位置）。
  Future<void> addMark({String note = ''}) =>
      _control(() => _addMarkInternal(note));

  Future<void> _addMarkInternal(String note) async {
    if (!_phase.isActive) return;
    final m = _manifest;
    if (m == null) return;
    final mark = TalkRecordLocalMark(
      localId: TalkRecordIds.newUuidV4(),
      positionMs: effectiveDurationMs,
      note: note,
      createdAtIso: DateTime.now().toIso8601String(),
    );
    _manifest = m.copyWith(
      marks: List.unmodifiable([...m.marks, mark]),
      updatedAtIso: DateTime.now().toIso8601String(),
    );
    await _writeManifest();
    _emit();
  }

  /// 用户结束并保存：封当前段→manifest ended→释放资源。
  ///
  /// 写入失败不抛出后假成功：结果里 [TalkRecordSessionResult.savedCleanly]
  /// =false 且 endReason=writeFailure/diskFull。已结束（含限额/失败自动
  /// 结束后再次调用）返回首次结束结果。
  Future<TalkRecordSessionResult> end() => _control(_endRequested);

  Future<TalkRecordSessionResult> _endRequested() async {
    if (_finished && _lastResult != null) {
      return _lastResult!;
    }
    return _endInternal(TalkRecordEndReason.user);
  }

  Future<TalkRecordSessionResult> _endInternal(
    TalkRecordEndReason reason,
  ) async {
    if (_ending) {
      // 并发结束请求（用户 end 与限额/失败结束竞争）：等待在途结束。
      // H2：_failKeepContent 进行中的窗口同样走到这里——completer 已
      // 同步创建（见 _failKeepContent），null 防御仅剩理论路径。
      final pending = _endCompleter;
      if (pending != null) return pending.future;
      final last = _lastResult;
      if (last != null) return last;
      throw StateError('结束进行中且无等待点（内部不一致）');
    }
    if (!_phase.isActive) {
      throw StateError('end 仅允许活跃状态（当前 $_phase）');
    }
    _ending = true;
    _finished = true;
    final completer = Completer<TalkRecordSessionResult>();
    _endCompleter = completer;
    var savedCleanly = true;
    var finalReason = reason;
    try {
      // 封当前段（尽力保留已录内容）。
      final sealed = await _sealCurrentSegment(finalMs: null);
      if (sealed == false) {
        savedCleanly = false;
        if (finalReason == TalkRecordEndReason.user) {
          finalReason = _lastWriteFailureIsDisk
              ? TalkRecordEndReason.diskFull
              : TalkRecordEndReason.writeFailure;
        }
      }
      _currentSegmentElapsedMs = 0;
      _phase = TalkRecordRecorderPhase.ended;
      _manifest = _manifest!.copyWith(
        status: TalkRecordSessionStatus.ended,
        endedReason: finalReason.wireName,
        updatedAtIso: DateTime.now().toIso8601String(),
      );
      try {
        await _writeManifest();
      } catch (_) {
        savedCleanly = false;
      }
    } finally {
      await _teardown();
    }
    if (_stopUnconfirmed) savedCleanly = false;
    final result = TalkRecordSessionResult(
      sessionId: _manifest!.sessionId,
      recordLocalId: _manifest!.recordLocalId,
      clientRecordingId: _manifest!.clientRecordingId,
      endReason: finalReason,
      savedCleanly: savedCleanly,
      stopUnconfirmed: _stopUnconfirmed,
      effectiveDurationMs: _manifest!.effectiveDurationMs,
      segmentCount: _manifest!.segments.length,
      totalCipherBytes: _manifest!.totalCipherBytes,
      manifest: _manifest!,
    );
    _lastResult = result;
    _emit(endReason: finalReason, savedCleanly: savedCleanly);
    completer.complete(result);
    return result;
  }

  /// L3：onDisposition 里 unawaited 的 _endInternal/_rolloverSegment
  /// 异常兜底——不让其成为 unhandled zone error，并尽量降级为失败结束。
  Future<void> _guardAsync(Future<void> Function() operation) =>
      _control(() async {
        try {
          await operation();
        } catch (_) {
          await _failKeepContent(TalkRecordEndReason.engineFailure);
        }
      });

  void _scheduleBoundary(Future<void> Function() operation) {
    if (_boundaryQueued) return;
    _boundaryQueued = true;
    unawaited(
      _guardAsync(() async {
        try {
          await operation();
        } finally {
          _boundaryQueued = false;
        }
      }),
    );
  }

  TalkRecordSessionResult? _lastResult;
  Completer<TalkRecordSessionResult>? _endCompleter;
  bool _lastWriteFailureIsDisk = false;

  Future<void> _teardown() async {
    for (final cleanup in <Future<void> Function()>[
      () async {
        await _dispositionSub?.cancel();
        _dispositionSub = null;
      },
      () async {
        await _interruptionSub?.cancel();
        _interruptionSub = null;
      },
      () async {
        await interruptionSource?.dispose();
      },
    ]) {
      try {
        await cleanup();
      } on Object {
        /* Still attempt physical close. */
      }
    }
    try {
      await _engine.close();
      _stopUnconfirmed = false;
      final leased = _leasedRecordLocalId;
      if (leased != null) {
        TalkRecordCaptureLease.release(leased);
        _leasedRecordLocalId = null;
      }
    } on Object {
      _stopUnconfirmed = true;
      _phase = TalkRecordRecorderPhase.failed;
      // Keep the process lease: neither this instance nor another may open mic.
    }
    _ending = false;
  }

  /// Explicit safety recovery, independent of navigation/account content access.
  Future<void> retryMicrophoneStop() => _control(_retryMicrophoneStopInternal);

  Future<void> _retryMicrophoneStopInternal() async {
    if (!_stopUnconfirmed) return;
    await _teardown();
    _emit(savedCleanly: false);
    if (_stopUnconfirmed) throw const TalkRecordStopUnconfirmedException();
  }

  Future<void> dispose() => _control(_disposeInternal);

  Future<void> _disposeInternal() async {
    if (_phase.isActive) {
      await _endInternal(TalkRecordEndReason.user);
    }
    if (_stopUnconfirmed) await _retryMicrophoneStopInternal();
    await _snapshots.close();
  }

  // 引擎驱动

  Future<void> _listenEngine() async {
    await _interruptionSub?.cancel();
    _interruptionSub = null;
    final src = interruptionSource;
    if (src != null) {
      // H1：必须先激活（生产源在 start() 里桥接平台中断流；
      // 只订阅不 start 的源永远静默——来电/抢占到不了 markInterrupted）。
      await src.start();
      _interruptionSub = src.interruptions.listen((signal) {
        // L3：引擎 pause 异常不得成为 unhandled zone error。
        unawaited(_guardAsync(() => _markInterruptedInternal(signal.reason)));
      });
    }
  }

  void _onDisposition(TalkRecordEngineDisposition d) {
    if (_phase != TalkRecordRecorderPhase.recording ||
        _rollingOver ||
        _boundaryQueued ||
        _ending) {
      return;
    }
    if (d.elapsedMs > _currentSegmentElapsedMs) {
      _currentSegmentElapsedMs = d.elapsedMs;
    }
    if (d.decibels != null) _lastDecibels = d.decibels;

    // 限额：到限结束并保留已录（§11.4）。
    if (effectiveDurationMs >= config.effectiveMaxDurationMs) {
      _scheduleBoundary(() async {
        await _endInternal(TalkRecordEndReason.durationLimit);
      });
      return;
    }
    if (_estimatedBytes() >= config.effectiveMaxRecordingBytes) {
      _scheduleBoundary(() async {
        await _endInternal(TalkRecordEndReason.bytesLimit);
      });
      return;
    }
    // 段滚动。
    if (_currentSegmentElapsedMs >= config.segmentTargetMs) {
      _scheduleBoundary(_rolloverSegment);
      return;
    }
    _emit();
  }

  int _estimatedBytes() {
    // 当前段按码率估算（封段后转为密文精确值）。
    final est = (effectiveDurationMs * config.encoder.bitRate) ~/ 8000;
    return (_manifest?.totalCipherBytes ?? 0) + est;
  }

  int _generation = 0;

  Future<void> _startSegment(int seq, {void Function()? beforeOpen}) async {
    final dir = sessionDir!;
    await dir.create(recursive: true);
    final tmpDir = Directory('${dir.path}/tmp');
    await tmpDir.create(recursive: true);
    final path = '${tmpDir.path}/seg_${seq.toString().padLeft(6, '0')}.aac';
    _currentSeq = seq;
    _currentSegmentElapsedMs = 0;
    _lastPlainFilePath = path;
    beforeOpen?.call();
    await _engine.startSegment(path, config.encoder);
    // 代际守卫：丢弃旧段在 flight 的滞后 disposition（段滚动后平台
    // 可能仍派发上一订阅的尾部事件，其高 elapsed 会污染新段时间轴）。
    _generation++;
    final gen = _generation;
    await _dispositionSub?.cancel();
    _dispositionSub = _engine.dispositions.listen(
      (d) {
        if (gen != _generation) return;
        _onDisposition(d);
      },
      onError: (Object error, StackTrace stack) {
        if (gen != _generation) return;
        unawaited(
          _guardAsync(() async {
            await _failKeepContent(TalkRecordEndReason.engineFailure);
          }),
        );
      },
    );
  }

  /// 段滚动：封当前段 → 起新段（限额触达则顺势结束）。
  Future<void> _rolloverSegment() async {
    if (_rollingOver || _phase != TalkRecordRecorderPhase.recording) return;
    _rollingOver = true;
    try {
      final ok = await _sealCurrentSegment(finalMs: null);
      if (ok == false) {
        // 写入失败已按失败路径处理（_sealCurrentSegment 内部触发结束）。
        return;
      }
      if (effectiveDurationMs >= config.effectiveMaxDurationMs) {
        await _endInternal(TalkRecordEndReason.durationLimit);
        return;
      }
      if ((_manifest?.totalCipherBytes ?? 0) >=
          config.effectiveMaxRecordingBytes) {
        await _endInternal(TalkRecordEndReason.bytesLimit);
        return;
      }
      final next = _currentSeq + 1;
      _sealedDurationMs = _manifest?.effectiveDurationMs ?? _sealedDurationMs;
      await _startSegment(next);
      _emit();
    } finally {
      _rollingOver = false;
    }
  }

  /// 封当前段：stop → 磁盘预检 → 加密落盘 → manifest 追加。
  ///
  /// 返回：true=成功/无需封；false=写入失败（已触发中止，不显示保存成功）；
  /// null=无有效内容可封（空段跳过）。
  Future<bool?> _sealCurrentSegment({int? finalMs}) async {
    final m = _manifest;
    final key = _recordKey;
    if (m == null || key == null) return true;
    if (_currentSegmentElapsedMs <= 0 && _lastPlainFilePath == null) {
      return null;
    }
    final dir = sessionDir!;
    String? plainPath;
    try {
      final engineMs = await _engine.stopSegment();
      plainPath = _lastPlainFilePath;
      _lastPlainFilePath = null;
      if (plainPath == null) return null;
      var elapsed = _currentSegmentElapsedMs;
      if (elapsed <= 0) {
        elapsed = (engineMs ?? 0).clamp(0, config.segmentTargetMs * 2);
      }
      if (elapsed <= 0) return null;
      final plainFile = File(plainPath);
      if (!plainFile.existsSync() || plainFile.lengthSync() == 0) return null;

      if (!await diskProbe.hasAtLeast(dir, config.minFreeDiskBytesPerSegment)) {
        _lastWriteFailureIsDisk = true;
        await _failKeepContent(TalkRecordEndReason.diskFull);
        return false;
      }
      final cipherFile = File('${dir.path}/${_cipherFileName(_currentSeq)}');
      final info = await TalkRecordSegmentCrypto.sealSegment(
        plainFile: plainFile,
        cipherFile: cipherFile,
        recordKey: key,
        sessionId: m.sessionId,
        seq: _currentSeq,
        mime: FlutterSoundTalkRecordEngine.segmentMime,
      );
      final startMs = _sealedDurationMs;
      final entry = TalkRecordSegmentEntry(
        seq: _currentSeq,
        startMs: startMs,
        endMs: startMs + elapsed,
        cipherFileName: _cipherFileName(_currentSeq),
        cipherSize: info.cipherSize,
        cipherSha256Hex: info.cipherSha256Hex,
        plainSize: info.plainSize,
        plainSha256Hex: info.plainSha256Hex,
        codec: config.encoder.codec,
        sampleRateHz: config.encoder.sampleRateHz,
        numChannels: config.encoder.numChannels,
        capturedWallTimeIso: DateTime.now().toIso8601String(),
      );
      final latest = _manifest!;
      _manifest = latest.copyWith(
        segments: List.unmodifiable([...latest.segments, entry]),
        updatedAtIso: DateTime.now().toIso8601String(),
      );
      await _writeManifest();
      _sealedDurationMs = _manifest!.effectiveDurationMs;
      _currentSegmentElapsedMs = 0;
      return true;
    } catch (e) {
      _lastWriteFailureIsDisk = e is FileSystemException;
      await _failKeepContent(TalkRecordEndReason.writeFailure);
      return false;
    } finally {
      // 明文临时文件即用即删（不留明文副本）。
      if (plainPath != null) {
        try {
          final f = File(plainPath);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }

  String _cipherFileName(int seq) =>
      'seg_${seq.toString().padLeft(6, '0')}.aes';

  /// 写入失败中止（§5.3）：保留已落盘段，标记失败，不显示保存成功。
  ///
  /// H2：与 _endInternal 同构走 completer——失败结束进行中调 end() 的
  /// 等待者拿到失败结果而非空引用；已完成（_finished）幂等直接返回。
  Future<void> _failKeepContent(TalkRecordEndReason reason) async {
    if (_finished) return;
    _finished = true;
    _ending = true;
    final completer = _endCompleter ?? Completer<TalkRecordSessionResult>();
    _endCompleter = completer;
    _currentSegmentElapsedMs = 0;
    _phase = TalkRecordRecorderPhase.ended;
    _manifest = _manifest!.copyWith(
      status: TalkRecordSessionStatus.ended,
      endedReason: reason.wireName,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
    try {
      await _writeManifest();
    } catch (_) {
      // manifest 都写不进去：保留内存态供 UI 呈现实际保留时长。
    }
    await _teardown();
    final result = TalkRecordSessionResult(
      sessionId: _manifest!.sessionId,
      recordLocalId: _manifest!.recordLocalId,
      clientRecordingId: _manifest!.clientRecordingId,
      endReason: reason,
      savedCleanly: false,
      stopUnconfirmed: _stopUnconfirmed,
      effectiveDurationMs: _manifest!.effectiveDurationMs,
      segmentCount: _manifest!.segments.length,
      totalCipherBytes: _manifest!.totalCipherBytes,
      manifest: _manifest!,
    );
    _lastResult = result;
    _emit(endReason: reason, savedCleanly: false);
    if (!completer.isCompleted) completer.complete(result);
  }

  // ───────────────────────────────────────────────────────────────────────
  // 恢复（DESIGN §5.3：异常退出→下次恢复已落盘分段）
  // ───────────────────────────────────────────────────────────────────────

  /// 列出 baseDirectory 下全部可恢复会话（含已 ended，调用方过滤）。
  ///
  /// M2：单目录损坏（manifest 非法 JSON 等）跳过而不中断——恢复入口
  /// 不能被最坏目录击穿（其余会话仍可见）。
  static Future<List<TalkRecordManifest>> listSessions(
    Directory baseDirectory,
  ) => TalkRecordManifestStore.listSessions(baseDirectory);

  /// 扫描单个会话目录并恢复（校验段完整性，坏尾截断）。
  static Future<TalkRecordRecoveryResult> recoverSession(
    Directory sessionDir, {
    bool verifyHashes = true,
  }) {
    return TalkRecordManifestStore(sessionDir)
        .recover(verifyHashes: verifyHashes);
  }

  /// 续接已恢复会话：附着清单与密钥，进入 interrupted 态——继续录必须
  /// 用户显式确认（§5.3/§11.1：恢复不等于设备仍持有麦克风）。
  ///
  /// 已 ended 的清单不可续接（走只读呈现路径）。
  Future<void> attachRecovered({
    required TalkRecordManifest manifest,
    required Uint8List recordKey,
  }) => _control(
    () => _attachRecoveredInternal(manifest: manifest, recordKey: recordKey),
  );

  Future<void> _attachRecoveredInternal({
    required TalkRecordManifest manifest,
    required Uint8List recordKey,
  }) async {
    if (_phase != TalkRecordRecorderPhase.idle) {
      throw StateError('attachRecovered 仅允许 idle 状态');
    }
    if (manifest.status == TalkRecordSessionStatus.ended) {
      throw ArgumentError('已结束会话不可续接录音');
    }
    TalkRecordCaptureLease.take(manifest.recordLocalId);
    _leasedRecordLocalId = manifest.recordLocalId;
    _ownsSessionDir = false; // 既有会话：启动失败不删除现场
    _manifest = manifest;
    _recordKey = recordKey;
    _sealedDurationMs = manifest.effectiveDurationMs;
    _currentSeq = manifest.lastSeq + 1;
    try {
      await _engine.open();
      await _startSegment(manifest.lastSeq + 1);
      await _listenEngine();
      await _engine.pause();
      _phase = TalkRecordRecorderPhase.interrupted;
      _emit();
    } catch (e) {
      await _abortStart();
      throw TalkRecordStartException('engine: $e', cause: e);
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // 内部
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _persistStatus(TalkRecordSessionStatus status) async {
    _manifest = _manifest!.copyWith(
      status: status,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
    await _writeManifest();
  }

  Future<void> _writeManifest() async {
    await TalkRecordManifestStore(sessionDir!).write(_manifest!);
  }

  void _emit({TalkRecordEndReason? endReason, bool? savedCleanly}) {
    final warn = _limitWarn();
    _snapshot = TalkRecordRecorderSnapshot(
      phase: _phase,
      sessionId: _manifest?.sessionId ?? '',
      // 有效时长 = 封段累计 + 当前段（暂停/中断态当前段冻结；结束后归零）。
      effectiveDurationMs: effectiveDurationMs,
      segmentCount: _manifest?.segments.length ?? 0,
      sealedCipherBytes: _manifest?.totalCipherBytes ?? 0,
      decibels: _phase == TalkRecordRecorderPhase.recording
          ? _lastDecibels
          : null,
      markCount: _manifest?.marks.length ?? 0,
      interruptReason: _manifest?.interruption?.reason,
      limitWarn: warn,
      endReason: endReason ?? _snapshot.endReason,
      savedCleanly: savedCleanly ?? _snapshot.savedCleanly,
      stopUnconfirmed: _stopUnconfirmed,
    );
    if (!_snapshots.isClosed) {
      _snapshots.add(_snapshot);
    }
  }

  TalkRecordLimitWarn _limitWarn() {
    if (!_phase.isActive) {
      return TalkRecordLimitWarn.none;
    }
    if (effectiveDurationMs >= config.durationWarnMs) {
      return TalkRecordLimitWarn.duration;
    }
    if (_estimatedBytes() >= config.bytesWarnBytes) {
      return TalkRecordLimitWarn.bytes;
    }
    return TalkRecordLimitWarn.none;
  }
}
