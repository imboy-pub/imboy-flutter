/// T09 录音编排服务单测：计时/暂停/中断/限额/单 capture/磁盘失败/恢复续接。
///
/// 全部 host 级（Fake 引擎 + 临时目录 + 真实加密链路）。真机断网/锁屏/
/// 来电/崩溃/空间不足行为见 T09 报告 waiting_resource 声明。
library;

import 'dart:async';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

import 'fake_talk_record_engine.dart';

/// 冲刷真实 IO：pumpEventQueue 只处理微任务，dart:io 完成回调需要
/// 事件循环回合；每个小 delay 让真实 loop 转一圈。
Future<void> settleIO({int turns = 12}) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await pumpEventQueue();
}

/// 条件等待（消时序敏感）：滚动封段/失败结束/manifest 落盘都是多段
/// 真实 IO 链，固定轮数的 settleIO 在并行负载下不够——改为循环冲刷
/// 直到 [cond] 为真或超时（返回是否达成，由随后的 expect 报差异）。
Future<bool> waitUntil(bool Function() cond, {int timeoutMs = 5000}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
  while (!cond()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await settleIO(turns: 3);
  }
  return true;
}

/// fake 引擎段时长：16kHz AAC-LC ADTS，每帧 1024 样本=恰 64ms，
/// 帧数=ceil(elapsed/64)（elapsed≤0 也产出 1 帧）——封段后真实样本是
/// 时间轴权威（PLAN 2.1），断言按真实 samples 设置，不用墙钟 tick 值。
int fakeSegMs(int elapsedMs) =>
    elapsedMs <= 0 ? 64 : (elapsedMs + 63) ~/ 64 * 64;

void main() {
  late Directory baseDir;
  late FakeTalkRecordEngine engine;
  late MemoryTalkRecordKeyStore keyStore;
  late FakeDiskSpaceProbe diskProbe;
  late FakeInterruptionSource interruptionSource;
  late FakeClock clock;

  setUp(() {
    baseDir = Directory.systemTemp.createTempSync('t09_service');
    engine = FakeTalkRecordEngine();
    keyStore = MemoryTalkRecordKeyStore();
    diskProbe = FakeDiskSpaceProbe();
    interruptionSource = FakeInterruptionSource();
    clock = FakeClock();
    TalkRecordCaptureLease.resetForTest();
  });

  tearDown(() async {
    TalkRecordCaptureLease.resetForTest();
    if (baseDir.existsSync()) baseDir.deleteSync(recursive: true);
  });

  /// 双轴推进：墙钟（读秒/轮转判定）+ 引擎样本（封段权威帧数）。
  void tickBoth(int ms, {double? decibels}) {
    clock.advanceMs(ms);
    engine.tick(ms, decibels: decibels);
  }

  TalkRecordRecorderService newService({TalkRecordRecorderConfig? config}) {
    return TalkRecordRecorderService(
      baseDirectory: baseDir,
      engine: engine,
      keyStore: keyStore,
      diskProbe: diskProbe,
      interruptionSource: interruptionSource,
      config:
          config ??
          const TalkRecordRecorderConfig(
            segmentTargetMs: 1000,
            maxDurationMs: 10000,
            maxRecordingBytes: 100 * 1024 * 1024,
            minFreeDiskBytesPerSegment: 1,
          ),
      nowSource: clock.call,
    );
  }

  Future<TalkRecordRecorderService> started({
    TalkRecordRecorderConfig? config,
  }) async {
    final svc = newService(config: config);
    await svc.start(recordLocalId: 'rec-1', clientRecordingId: 'crid-1');
    await settleIO();
    return svc;
  }

  for (final boundary in [1, 2, 3]) {
    test(
      'expired start intent at boundary $boundary never starts native capture',
      () async {
        final service = newService();
        var checks = 0;
        await expectLater(
          service.start(
            recordLocalId: 'guarded',
            clientRecordingId: 'guarded-1',
            beforeOpen: () {
              if (++checks == boundary) throw StateError('intent expired');
            },
          ),
          throwsA(isA<TalkRecordStartException>()),
        );
        expect(
          engine.events.where((event) => event.startsWith('start:')),
          isEmpty,
        );
        if (boundary == 1) {
          expect(engine.events, isNot(contains('open')));
        }
        expect(engine.events, contains('close'));
        expect(keyStore.store, isEmpty);
        expect(TalkRecordCaptureLease.isBusy, isFalse);
        await service.dispose();
      },
    );
  }

  test('start → recording；重复 start（同记录）被单 capture 规则拒绝', () async {
    final svc = await started();
    expect(svc.phase, TalkRecordRecorderPhase.recording);
    expect(svc.snapshot.effectiveDurationMs, 0);
    expect(keyStore.store.length, 1);

    final svc2 = newService();
    expect(
      () => svc2.start(recordLocalId: 'rec-1', clientRecordingId: 'crid-2'),
      throwsA(isA<TalkRecordCaptureBusyException>()),
    );
    await svc.end();
  });

  test('重复 start（不同记录）也被拒绝（并发 1 条本机录音）', () async {
    final svc = await started();
    final svc2 = newService();
    expect(
      () => svc2.start(recordLocalId: 'rec-other', clientRecordingId: 'c2'),
      throwsA(isA<TalkRecordCaptureBusyException>()),
    );
    await svc.end();
  });

  test('结束后租约释放，可再次开始新会话', () async {
    final svc = await started();
    await svc.end();
    expect(TalkRecordCaptureLease.isBusy, isFalse);
    final svc2 = newService();
    await svc2.start(recordLocalId: 'rec-2', clientRecordingId: 'c2');
    expect(svc2.phase, TalkRecordRecorderPhase.recording);
    await svc2.end();
  });

  test('计时与段滚动：目标 1000ms 滚动，有效时长=分段累加', () async {
    final svc = await started();
    tickBoth(500, decibels: -20);
    await settleIO();
    expect(svc.snapshot.effectiveDurationMs, 500);
    expect(svc.snapshot.decibels, -20);

    tickBoth(700); // 墙钟 1200ms ≥ 1000 → 滚动封段
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '滚动封段未在超时内完成',
    );
    // 封段后真实样本权威：1200ms 进度 → 19 帧@16kHz = 1216ms。
    expect(svc.snapshot.effectiveDurationMs, fakeSegMs(1200));

    tickBoth(400);
    expect(
      await waitUntil(
        () => svc.snapshot.effectiveDurationMs == fakeSegMs(1200) + 400,
      ),
      isTrue,
      reason: '新段 disposition 未送达',
    );
    expect(svc.snapshot.segmentCount, 1); // 未到滚动点

    final result = await svc.end();
    expect(result.segmentCount, 2);
    // 段 0 真实样本 1216ms + 段 1 400ms 进度 → 7 帧 448ms。
    expect(result.effectiveDurationMs, fakeSegMs(1200) + fakeSegMs(400));
    expect(result.savedCleanly, isTrue);
    expect(result.manifest.segments[0].startMs, 0);
    expect(result.manifest.segments[0].durationMs, fakeSegMs(1200));
    expect(result.manifest.segments[0].sampleCount, 19 * 1024);
    expect(result.manifest.segments[0].sampleRateHz, 16000);
    expect(result.manifest.segments[0].numChannels, 1);
    expect(result.manifest.segments[1].startMs, fakeSegMs(1200));
    expect(result.manifest.segments[1].durationMs, fakeSegMs(400));
    expect(result.endReason, TalkRecordEndReason.user);
  });

  test('foreground service loss ends as failure and preserves encrypted sealed audio', () async {
    final svc = await started();
    tickBoth(1200);
    expect(await waitUntil(() => svc.snapshot.segmentCount == 1), isTrue);
    await settleIO();
    final dir = svc.sessionDir!;
    final before = TalkRecordManifestStore(dir);
    final sealed = (await before.read())!.segments.single;
    final audio = File('${dir.path}/${sealed.cipherFileName}');
    final bytes = await audio.readAsBytes();
    engine.emitFailure(StateError('foreground service lost'));
    expect(
      await waitUntil(() => svc.phase == TalkRecordRecorderPhase.ended),
      isTrue,
    );
    final result = await svc.end();
    expect(result.endReason, TalkRecordEndReason.engineFailure);
    expect(result.savedCleanly, false);
    expect(result.segmentCount, 1);
    expect(result.effectiveDurationMs, fakeSegMs(1200));
    expect(engine.events, contains('close'));
    expect(await audio.readAsBytes(), bytes);
    expect(
      (await TalkRecordManifestStore(dir).read())!.endedReason,
      'engine_failure',
    );
    await svc.dispose();
  });

  test('暂停不计时（含墙钟流逝）；恢复后墙钟轴继续累计（不依赖引擎上报）', () async {
    final svc = await started();
    tickBoth(600);
    await settleIO();
    await svc.pause();
    expect(svc.phase, TalkRecordRecorderPhase.paused);
    // 暂停期间引擎静默，但即使有滞后帧也不计数。
    engine.emitRaw(9000);
    await settleIO();
    expect(svc.snapshot.effectiveDurationMs, 600);
    // 暂停期墙钟流逝不计时（真机缺陷语义：暂停不可计入录音时长）。
    clock.advanceMs(5000);
    expect(svc.snapshot.effectiveDurationMs, 600);

    await svc.resume();
    // 引擎上报停摆（真机实证）：仅墙钟推进，读秒照常走动（快照由
    // ticker 周期 emit 刷新，300ms 内必达）。
    clock.advanceMs(200);
    expect(
      await waitUntil(() => svc.snapshot.effectiveDurationMs == 800),
      isTrue,
      reason: 'resume 后墙钟轴读秒未恢复走动',
    );
    // 恢复后引擎帧到达也只带电平，不把引擎 elapsed 灌入读秒。
    engine.tick(99999);
    await settleIO();
    expect(svc.snapshot.effectiveDurationMs, 800);
    await svc.end();
  });

  test('中断：真实暂停+持久原因；恢复必须用户点击', () async {
    final svc = await started();
    tickBoth(300);
    await settleIO();

    interruptionSource.interrupt('audio_interruption');
    expect(
      await waitUntil(
        () =>
            svc.phase == TalkRecordRecorderPhase.interrupted &&
            svc.snapshot.interruptReason == 'audio_interruption',
      ),
      isTrue,
      reason: '中断处理链（pause+manifest 持久化+emit）未完成',
    );
    expect(engine.paused, isTrue);

    // 中断期间帧不计入。
    engine.emitRaw(5000);
    await settleIO();
    expect(svc.snapshot.effectiveDurationMs, 300);

    // manifest 已持久化中断记录。
    final persisted = await TalkRecordManifestStore(
      Directory('${baseDir.path}/${svc.sessionId}'),
    ).read();
    expect(persisted!.status, TalkRecordSessionStatus.interrupted);
    expect(persisted.interruption?.reason, 'audio_interruption');

    // 用户点击恢复。
    await svc.userResumeAfterInterruption();
    expect(svc.phase, TalkRecordRecorderPhase.recording);
    clock.advanceMs(100);
    expect(
      await waitUntil(() => svc.snapshot.effectiveDurationMs == 400),
      isTrue,
      reason: '中断恢复后墙钟轴读秒未恢复走动',
    );
    await svc.end();
  });

  test('时长限额：到限自动结束并保留已录内容', () async {
    final svc = await started(
      config: const TalkRecordRecorderConfig(
        segmentTargetMs: 1000,
        maxDurationMs: 2500,
        approachingLimitRatio: 0.8,
        minFreeDiskBytesPerSegment: 1,
      ),
    );
    tickBoth(2100); // 墙钟 ≥ warn 线 2000（2500×0.8）
    expect(
      await waitUntil(
        () => svc.snapshot.limitWarn == TalkRecordLimitWarn.duration,
      ),
      isTrue,
      reason: '滚动后的限额提示未送达',
    );

    tickBoth(500); // 2600 ≥ 2500 → 自动结束
    expect(
      await waitUntil(() => svc.phase == TalkRecordRecorderPhase.ended),
      isTrue,
      reason: '到限自动结束链未完成',
    );
    final result = await svc.end(); // 幂等：返回首次结果
    expect(result.endReason, TalkRecordEndReason.durationLimit);
    expect(result.savedCleanly, isTrue);
    // 2100ms 段 → 33 帧 2112ms；500ms 段 → 8 帧 512ms。
    expect(result.effectiveDurationMs, fakeSegMs(2100) + fakeSegMs(500));
    expect(result.segmentCount, greaterThanOrEqualTo(1));
    // 清单终态。
    final persisted = await TalkRecordManifestStore(
      Directory('${baseDir.path}/${svc.sessionId}'),
    ).read();
    expect(persisted!.status, TalkRecordSessionStatus.ended);
    expect(persisted.endedReason, 'duration_limit');
  });

  test('字节限额：按码率估算到限自动结束', () async {
    // bitRate 24000 → 3000 B/s；maxRecordingBytes=3000 → 1 秒到限。
    final svc = await started(
      config: const TalkRecordRecorderConfig(
        segmentTargetMs: 30000,
        maxDurationMs: 60000,
        maxRecordingBytes: 3000,
        minFreeDiskBytesPerSegment: 1,
      ),
    );
    tickBoth(500);
    await settleIO();
    expect(svc.phase, TalkRecordRecorderPhase.recording);
    tickBoth(600); // 墙钟 1100ms → est ≈ 3300B ≥ 3000
    expect(
      await waitUntil(
        () =>
            svc.phase == TalkRecordRecorderPhase.ended &&
            svc.snapshot.endReason == TalkRecordEndReason.bytesLimit,
      ),
      isTrue,
      reason: '字节限额自动结束链未完成',
    );
    expect(svc.snapshot.savedCleanly, isTrue);
  });

  test('启动磁盘预检失败 → 拒绝开始且租约释放', () async {
    diskProbe.ok = false;
    final svc = newService();
    await expectLater(
      svc.start(recordLocalId: 'rec-1', clientRecordingId: 'c'),
      throwsA(isA<TalkRecordStartException>()),
    );
    expect(TalkRecordCaptureLease.isBusy, isFalse);

    diskProbe.ok = true;
    final svc2 = newService();
    await svc2.start(recordLocalId: 'rec-1', clientRecordingId: 'c');
    await svc2.end();
  });

  test('录制中空间耗尽 → 中止并保留已落盘段，不显示保存成功', () async {
    final svc = await started();
    tickBoth(1200); // 滚动封第 0 段成功
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '滚动封段未完成',
    );

    // 下一次封段前预检失败。
    diskProbe.failingDirs.add(svc.sessionDir!.path);
    tickBoth(1000); // 第 1 段到滚动点 → 预检失败 → 中止
    expect(
      await waitUntil(
        () =>
            svc.phase == TalkRecordRecorderPhase.ended &&
            svc.snapshot.savedCleanly == false &&
            svc.snapshot.endReason == TalkRecordEndReason.diskFull,
      ),
      isTrue,
      reason: 'diskFull 失败结束链未完成',
    );
    final result = await svc.end();
    expect(result.savedCleanly, isFalse);
    expect(result.endReason, TalkRecordEndReason.diskFull);
    // 已落盘的第 0 段保留。
    expect(result.segmentCount, 1);
    expect(result.effectiveDurationMs, fakeSegMs(1200));
  });

  test('空段（start 后立即 end）→ 文件有有效帧仍保留（真实样本权威）', () async {
    final svc = await started();
    final result = await svc.end();
    // fake 引擎 elapsed=0 也产出 1 帧：进度缺失但有有效帧 → 段保留
    //（PLAN 2.1：不得凭进度丢弃有效音频）。
    expect(result.segmentCount, 1);
    expect(result.effectiveDurationMs, fakeSegMs(0));
    expect(result.manifest.segments.single.sampleCount, 1024);
    expect(result.savedCleanly, isTrue);
  });

  test('重点标记写本地：位置=当时有效时长，封段一次性校正', () async {
    final svc = await started();
    tickBoth(1500);
    // 等滚动封段完成（否则第二笔 tick 可能被 _rollingOver 吞掉，
    // 位置断言随负载漂移）。
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '1500ms 段未封',
    );
    await svc.addMark(note: '结论');
    expect(svc.snapshot.markCount, 1);
    tickBoth(200);
    expect(
      await waitUntil(
        () => svc.snapshot.effectiveDurationMs == fakeSegMs(1500) + 200,
      ),
      isTrue,
      reason: '续段 disposition 未送达',
    );
    await svc.addMark();
    expect(svc.snapshot.markCount, 2);

    final persisted = await TalkRecordManifestStore(
      Directory('${baseDir.path}/${svc.sessionId}'),
    ).read();
    expect(persisted!.marks.length, 2);
    // 临时位置 = 记录时有效时长（段 0 真实样本 1536ms + 段内进度）。
    expect(persisted.marks[0].positionMs, fakeSegMs(1500));
    expect(persisted.marks[0].note, '结论');
    expect(persisted.marks[0].segmentSeq, 1);
    expect(persisted.marks[1].positionMs, fakeSegMs(1500) + 200);
    expect(persisted.marks[1].segmentSeq, 1);
    // 段 1 未封：均未校正。
    expect(persisted.marks[0].calibratedMs, isNull);
    await svc.end();

    // end 封段 1：两标记按真实样本一次性校正且不再变动。
    final settled = await TalkRecordManifestStore(
      Directory('${baseDir.path}/${svc.sessionId}'),
    ).read();
    final seg1 = settled!.segments[1];
    expect(seg1.sampleCount, greaterThan(0));
    for (final mark in settled.marks) {
      expect(mark.segmentSeq, 1);
      expect(mark.calibrated, isTrue, reason: '封段后标记必须已校正');
      expect(mark.calibratedMs, inInclusiveRange(seg1.startMs, seg1.endMs));
    }
    // 校正位置 = ms(prevTotal + localSample)：prevTotal=24 帧，
    // mark0 相对 0ms → localSample=0 → 起点边界。
    expect(settled.marks[0].calibratedMs, seg1.startMs);
  });

  test('崩溃恢复：未 ended 会话 → 恢复 interrupted，续接后继续累计并重新封段', () async {
    // 第一段：录制一段并封段（通过滚动），随后不 end（模拟崩溃）。
    final svc = await started();
    tickBoth(1200);
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '崩溃前封段未完成',
    );
    final sessionId = svc.sessionId!;
    // 模拟进程死亡：不做 end/清理（不复用 service 实例）。
    TalkRecordCaptureLease.resetForTest();

    // 恢复。
    final dir = Directory('${baseDir.path}/$sessionId');
    final recovery = await TalkRecordRecorderService.recoverSession(dir);
    expect(recovery.truncatedTail, isFalse);
    expect(recovery.effectiveDurationMs, fakeSegMs(1200));

    final engine2 = FakeTalkRecordEngine();
    final svc2 = TalkRecordRecorderService(
      baseDirectory: baseDir,
      engine: engine2,
      keyStore: keyStore,
      diskProbe: diskProbe,
      config: const TalkRecordRecorderConfig(
        segmentTargetMs: 1000,
        maxDurationMs: 10000,
        minFreeDiskBytesPerSegment: 1,
      ),
      nowSource: clock.call,
    );
    await svc2.attachRecovered(
      manifest: recovery.manifest!,
      recordKey: keyStore.store[sessionId]!,
    );
    expect(svc2.phase, TalkRecordRecorderPhase.interrupted);
    expect(svc2.snapshot.effectiveDurationMs, fakeSegMs(1200));
    expect(svc2.snapshot.interruptReason, 'unknown_interrupt');

    // 用户确认恢复，继续录（墙钟轴接续，不依赖引擎上报；引擎照常
    // 编码推进样本轴——封段权威仍按真实样本）。
    await svc2.userResumeAfterInterruption();
    clock.advanceMs(500);
    engine2.tick(500);
    expect(
      await waitUntil(
        () => svc2.snapshot.effectiveDurationMs == fakeSegMs(1200) + 500,
      ),
      isTrue,
      reason: '恢复续接后墙钟轴读秒未接续走动',
    );
    final result = await svc2.end();
    // 恢复前 1 段 + 续接 1 段，样本时间轴连续（先累计样本再舍入）。
    expect(result.segmentCount, 2);
    expect(result.manifest.segments[1].seq, 1);
    expect(result.manifest.segments[1].startMs, fakeSegMs(1200));
    expect(
      result.effectiveDurationMs,
      fakeSegMs(1200) + fakeSegMs(500),
      reason: '累计样本统一舍入：19 帧 + 8 帧 = 27 帧 × 64ms = 1728',
    );
  });

  test('已结束会话不可续接', () async {
    final svc = await started();
    final result = await svc.end();
    final svc2 = TalkRecordRecorderService(
      baseDirectory: baseDir,
      engine: FakeTalkRecordEngine(),
    );
    expect(
      () => svc2.attachRecovered(
        manifest: result.manifest,
        recordKey: TalkRecordSegmentCrypto.generateRecordKey(),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('listSessions：枚举含已结束与进行中会话', () async {
    final svc = await started();
    tickBoth(1200);
    await settleIO();
    await svc.end();
    final svc2 = newService();
    await svc2.start(recordLocalId: 'rec-2', clientRecordingId: 'c2');
    await settleIO();

    final sessions = await TalkRecordRecorderService.listSessions(baseDir);
    expect(sessions.length, 2);
    expect(
      sessions.map((s) => s.status).toSet(),
      containsAll([
        TalkRecordSessionStatus.ended,
        TalkRecordSessionStatus.recording,
      ]),
    );
    await svc2.end();
  });

  test('H1：service 启动即激活中断源（start 被调用且仅一次）', () async {
    final svc = await started();
    expect(interruptionSource.started, isTrue);
    expect(interruptionSource.startCount, 1);
    await svc.end();
  });

  test('H1：attachRecovered 恢复续接同样激活中断源', () async {
    final svc = await started();
    tickBoth(1200);
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '恢复样例段未封',
    );
    final sessionId = svc.sessionId!;
    TalkRecordCaptureLease.resetForTest();
    final recovery = await TalkRecordRecorderService.recoverSession(
      Directory('${baseDir.path}/$sessionId'),
    );
    final source2 = FakeInterruptionSource();
    final engine2 = FakeTalkRecordEngine();
    final svc2 = TalkRecordRecorderService(
      baseDirectory: baseDir,
      engine: engine2,
      keyStore: keyStore,
      interruptionSource: source2,
      config: const TalkRecordRecorderConfig(
        segmentTargetMs: 1000,
        maxDurationMs: 10000,
        minFreeDiskBytesPerSegment: 1,
      ),
      nowSource: clock.call,
    );
    await svc2.attachRecovered(
      manifest: recovery.manifest!,
      recordKey: keyStore.store[sessionId]!,
    );
    expect(source2.started, isTrue);
    await svc2.end();
    await svc.dispose();
  });

  test('H2：diskFull 失败结束进行中调 end()——等待失败结果而非空引用崩溃', () async {
    final svc = await started();
    tickBoth(1200); // 封第 0 段
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '第 0 段未封',
    );
    // 构造确定性竞态窗口：失败结束链走到 teardown 的 engine.close() 时
    // 被闸住——此刻 _failKeepContent 在途（_ending=true、completer 已建、
    // _lastResult 未赋、phase 已置 ended）。
    diskProbe.failingDirs.add(svc.sessionDir!.path);
    final gate = Completer<void>();
    engine.closeGate = gate;
    tickBoth(1000);
    expect(
      await waitUntil(() => svc.phase == TalkRecordRecorderPhase.ended),
      isTrue,
      reason: '失败结束未到达 teardown 窗口',
    );

    final endFuture = svc.end();
    // 落在窗口内的 end()：不抛、不空引用，等待失败结果。
    gate.complete();
    final result = await endFuture;
    expect(result.savedCleanly, isFalse);
    expect(result.endReason, TalkRecordEndReason.diskFull);
    expect(result.segmentCount, 1); // 已落盘的第 0 段保留
    // 幂等：结束后再次 end() 返回同一失败结果。
    final again = await svc.end();
    expect(again.savedCleanly, isFalse);
  });

  test('M1：引擎首段启动失败——抛异常+租约释放+零残留', () async {
    engine.failStartSegment = true;
    final svc = newService();
    await expectLater(
      svc.start(recordLocalId: 'rec-1', clientRecordingId: 'c'),
      throwsA(isA<TalkRecordStartException>()),
    );
    expect(TalkRecordCaptureLease.isBusy, isFalse);
    // 零残留：无会话目录（manifest/tmp/段文件）、无孤儿密钥。
    expect(baseDir.listSync(), isEmpty);
    expect(keyStore.store, isEmpty);
    // 租约可用：重试成功。
    engine.failStartSegment = false;
    final svc2 = newService();
    await svc2.start(recordLocalId: 'rec-1', clientRecordingId: 'c');
    expect(svc2.phase, TalkRecordRecorderPhase.recording);
    await svc2.end();
  });

  test('M2：listSessions 单目录损坏不击穿枚举（一坏多好）', () async {
    final svc = await started();
    tickBoth(1200);
    await settleIO();
    await svc.end();
    // 伪造一个 manifest 损坏的会话目录。
    final bad = Directory('${baseDir.path}/bad-session')..createSync();
    File('${bad.path}/manifest.json').writeAsStringSync('not-json');
    final sessions = await TalkRecordRecorderService.listSessions(baseDir);
    expect(sessions.length, 1);
    expect(sessions.single.status, TalkRecordSessionStatus.ended);
  });

  test('M4：writeFailure 注入（密文路径被目录占位）——ended+失败+保留先前段', () async {
    final svc = await started();
    tickBoth(1200); // 第 0 段正常封段
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '第 0 段未封',
    );
    // 让下一段的密文落盘失败：目录占位 seg_000001.aes → rename 失败。
    Directory('${svc.sessionDir!.path}/seg_000001.aes').createSync();
    tickBoth(1100); // 滚动封第 1 段 → seal 抛 → 失败结束
    expect(
      await waitUntil(
        () =>
            svc.phase == TalkRecordRecorderPhase.ended &&
            svc.snapshot.savedCleanly == false &&
            svc.snapshot.endReason == TalkRecordEndReason.writeFailure,
      ),
      isTrue,
      reason: 'writeFailure 失败结束链未完成',
    );
    final result = await svc.end();
    expect(result.segmentCount, 1); // 先前段保留
    expect(result.effectiveDurationMs, fakeSegMs(1200));
  });

  test('空段（dropSegmentFileOnStop）跳过，录音继续不崩溃', () async {
    int startCount() =>
        engine.events.where((e) => e.startsWith('start:')).length;
    final svc = await started();
    tickBoth(1200); // 第 0 段正常
    expect(
      await waitUntil(() => startCount() == 2), // seg0 已封、seg1 已开
      isTrue,
      reason: '第一次滚动未完成（段 0 封存+段 1 启动）',
    );
    engine.dropSegmentFileOnStop = true; // 第 1 段 stop 时丢明文
    tickBoth(1100); // 滚动：第 1 段文件缺失 → 空段跳过 → seg2 启动
    expect(
      await waitUntil(() => startCount() == 3), // 跳过后第 2 段已开
      isTrue,
      reason: '空段跳过后的第 2 段未启动',
    );
    expect(svc.phase, TalkRecordRecorderPhase.recording); // 未中止
    expect(svc.snapshot.segmentCount, 1); // 仅第 0 段
    engine.dropSegmentFileOnStop = false;
    tickBoth(600); // 第 2 段继续累计
    expect(
      await waitUntil(
        () => svc.snapshot.effectiveDurationMs == fakeSegMs(1200) + 600,
      ),
      isTrue,
      reason: '第 2 段 disposition 未送达',
    );
    final result = await svc.end();
    expect(result.segmentCount, 2);
    expect(result.effectiveDurationMs, fakeSegMs(1200) + fakeSegMs(600));
    expect(result.savedCleanly, isTrue);
  });

  test('会话目录中段文件为密文（无明文残留），明文临时文件即用即删', () async {
    final svc = await started();
    tickBoth(1200);
    expect(
      await waitUntil(() => svc.snapshot.segmentCount == 1),
      isTrue,
      reason: '第一次滚动未完成（避免与 end 竞态）',
    );
    tickBoth(500);
    await settleIO();
    await svc.end();

    final dir = Directory('${baseDir.path}/${svc.sessionId}');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .toList();
    expect(files.where((p) => p.endsWith('.aac')), isEmpty);
    expect(files.where((p) => p.endsWith('.tmp')), isEmpty);
    expect(files.where((p) => p.endsWith('.aes')).length, 2);
  });
}
