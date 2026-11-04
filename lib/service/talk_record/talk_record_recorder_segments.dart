part of 'talk_record_recorder_service.dart';

/// Segment rotation, sealing and sample-axis calibration. Controls remain serialized
/// by the owning recorder; these operations never enter the control queue.
extension _RecorderSegments on TalkRecordRecorderService {
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

  /// 封当前段：stop → 解析真实 ADTS → 磁盘预检 → 加密落盘 →
  /// 样本时间轴与标记一次性校正 → manifest 原子追加。
  ///
  /// 封段后真实编码样本成为录后时长/分段边界/标记的统一权威（PLAN 2.1）：
  /// * 段 start/end 按累计样本统一整数舍入（ms(S,R)），不逐段舍入累加；
  /// * sample_rate_hz/num_channels 记真实 ADTS 头值（非配置值）；
  /// * 本段标记（segmentSeq==当前 seq 且未校正）按真实样本校正一次，
  ///   与段条目在同一次 manifest 原子写入落盘；进度缺失但有有效帧时
  ///   段照常保留，标记标记为校准失败（不伪造位置）。
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
      await _engine.stopSegment();
      plainPath = _lastPlainFilePath;
      _lastPlainFilePath = null;
      if (plainPath == null) return null;
      final plainFile = File(plainPath);
      if (!plainFile.existsSync() || plainFile.lengthSync() == 0) return null;

      // 有界解析：30 秒级明文段读入内存做结构校验（不施加 MiniMax 的
      // 500 秒上限——那属于其调用层）。
      final TalkRecordAdtsSummary audio;
      try {
        audio = talkRecordAdtsScan(await plainFile.readAsBytes());
      } on TalkRecordAdtsException {
        // 编码器产出不可解析（截断帧/坏头）：不能封存为有效音频段。
        _lastWriteFailureIsDisk = false;
        await _failKeepContent(TalkRecordEndReason.writeFailure);
        return false;
      }
      if (audio.frameCount <= 0) return null;
      // 同一录音参数必须一致（混合参数无法拼接为合法成品）。
      if (_audioRateHz == null || _audioChannels == null) {
        _audioRateHz = audio.sampleRateHz;
        _audioChannels = audio.numChannels;
      } else if (_audioRateHz != audio.sampleRateHz ||
          _audioChannels != audio.numChannels) {
        _lastWriteFailureIsDisk = false;
        await _failKeepContent(TalkRecordEndReason.engineFailure);
        return false;
      }

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

      // 段边界：样本轴可用时先累计样本再统一舍入；旧清单续接退毫秒轴。
      final int startMs;
      final int endMs;
      if (_sampleAxisUsable) {
        startMs = msOfSamples(_sealedTotalSamples, audio.sampleRateHz);
        endMs = msOfSamples(
          _sealedTotalSamples + audio.sampleCount,
          audio.sampleRateHz,
        );
      } else {
        startMs = _sealedDurationMs;
        endMs = startMs + _currentSegmentElapsedMs;
      }
      final entry = TalkRecordSegmentEntry(
        seq: _currentSeq,
        startMs: startMs,
        endMs: endMs,
        cipherFileName: _cipherFileName(_currentSeq),
        cipherSize: info.cipherSize,
        cipherSha256Hex: info.cipherSha256Hex,
        plainSize: info.plainSize,
        plainSha256Hex: info.plainSha256Hex,
        codec: config.encoder.codec,
        sampleRateHz: audio.sampleRateHz,
        numChannels: audio.numChannels,
        sampleCount: audio.sampleCount,
        capturedWallTimeIso: DateTime.now().toIso8601String(),
      );
      final marks = _calibrateMarksForSealedSegment(
        m,
        seq: _currentSeq,
        segStartMs: startMs,
        segSamples: audio.sampleCount,
        prevTotalSamples: _sealedTotalSamples,
        rateHz: audio.sampleRateHz,
      );
      final latest = _manifest!;
      _manifest = latest.copyWith(
        segments: List.unmodifiable([...latest.segments, entry]),
        marks: marks ?? latest.marks,
        updatedAtIso: DateTime.now().toIso8601String(),
      );
      await _writeManifest();
      if (_sampleAxisUsable) {
        _sealedTotalSamples += audio.sampleCount;
      }
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

  /// 封段时对本段未校正标记一次性校正（PLAN 2.1 公式）：
  /// relative = provisional - segmentStart；localSample =
  /// round(clamp(relative/progress,0,1) × segSamples)；
  /// mark_ms = ms(prevTotal + localSample, R)。
  ///
  /// 进度缺失（elapsed<=0）但有有效帧：标记置校准失败，不伪造位置。
  /// 样本轴不可用（旧清单续接）：保留临时位置不校正。返回 null 表示
  /// 无标记需要更新（调用方沿用原列表，同一次原子写入不受影响）。
  List<TalkRecordLocalMark>? _calibrateMarksForSealedSegment(
    TalkRecordManifest manifest, {
    required int seq,
    required int segStartMs,
    required int segSamples,
    required int prevTotalSamples,
    required int rateHz,
  }) {
    if (manifest.marks.isEmpty) return null;
    final progressMs = _currentSegmentElapsedMs;
    var changed = false;
    final out = <TalkRecordLocalMark>[];
    for (final mark in manifest.marks) {
      if (mark.segmentSeq != seq || mark.calibrated || mark.calibrationFailed) {
        out.add(mark);
        continue;
      }
      changed = true;
      if (!_sampleAxisUsable || progressMs <= 0) {
        // 无法精确定位：明确失效，不伪造正确位置（上传层跳过）。
        out.add(
          TalkRecordLocalMark(
            localId: mark.localId,
            positionMs: mark.positionMs,
            segmentSeq: mark.segmentSeq,
            calibrationFailed: true,
            note: mark.note,
            createdAtIso: mark.createdAtIso,
          ),
        );
        continue;
      }
      final relativeMs = (mark.positionMs - segStartMs).clamp(0, progressMs);
      final ratio = relativeMs / progressMs;
      final localSample = (ratio * segSamples).round();
      out.add(
        TalkRecordLocalMark(
          localId: mark.localId,
          positionMs: mark.positionMs,
          segmentSeq: mark.segmentSeq,
          calibratedMs: msOfSamples(prevTotalSamples + localSample, rateHz),
          note: mark.note,
          createdAtIso: mark.createdAtIso,
        ),
      );
    }
    return changed ? List.unmodifiable(out) : null;
  }

  String _cipherFileName(int seq) =>
      'seg_${seq.toString().padLeft(6, '0')}.aes';
}
