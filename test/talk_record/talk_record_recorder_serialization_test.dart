import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';

import 'fake_talk_record_engine.dart';

class _StopGateEngine extends FakeTalkRecordEngine {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool inStop = false;
  int overlaps = 0;
  int stops = 0;

  @override
  Future<int?> stopSegment() async {
    stops++;
    if (stops == 1) {
      inStop = true;
      entered.complete();
      await release.future;
    }
    try {
      return await super.stopSegment();
    } finally {
      inStop = false;
    }
  }

  @override
  Future<void> pause() async {
    if (inStop) overlaps++;
    await super.pause();
  }

  @override
  Future<void> startSegment(
    String path,
    TalkRecordEncoderSettings settings,
  ) async {
    if (inStop) overlaps++;
    await super.startSegment(path, settings);
  }
}

class _SealProbe implements DiskSpaceProbe {
  final entered = Completer<void>();
  final release = Completer<void>();
  int calls = 0;
  bool failSeal = false;

  @override
  Future<bool> hasAtLeast(Directory dir, int bytes) async {
    calls++;
    if (calls == 2) {
      entered.complete();
      await release.future;
      return !failSeal;
    }
    return true;
  }
}

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('talk-serial-test');
    TalkRecordCaptureLease.resetForTest();
  });
  tearDown(() {
    TalkRecordCaptureLease.resetForTest();
    root.deleteSync(recursive: true);
  });

  TalkRecordRecorderService service(
    FakeTalkRecordEngine engine,
    DiskSpaceProbe probe,
  ) => TalkRecordRecorderService(
    baseDirectory: root,
    engine: engine,
    diskProbe: probe,
    keyStore: MemoryTalkRecordKeyStore(),
    config: const TalkRecordRecorderConfig(
      segmentTargetMs: 1000,
      maxDurationMs: 10000,
      maxRecordingBytes: 100 * 1024 * 1024,
      minFreeDiskBytesPerSegment: 1,
    ),
  );

  test(
    'stop barrier serializes mark, pause and end without duplicate sealing',
    () async {
      final engine = _StopGateEngine();
      final svc = service(engine, FakeDiskSpaceProbe());
      await svc.start(recordLocalId: 'r', clientRecordingId: 'c');
      engine.tick(1000);
      for (var i = 0; i < 5; i++) {
        engine.emitRaw(1000);
      }
      await engine.entered.future;
      final mark = svc.addMark(note: 'during seal');
      final pause = svc.pause();
      final end = svc.end();
      final lateMark = svc.addMark(note: 'after end intent');
      engine.release.complete();
      await Future.wait([mark, pause]);
      final result = await end;
      await lateMark;
      expect(engine.overlaps, 0);
      expect(
        engine.stops,
        2,
      ); // Rollover's old segment and end's empty new segment.
      expect(engine.events.where((e) => e.startsWith('start:')).length, 2);
      expect(result.manifest.marks.single.note, 'during seal');
      expect(result.manifest.marks.single.positionMs, 1000);
      expect(result.manifest.segments.map((s) => s.seq), [0]);
      expect(result.manifest.status, TalkRecordSessionStatus.ended);
      final disk = await TalkRecordManifestStore(svc.sessionDir!).read();
      expect(disk!.marks.length, 1);
      expect(disk.status, TalkRecordSessionStatus.ended);
      await svc.dispose();
    },
  );

  test('seal I/O barrier preserves pause and marks before resume seals next segment', () async {
    final engine = FakeTalkRecordEngine();
    final probe = _SealProbe();
    final svc = service(engine, probe);
    await svc.start(recordLocalId: 'r', clientRecordingId: 'c');
    engine.tick(1000);
    await probe.entered.future;
    final mark = svc.addMark(note: 'I/O mark');
    final pause = svc.pause();
    probe.release.complete();
    await Future.wait([mark, pause]);
    final paused = await TalkRecordManifestStore(svc.sessionDir!).read();
    expect(paused!.status, TalkRecordSessionStatus.paused);
    expect(paused.marks.single.note, 'I/O mark');
    expect(paused.segments.map((s) => s.seq), [0]);
    await svc.resume();
    final progressed = svc.snapshots.firstWhere(
      (s) => s.effectiveDurationMs == 1200,
    );
    engine.tick(200);
    await progressed;
    final result = await svc.end();
    expect(result.manifest.marks.length, 1);
    expect(result.manifest.segments.map((s) => s.seq), [0, 1]);
    expect(result.effectiveDurationMs, 1200);
    await svc.dispose();
  });

  test(
    'seal failure and queued end finish without recursive control deadlock',
    () async {
      final engine = FakeTalkRecordEngine();
      final probe = _SealProbe()..failSeal = true;
      final svc = service(engine, probe);
      await svc.start(recordLocalId: 'r', clientRecordingId: 'c');
      engine.tick(1000);
      await probe.entered.future;
      final end = svc.end();
      probe.release.complete();
      final result = await end;
      expect(result.savedCleanly, false);
      expect(result.endReason, TalkRecordEndReason.diskFull);
      expect(result.segmentCount, 0);
      await svc.dispose();
    },
  );
}
